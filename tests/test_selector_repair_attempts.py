import json
import subprocess

from tests.linear_selector_helpers import _accepted_gate, _issue, _select, _tree


REPAIR_INSTRUCTION = (
    "Authorize ALP-2419 in the accepted gate Execute list before continuing post execution review."
)


def _attempt(timestamp):
    return {
        "body": json.dumps(
            {
                "repair_attempts": {
                    "target_issue": "ALP-2418",
                    "repair_instruction": REPAIR_INSTRUCTION,
                    "iteration_timestamp": timestamp,
                }
            },
            separators=(",", ":"),
        ),
        "createdAt": timestamp,
        "updatedAt": timestamp,
    }


def _resolution(timestamp):
    return {
        "body": json.dumps(
            {
                "repair_attempts_resolved": {
                    "target_issue": "ALP-2418",
                    "repair_instruction": REPAIR_INSTRUCTION,
                    "iteration_timestamp": timestamp,
                    "resolution": "Extended the gate Execute line.",
                }
            },
            separators=(",", ":"),
        ),
        "createdAt": timestamp,
        "updatedAt": timestamp,
    }


def _unauthorized_repair_tree(*, review_comments=None, gate_comments=None):
    return _tree(
        _accepted_gate("`ALP-2414`, `ALP-2418`", comments=gate_comments),
        _issue(
            "ALP-2226",
            "Backlog",
            children=[
                _issue("ALP-2414", "Completed worker", state="Worker Done", sort=1),
                _issue(
                    "ALP-2418",
                    "Post execution review",
                    sort=2,
                    comments=review_comments,
                ),
                _issue("ALP-2419", "Corrective gate repair", state="Backlog", sort=3),
            ],
        ),
    )


def _tree_with_master_comments(issue_tree, comments):
    issue_tree["data"]["issue"] = _issue("ALP-2420", "Selector blocker taxonomy", comments=comments)
    return issue_tree


def test_two_unresolved_repair_attempts_promote_workflow_repair_to_agent_stuck():
    selected = _select(
        _unauthorized_repair_tree(
            review_comments=[
                _attempt("2026-01-01T00:00:01Z"),
                _attempt("2026-01-01T00:00:02Z"),
            ]
        )
    )

    assert selected["selected_mode"] == "agent_stuck"
    assert selected["workflow_repair_route"] is False
    assert selected["agent_stuck"] is True
    assert selected["repair_routing"] is None
    assert selected["human_direction"]["identifier"] == "ALP-2418"
    assert "ALP-2418 at 2026-01-01T00:00:01Z" in selected["human_direction"]["classifier_body"]
    assert "ALP-2418 at 2026-01-01T00:00:02Z" in selected["human_direction"]["classifier_body"]


def test_master_parent_attempt_stream_promotes_when_no_review_issue_exists():
    instruction = "Flatten unsupported hierarchy under ALP-2501; Nancy supports only parent and child issues."
    issue_tree = _tree(
        _accepted_gate("`ALP-2501`"),
        _issue(
            "ALP-2226",
            "Backlog",
            children=[
                _issue(
                    "ALP-2501",
                    "Nested worker",
                    children=[_issue("ALP-2502", "Unsupported grandchild")],
                )
            ],
        ),
    )

    selected = _select(
        _tree_with_master_comments(
            issue_tree,
            [
                {
                    "body": json.dumps(
                        {
                            "repair_attempts": {
                                "target_issue": "ALP-2501",
                                "repair_instruction": instruction,
                                "iteration_timestamp": "2026-01-01T00:00:01Z",
                            }
                        },
                        separators=(",", ":"),
                    ),
                    "createdAt": "2026-01-01T00:00:01Z",
                    "updatedAt": "2026-01-01T00:00:01Z",
                },
                {
                    "body": json.dumps(
                        {
                            "repair_attempts": {
                                "target_issue": "ALP-2501",
                                "repair_instruction": instruction,
                                "iteration_timestamp": "2026-01-01T00:00:02Z",
                            }
                        },
                        separators=(",", ":"),
                    ),
                    "createdAt": "2026-01-01T00:00:02Z",
                    "updatedAt": "2026-01-01T00:00:02Z",
                },
            ],
        )
    )

    assert selected["selected_mode"] == "agent_stuck"
    assert "comment on ALP-2420" in selected["human_direction"]["classifier_body"]


def test_later_repair_resolution_comment_resets_attempt_counter():
    selected = _select(
        _unauthorized_repair_tree(
            review_comments=[
                _attempt("2026-01-01T00:00:01Z"),
                _attempt("2026-01-01T00:00:02Z"),
            ],
            gate_comments=[_resolution("2026-01-01T00:00:03Z")],
        )
    )

    assert selected["selected_mode"] == "workflow_repair"
    assert selected["workflow_repair_route"] is True
    assert selected["agent_stuck"] is False
    assert selected["repair_routing"] == {
        "target_issue": "ALP-2418",
        "target_mode": "post_execution_review",
        "repair_instruction": REPAIR_INSTRUCTION,
    }


def test_repair_attempt_writer_is_idempotent_for_one_routing_decision(tmp_path):
    script = r'''
        source src/linear/selector.sh

        export NANCY_CURRENT_TASK_DIR="$1"
        export NANCY_SESSION_ID="nancy-ALP-2420-test-iter1"
        calls="$NANCY_CURRENT_TASK_DIR/calls"

        linear::issue:comment:add() {
            printf '%s\t%s\n' "$1" "$2" >>"$calls"
        }

        selection='{"workflow_repair_route":true,"selected_issue":{"identifier":"ALP-2418","review":true},"repair_routing":{"target_issue":"ALP-2418","repair_instruction":"Authorize ALP-2419 in the accepted gate Execute list before continuing post execution review."}}'

        linear::selector:write_repair_attempt "$selection" "ALP-2420" "2026-01-01T00:00:03Z"
        linear::selector:write_repair_attempt "$selection" "ALP-2420" "2026-01-01T00:00:03Z"
        cat "$calls"
    '''
    result = subprocess.run(
        ["bash", "-c", script, "writer-test", str(tmp_path)],
        text=True,
        capture_output=True,
        check=False,
    )

    assert result.returncode == 0, result.stderr + result.stdout
    assert result.stdout.count("repair_attempts") == 1
    assert result.stdout.startswith("ALP-2418\t")
    assert '"target_issue":"ALP-2418"' in result.stdout
    assert '"iteration_timestamp":"2026-01-01T00:00:03Z"' in result.stdout


def test_repair_attempt_writer_falls_back_to_master_parent_without_review_target(tmp_path):
    script = r'''
        source src/linear/selector.sh

        export NANCY_CURRENT_TASK_DIR="$1"
        export NANCY_SESSION_ID="nancy-ALP-2420-test-iter2"
        calls="$NANCY_CURRENT_TASK_DIR/calls"

        linear::issue:comment:add() {
            printf '%s\t%s\n' "$1" "$2" >>"$calls"
        }

        selection='{"workflow_repair_route":true,"selected_issue":{"identifier":"ALP-2501","review":false},"repair_routing":{"target_issue":"ALP-2501","repair_instruction":"Flatten unsupported hierarchy under ALP-2501; Nancy supports only parent and child issues."}}'
        linear::selector:write_repair_attempt "$selection" "ALP-2420" "2026-01-01T00:00:03Z"
        cat "$calls"
    '''
    result = subprocess.run(
        ["bash", "-c", script, "writer-test", str(tmp_path)],
        text=True,
        capture_output=True,
        check=False,
    )

    assert result.returncode == 0, result.stderr + result.stdout
    assert result.stdout.startswith("ALP-2420\t")
    assert '"target_issue":"ALP-2501"' in result.stdout
