import subprocess
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
PROMPT_MODE_DIR = REPO_ROOT / "templates" / "modes"
FORBIDDEN_EXECUTION_TEXT = [
    "Implement all issues",
    "Mark the checkbox",
    "echo \"done\"",
    "just check && just build && just test",
]
NON_EXECUTION_MODES = [
    "planning",
    "agent_issue_review",
    "post_execution_review",
    "needs_human_direction",
]
REQUIRED_MODES = [
    "planning",
    "agent_issue_review",
    "execution",
    "corrective_resolution",
    "post_execution_review",
    "needs_human_direction",
]


def _mode_instructions(mode):
    script = (
        "source src/prompt/index.sh; "
        "prompt::mode_instructions \"$1\""
    )
    result = subprocess.run(
        ["bash", "-c", script, "prompt-mode", mode],
        cwd=REPO_ROOT,
        env={"NANCY_FRAMEWORK_ROOT": str(REPO_ROOT)},
        text=True,
        capture_output=True,
        check=False,
    )
    assert result.returncode == 0, result.stderr
    return result.stdout


def test_required_prompt_mode_templates_exist():
    for mode in REQUIRED_MODES:
        assert (PROMPT_MODE_DIR / f"{mode}.md.template").exists()


def test_non_execution_prompt_modes_exclude_execution_only_instructions():
    for mode in NON_EXECUTION_MODES:
        instructions = _mode_instructions(mode)

        for forbidden in FORBIDDEN_EXECUTION_TEXT:
            assert forbidden not in instructions


def test_corrective_resolution_requires_post_execution_finding_context():
    instructions = _mode_instructions("corrective_resolution")

    assert "concrete post execution finding" in instructions
    assert "completed worker issue" in instructions


def test_execution_prompt_completes_issue_not_task():
    instructions = _mode_instructions("execution")

    assert 'state: "Worker Done"' in instructions
    assert "CODE_COMPLETE" not in instructions
    assert "Do not write `COMPLETE`" not in instructions


def test_corrective_resolution_does_not_repeat_complete_sentinel_warning():
    instructions = _mode_instructions("corrective_resolution")

    assert "Do not write `COMPLETE`" not in instructions
