import subprocess
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


def _run_dispatch_script(script):
    result = subprocess.run(
        ["bash", "-c", script],
        cwd=REPO_ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    assert result.returncode == 0, result.stderr + result.stdout
    return result.stdout


def test_product_decision_pauses_with_decision_renderer():
    script = r'''
        source src/cmd/start.sh
        source src/task/task.sh
        source src/linear/selector.sh

        NANCY_TASK_DIR=$(mktemp -d)
        export NANCY_TASK_DIR
        mkdir -p "$NANCY_TASK_DIR/ALP-1"

        linear::issue:update:status() {
            echo "parent should not be closed"
            exit 1
        }

        selection='{"selected_mode":"product_decision","selected_issue":null,"eligibility_reason":"Product or scope decision needed from human","human_direction":{"identifier":"ALP-2","title":"Post execution review","state":"Todo","blocker":"Exact unresolved question: Should smoke run before publish?","classification":"decision","classifier_body":"Outcome: Needs human direction.\nClassification: decision\nExact unresolved question: Should smoke run before publish?\nPositions: before publish reduces risk; after publish matches timing.\nSmallest Stuart decision: pick release smoke timing.\nSafe work while waiting: Update docs."}}'

        output=$(_start_handle_null_selection ALP-1 project-1 product_decision "$selection")
        status=$?

        if [[ "$status" -ne 2 ]]; then
            echo "expected status 2, got $status"
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
        if [[ "$output" != *"BLOCKER: Product decision needed"* || "$output" != *"Question: Should smoke run before publish?"* ]]; then
            echo "decision blocker output missing"
            printf '%s\n' "$output"
            exit 1
        fi
        if [[ "$(cat "$NANCY_TASK_DIR/ALP-1/PAUSE")" != *"Reason: Product decision needed"* ]]; then
            echo "PAUSE reason missing"
            exit 1
        fi
    '''

    _run_dispatch_script(script)


def test_workflow_repair_null_selection_is_not_a_pause_case():
    script = r'''
        source src/cmd/start.sh
        source src/linear/selector.sh

        NANCY_TASK_DIR=$(mktemp -d)
        export NANCY_TASK_DIR
        mkdir -p "$NANCY_TASK_DIR/ALP-1"

        log::error() {
            printf '%s\n' "$*"
        }

        selection='{"selected_mode":"workflow_repair","selected_issue":null,"eligibility_reason":"Workflow repair requires a selected repair target","completion_threshold":{"blocker_release_states":["Worker Done"]}}'

        output=$(_start_handle_null_selection ALP-1 project-1 workflow_repair "$selection" 2>&1)
        status=$?

        if [[ "$status" -ne 1 ]]; then
            echo "expected status 1, got $status"
            exit 1
        fi
        if [[ -f "$NANCY_TASK_DIR/ALP-1/PAUSE" ]]; then
            echo "workflow repair null selection should not create PAUSE"
            exit 1
        fi
        if [[ "$output" != *"No eligible Linear issue selected"* ]]; then
            echo "missing null selection refusal"
            printf '%s\n' "$output"
            exit 1
        fi
    '''

    _run_dispatch_script(script)
