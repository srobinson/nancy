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


def test_post_execution_review_primary_pass_uses_reviewer_agent():
    script = r'''
        source src/cmd/start.sh

        if ! _start_mode_uses_reviewer_agent post_execution_review; then
            echo "post execution review primary pass should route to reviewer agent"
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


def test_selector_output_validation_rejects_trailing_parse_garbage():
    script = r'''
        source src/cmd/start.sh

        log::error() {
            printf '%s\n' "$*"
        }

        selection='{"selected_mode":"corrective_resolution","selected_issue":{"identifier":"ALP-1"}}
}'

        if _start_validate_selector_output "$selection"; then
            echo "selector validation should reject trailing garbage"
            exit 1
        fi
    '''

    _run_review_mode_script(script)


def test_create_issues_file_rejects_malformed_selector_before_loop_branch():
    script = r'''
        source src/cmd/start.sh

        NANCY_CURRENT_TASK_DIR=$(mktemp -d)
        export NANCY_CURRENT_TASK_DIR

        log::error() {
            printf '%s\n' "$*"
        }
        linear::issue:sub() {
            printf '{"data":{"issues":{"nodes":[]}}}'
        }
        linear::issue:sub:statuses() {
            printf '{"data":{"issues":{"nodes":[]}}}'
        }
        linear::selector:evaluate() {
            printf '{"selected_mode":"execution","selected_issue":{"identifier":"ALP-1"}}\n}'
        }

        output=$(_start_create_issues_file ALP-1 project-1 ALP-1 "Project" 2>&1)
        status=$?

        if [[ "$status" -eq 0 ]]; then
            echo "malformed selector should fail"
            exit 1
        fi
        if [[ "$output" != *"Linear selector returned invalid JSON"* ]]; then
            echo "missing selector error: $output"
            exit 1
        fi
        if [[ "$output" == *"jq: parse error"* ]]; then
            echo "jq parse noise leaked"
            exit 1
        fi
    '''

    _run_review_mode_script(script)


def test_start_stops_when_selector_issue_file_creation_fails():
    script = r'''
        source src/cmd/start.sh

        NANCY_DIR=$(mktemp -d)
        NANCY_TASK_DIR=$(mktemp -d)
        NANCY_CURRENT_TASK_DIR="$NANCY_TASK_DIR/ALP-1"
        export NANCY_DIR NANCY_TASK_DIR NANCY_CURRENT_TASK_DIR
        mkdir -p "$NANCY_CURRENT_TASK_DIR"

        task::count_sessions() {
            printf '0\n'
        }
        _start_clear_stale_sentinels() {
            :
        }
        _start_fetch_linear_context() {
            local -n project_ref=$2
            project_ref[id]="project-1"
            project_ref[identifier]="ALP-1"
            project_ref[title]="Project"
            project_ref[description]=""
        }
        _start_setup_worktree() {
            local -n worktree_ref=$2
            worktree_ref[dir]="."
        }
        config::get_agent() {
            printf 'bash\n'
        }
        cli::current() {
            printf 'bash\n'
        }
        deps::exists() {
            return 0
        }
        _start_print_start_info() {
            :
        }
        _start_create_issues_file() {
            return 1
        }
        _start_handle_null_selection() {
            echo "null selection handler should not run"
            exit 1
        }

        cmd::start ALP-1
        status=$?

        if [[ "$status" -ne 1 ]]; then
            echo "expected status 1, got $status"
            exit 1
        fi
    '''

    _run_review_mode_script(script)


def test_null_selection_check_rejects_invalid_json_without_jq_parse_noise():
    script = r'''
        source src/cmd/start.sh

        log::error() {
            printf '%s\n' "$*"
        }

        selection='{"selected_mode":"corrective_resolution","selected_issue":{"identifier":"ALP-1"}}
}'

        output=$(_start_selection_has_no_issue "$selection" 2>&1)
        status=$?

        if [[ "$status" -ne 2 ]]; then
            echo "expected status 2, got $status"
            exit 1
        fi
        if [[ "$output" == *"jq: parse error"* ]]; then
            echo "jq parse noise leaked"
            exit 1
        fi
        if [[ "$output" != *"Linear selector JSON became invalid"* ]]; then
            echo "missing clear selector error: $output"
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


def test_needs_human_direction_malformed_selector_does_not_leak_jq_parse_error():
    script = r'''
        source src/cmd/start.sh
        source src/task/task.sh
        source src/linear/selector.sh

        NANCY_TASK_DIR=$(mktemp -d)
        export NANCY_TASK_DIR
        mkdir -p "$NANCY_TASK_DIR/ALP-1"

        selection='{"selected_mode":"needs_human_direction","selected_issue":null,"eligibility_reason":"Needs human direction","human_direction":{"identifier":"ALP-2","title":"Post execution review","state":"Worker Done","blocker":"Outcome: Needs human direction."}}
}'

        output=$(_start_handle_null_selection ALP-1 project-1 needs_human_direction "$selection" 2>&1)
        status=$?

        if [[ "$status" -ne 2 ]]; then
            echo "expected status 2, got $status"
            exit 1
        fi
        if [[ "$output" == *"jq: parse error"* ]]; then
            echo "jq parse noise leaked"
            printf '%s\n' "$output"
            exit 1
        fi
        if [[ "$output" != *"BLOCKER: Selector JSON invalid"* ]]; then
            echo "missing invalid selector blocker"
            printf '%s\n' "$output"
            exit 1
        fi
    '''

    _run_review_mode_script(script)


def test_pause_wait_message_names_resume_and_stop_commands():
    script = r'''
        source src/cmd/start.sh

        log::info() {
            printf 'INFO %s\n' "$*"
        }
        ui::muted() {
            printf '%s\n' "$*"
        }

        NANCY_TASK_DIR=$(mktemp -d)
        export NANCY_TASK_DIR
        mkdir -p "$NANCY_TASK_DIR/ALP-1"
        touch "$NANCY_TASK_DIR/ALP-1/PAUSE"

        (sleep 0.1; rm -f "$NANCY_TASK_DIR/ALP-1/PAUSE") &
        output=$(_start_wait_while_paused ALP-1)
        wait

        if [[ "$output" != *"nancy unpause ALP-1"* ]]; then
            echo "missing unpause command"
            printf '%s\n' "$output"
            exit 1
        fi
        if [[ "$output" != *"nancy stop ALP-1"* ]]; then
            echo "missing stop command"
            printf '%s\n' "$output"
            exit 1
        fi
        if [[ "$output" == *"Ctrl+C to stop"* ]]; then
            echo "old ctrl-c wording still present"
            printf '%s\n' "$output"
            exit 1
        fi
    '''

    _run_review_mode_script(script)


def test_stop_removes_pause_lock_to_release_paused_worker():
    script = r'''
        source src/cmd/stop.sh

        NANCY_TASK_DIR=$(mktemp -d)
        export NANCY_TASK_DIR
        mkdir -p "$NANCY_TASK_DIR/ALP-1"
        touch "$NANCY_TASK_DIR/ALP-1/PAUSE"

        task::exists() {
            return 0
        }
        sidecar::stop() {
            :
        }
        notify::stop_all_watchers() {
            :
        }
        ui::muted() {
            :
        }
        ui::success() {
            :
        }

        cmd::stop ALP-1

        if [[ ! -f "$NANCY_TASK_DIR/ALP-1/STOP" ]]; then
            echo "STOP was not created"
            exit 1
        fi
        if [[ -f "$NANCY_TASK_DIR/ALP-1/PAUSE" ]]; then
            echo "PAUSE should be removed by stop"
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


def test_sidecar_detects_claude_prefixed_end_turn():
    script = r'''
        source src/sidecar/sidecar.sh

        pane_text=$(printf '\342\217\272 <END_TURN>\n')

        if ! sidecar::_detect_exit_ready "$pane_text"; then
            echo "sidecar did not detect Claude prefixed END_TURN"
            exit 1
        fi
    '''

    _run_review_mode_script(script)


def test_sidecar_uses_handover_timeout_instead_of_worker_done_breakpoint():
    script = r'''
        source src/sidecar/sidecar.sh

        export NANCY_TASK_DIR
        NANCY_TASK_DIR=$(mktemp -d)
        task=ALP-test
        mkdir -p "$NANCY_TASK_DIR/$task"
        echo "$$" > "$NANCY_TASK_DIR/$task/.worker_pid"

        time_file=$(mktemp)
        printf '100\n' > "$time_file"
        date() {
            if [[ "${1:-}" == "+%s" ]]; then
                current_time=$(cat "$time_file")
                current_time=$((current_time + 1))
                printf '%s\n' "$current_time" > "$time_file"
                printf '%s\n' "$current_time"
                return 0
            fi
            command date "$@"
        }

        sleep() { :; }
        log::debug() { :; }
        log::info() { :; }
        log::warn() { :; }
        sidecar::_pane_exists() { return 0; }
        sidecar::_worker_alive() { return 0; }
        sidecar::_extract_context_percent() { printf '70\n'; }
        sidecar::_request_handover() { :; }
        sidecar::_handover_changed() { return 1; }
        sidecar::_capture_worker() {
            printf 'Successfully loaded skill: session-handover\n'
            printf 'Called linear.save_issue({"state":"Worker Done"})\n'
        }
        sidecar::_kill_worker() {
            printf '%s\n' "$3"
            return 0
        }

        output=$(
            NANCY_SIDECAR_POLL_SECONDS=0 \
            NANCY_SIDECAR_HANDOVER_TIMEOUT_SECONDS=1 \
            sidecar::_monitor_loop "$task" "%1" "$PWD" worker
        )

        if [[ "$output" == "breakpoint issue-transition" ]]; then
            echo "handover activity allowed Worker Done breakpoint"
            exit 1
        fi
        if [[ "$output" != "handover timeout" ]]; then
            echo "expected handover timeout, got: $output"
            exit 1
        fi
    '''

    _run_review_mode_script(script)


def test_turn_exit_instruction_survives_skill_confirmation_steps():
    script = r'''
        source src/cmd/start.sh

        codex_text=$(_start_turn_exit_instruction codex)
        claude_text=$(_start_turn_exit_instruction claude)

        for text in "$codex_text" "$claude_text"; do
            if [[ "$text" != *"This instruction also applies after any skill runs"* ]]; then
                echo "turn exit instruction does not override skill confirmations"
                exit 1
            fi
            if [[ "$text" != *"then print the required turn exit line"* ]]; then
                echo "turn exit instruction does not require final marker after skill output"
                exit 1
            fi
        done
    '''

    _run_review_mode_script(script)
