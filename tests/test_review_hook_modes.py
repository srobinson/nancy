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


def test_post_execution_review_primary_pass_uses_worker_agent():
    script = r'''
        source src/cmd/start.sh

        if _start_mode_uses_reviewer_agent post_execution_review; then
            echo "post execution review primary pass should use worker agent"
            exit 1
        fi

        _start_mode_uses_reviewer_agent agent_issue_review
    '''

    _run_review_mode_script(script)


def test_post_execution_review_ends_after_one_agent_turn():
    script = r'''
        source src/cmd/start.sh

        _start_has_reviewer_agent() { return 0; }

        if _start_should_run_reviewer_after_worker post_execution_review ALP-2154; then
            echo "post execution review should end after one agent turn"
            exit 1
        fi

        planning_followup=$(_start_reviewer_followup_mode planning)
        if [[ "$planning_followup" != "agent_issue_review" ]]; then
            echo "expected planning followup to use agent_issue_review, got $planning_followup"
            exit 1
        fi
    '''

    _run_review_mode_script(script)


def test_issues_file_wraps_column_output_in_text_fence():
    script = r'''
        source src/cmd/start.sh

        NANCY_CURRENT_TASK_DIR=$(mktemp -d)
        export NANCY_CURRENT_TASK_DIR

        linear::issue:sub() {
            cat <<'JSON'
{"data":{"issues":{"nodes":[{"identifier":"ALP-1","title":"Parent issue","priorityLabel":"Medium","state":{"name":"Worker Done"},"labels":{"nodes":[]},"subIssueSortOrder":1,"children":{"nodes":[{"identifier":"ALP-2","title":"Child issue","priorityLabel":"Low","state":{"name":"Todo"},"labels":{"nodes":[]},"subIssueSortOrder":1}]}}]}}}
JSON
        }
        linear::issue:sub:statuses() {
            echo '{}'
        }
        linear::selector:evaluate() {
            echo '{"selected_issue":{"agent_role":null},"selected_mode":"execution"}'
        }
        linear::selector:render_summary() {
            printf '## Selector Decision\n\nISSUES.md is selector evidence only.\n\n'
        }
        linear::selector:render_prompt_context() {
            echo ''
        }
        linear::selector:row_marker_jq() {
            cat <<'JQ'
def marker($selector): "-";
JQ
        }

        _start_create_issues_file ALP-0 project-0 ALP-0 "Root issue"

        python3 - "$NANCY_CURRENT_TASK_DIR/ISSUES.md" <<'PY'
import sys
import re
from pathlib import Path

content = Path(sys.argv[1]).read_text()
open_fence = content.index("```text\n")
close_fence = content.index("\n```", open_fence)
table = content[open_fence:close_fence]

assert "ISSUE_ID" in table
assert "Priority" in table
assert "Tags" not in table
assert "Selector" not in table
assert re.search(r"\[X\]\s+ALP-1", table)
assert re.search(r"\[ \]\s+↳ ALP-2", table)
assert content.count("```text") == 1
assert content.rstrip().endswith("```")
PY
    '''

    _run_review_mode_script(script)


def test_null_selection_final_completion_marks_task_complete():
    script = r'''
        source src/cmd/start.sh
        source src/task/task.sh
        source src/linear/selector.sh

        NANCY_TASK_DIR=$(mktemp -d)
        export NANCY_TASK_DIR
        mkdir -p "$NANCY_TASK_DIR/ALP-1"

        updated_state=""
        linear::issue:update:status() {
            updated_state="$1:$2"
        }
        ui::banner() {
            :
        }

        selection='}'

        _start_handle_null_selection ALP-1 project-1 final_completion "$selection"

        if [[ "$updated_state" != "project-1:Worker Done" ]]; then
            echo "parent was not closed: $updated_state"
            exit 1
        fi
        if [[ ! -f "$NANCY_TASK_DIR/ALP-1/COMPLETE" ]]; then
            echo "COMPLETE was not created"
            exit 1
        fi
    '''

    _run_review_mode_script(script)


def test_null_selection_without_final_completion_stops_before_agent_launch():
    script = r'''
        source src/cmd/start.sh

        linear::selector:render_summary() {
            printf 'selector summary\n'
        }
        log::error() {
            printf '%s\n' "$*"
        }

        selection='{"selected_mode":"execution","selected_issue":null,"eligibility_reason":"No eligible issue after gate, status, and blocker checks"}'

        if _start_handle_null_selection ALP-1 project-1 execution "$selection"; then
            echo "null execution selection should stop"
            exit 1
        fi
    '''

    _run_review_mode_script(script)


def test_needs_human_direction_pauses_without_completion():
    script = r'''
        source src/cmd/start.sh
        source src/task/task.sh
        source src/linear/selector.sh

        NANCY_TASK_DIR=$(mktemp -d)
        export NANCY_TASK_DIR
        mkdir -p "$NANCY_TASK_DIR/ALP-1"

        updated_state=""
        linear::issue:update:status() {
            updated_state="$1:$2"
        }

        selection='{"selected_mode":"needs_human_direction","selected_issue":null,"eligibility_reason":"Needs human direction","human_direction":{"identifier":"ALP-2","title":"Post execution review","state":"In Progress","blocker":"Outcome: Needs human direction. Decide smoke timing."}}'

        output=$(_start_handle_null_selection ALP-1 project-1 needs_human_direction "$selection")
        status=$?

        if [[ "$status" -ne 2 ]]; then
            echo "expected status 2, got $status"
            exit 1
        fi
        if [[ -n "$updated_state" ]]; then
            echo "parent should not be closed: $updated_state"
            exit 1
        fi
        if [[ -f "$NANCY_TASK_DIR/ALP-1/COMPLETE" ]]; then
            echo "COMPLETE should not be created"
            exit 1
        fi
        if [[ ! -f "$NANCY_TASK_DIR/ALP-1/PAUSE" ]]; then
            echo "PAUSE was not created"
            exit 1
        fi
        if [[ "$output" != *"BLOCKER: Needs human direction"* || "$output" != *"Outcome: Needs human direction"* ]]; then
            echo "blocker output missing"
            printf '%s\n' "$output"
            exit 1
        fi
    '''

    _run_review_mode_script(script)


def test_start_clears_stale_stop_and_complete_sentinels():
    script = r'''
        source src/cmd/start.sh

        NANCY_TASK_DIR=$(mktemp -d)
        export NANCY_TASK_DIR
        mkdir -p "$NANCY_TASK_DIR/ALP-1"
        echo stale >"$NANCY_TASK_DIR/ALP-1/STOP"
        echo stale >"$NANCY_TASK_DIR/ALP-1/COMPLETE"

        _start_clear_stale_sentinels ALP-1

        if [[ -f "$NANCY_TASK_DIR/ALP-1/STOP" ]]; then
            echo "STOP should be cleared"
            exit 1
        fi
        if [[ -f "$NANCY_TASK_DIR/ALP-1/COMPLETE" ]]; then
            echo "COMPLETE should be cleared"
            exit 1
        fi
    '''

    _run_review_mode_script(script)
