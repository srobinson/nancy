import subprocess
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


def _run_review_mode_script(script):
    result = subprocess.run(
        ["bash", "-c", script],
        cwd=REPO_ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    assert result.returncode == 0, result.stderr + result.stdout
    return result.stdout


def test_gate_aware_modes_disable_legacy_review_hook():
    script = r'''
        source src/cmd/start.sh
        export NANCY_CODE_REVIEW_AGENT_ENABLED=true
        export NANCY_LEGACY_LOCAL_REVIEW_ENABLED=true

        for mode in planning agent_issue_review execution corrective_resolution post_execution_review needs_human_direction; do
            if _start_should_run_review_agent_for_mode "$mode"; then
                echo "legacy review hook unexpectedly enabled for $mode"
                exit 1
            fi
        done
    '''

    _run_review_mode_script(script)


def test_legacy_review_hook_requires_explicit_legacy_local_hygiene_mode():
    script = r'''
        source src/cmd/start.sh

        export NANCY_CODE_REVIEW_AGENT_ENABLED=true
        unset NANCY_LEGACY_LOCAL_REVIEW_ENABLED
        if _start_should_run_review_agent_for_mode legacy_local_hygiene; then
            echo "legacy review hook enabled without explicit opt in"
            exit 1
        fi

        export NANCY_LEGACY_LOCAL_REVIEW_ENABLED=true
        _start_should_run_review_agent_for_mode legacy_local_hygiene
    '''

    _run_review_mode_script(script)


def test_post_execution_review_prompt_stays_distinct_from_legacy_reviewer_prompt():
    post_review = (REPO_ROOT / "templates" / "modes" / "post_execution_review.md.template").read_text()
    legacy_review = (REPO_ROOT / "templates" / "REVIEW.md.template").read_text()

    assert "Do not make direct source edits as the durable review mechanism" in post_review
    assert "may commit review fixes" in legacy_review
