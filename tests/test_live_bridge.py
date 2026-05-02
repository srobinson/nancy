import json
import os
import stat
import subprocess
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


def _write_executable(path, body):
    path.write_text(body, encoding="utf-8")
    path.chmod(path.stat().st_mode | stat.S_IXUSR)


def _fake_path(tmp_path):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir(exist_ok=True)

    _write_executable(
        bin_dir / "gum",
        """#!/usr/bin/env bash
set -euo pipefail
cmd="${1:-}"
shift || true
case "$cmd" in
  input)
    value=""
    while [[ $# -gt 0 ]]; do
      if [[ "$1" == "--value" ]]; then
        value="$2"
        shift 2
      else
        shift
      fi
    done
    printf '%s\\n' "$value"
    ;;
  choose)
    last=""
    skip_next=0
    for arg in "$@"; do
      if [[ "$skip_next" == "1" ]]; then
        skip_next=0
        continue
      fi
      case "$arg" in
        --cursor|--header)
          skip_next=1
          ;;
        --*)
          ;;
        *)
          last="$arg"
          ;;
      esac
    done
    printf '%s\\n' "$last"
    ;;
  confirm)
    exit 1
    ;;
  log)
    shift 2 || true
    printf '%s\\n' "$*"
    ;;
  style)
    out=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --*)
          shift
          if [[ $# -gt 0 && "$1" != --* ]]; then
            shift
          fi
          ;;
        *)
          out="${out}${out:+ }$1"
          shift
          ;;
      esac
    done
    printf '%s\\n' "$out"
    ;;
  *)
    exit 0
    ;;
esac
""",
    )

    for name in ("git", "tmux", "claude"):
        _write_executable(bin_dir / name, "#!/usr/bin/env bash\nexit 0\n")

    return f"{bin_dir}{os.pathsep}/opt/homebrew/bin{os.pathsep}/usr/bin{os.pathsep}/bin"


def _run_nancy(tmp_path, args, env=None):
    run_env = {
        **os.environ,
        "PATH": _fake_path(tmp_path),
        "NANCY_SIDECAR_MODE": "0",
    }
    if env:
        run_env.update(env)

    return subprocess.run(
        [str(REPO_ROOT / "nancy"), *args],
        cwd=tmp_path,
        env=run_env,
        text=True,
        capture_output=True,
        check=False,
    )


def _fake_rust_live(tmp_path):
    capture = tmp_path / "rust-live.capture"
    exe = tmp_path / "nancy-live"
    _write_executable(
        exe,
        f"""#!/usr/bin/env bash
set -euo pipefail
{{
  printf 'argv=%s\\n' "$*"
  printf 'project=%s\\n' "${{NANCY_PROJECT_ROOT:-}}"
  printf 'task_dir=%s\\n' "${{NANCY_TASK_DIR:-}}"
}} > {capture}
exit 23
""",
    )
    return exe, capture


def test_setup_uses_bash_by_default_and_preserves_agent_config(tmp_path):
    result = _run_nancy(tmp_path, ["setup"])

    assert result.returncode == 0, result.stderr + result.stdout
    config = json.loads((tmp_path / ".nancy" / "config.json").read_text())
    assert (tmp_path / ".nancy" / "tasks").is_dir()
    assert config["agents"]["worker"]["cli"] in {"claude", "codex"}
    assert config["agents"]["worker"]["model"]
    assert config["agents"]["reviewer"]["cli"] == config["agents"]["worker"]["cli"]
    assert config["agents"]["reviewer"]["model"]


def test_go_default_path_runs_setup_then_rejects_invalid_task_name(tmp_path):
    result = _run_nancy(tmp_path, ["go", "../bad"])

    assert result.returncode != 0
    assert (tmp_path / ".nancy" / "config.json").is_file()
    assert (tmp_path / ".nancy" / "tasks").is_dir()
    assert not (tmp_path / ".nancy" / "bad").exists()
    assert "Invalid task name" in result.stdout


def test_opt_in_rust_live_bridge_dispatches_only_setup_and_go(tmp_path):
    rust_live, capture = _fake_rust_live(tmp_path)

    setup_result = _run_nancy(
        tmp_path,
        ["setup"],
        {
            "NANCY_RUST_LIVE_ENABLED": "1",
            "NANCY_RUST_LIVE_BIN": str(rust_live),
        },
    )
    assert setup_result.returncode == 23
    assert "argv=setup" in capture.read_text()

    capture.unlink()
    go_result = _run_nancy(
        tmp_path,
        ["go", "ALP-123"],
        {
            "NANCY_RUST_LIVE_ENABLED": "1",
            "NANCY_RUST_LIVE_BIN": str(rust_live),
        },
    )
    assert go_result.returncode == 23
    capture_text = capture.read_text()
    assert "argv=go ALP-123" in capture_text
    assert f"project={tmp_path}" in capture_text
    assert f"task_dir={tmp_path / '.nancy' / 'tasks'}" in capture_text

    capture.unlink()
    status_result = _run_nancy(
        tmp_path,
        ["status"],
        {
            "NANCY_RUST_LIVE_ENABLED": "1",
            "NANCY_RUST_LIVE_BIN": str(rust_live),
        },
    )
    assert status_result.returncode != 23
    assert not capture.exists()
