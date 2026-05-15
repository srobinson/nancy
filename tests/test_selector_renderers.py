import json
import os
import subprocess
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


def _render(function_name, selection, extra_env=None):
    script = f"""
        source src/linear/selector.sh
        {function_name} "$SELECTION"
    """
    result = subprocess.run(
        ["bash", "-c", script],
        cwd=REPO_ROOT,
        env={**os.environ, "SELECTION": json.dumps(selection), **(extra_env or {})},
        text=True,
        capture_output=True,
        check=False,
    )
    assert result.returncode == 0, result.stderr + result.stdout
    return result.stdout


def test_render_repair_route_names_target_mode_and_instruction(tmp_path):
    output = _render(
        "linear::selector:render_repair_route",
        {
            "selected_mode": "workflow_repair",
            "selected_issue": {
                "identifier": "ALP-2418",
                "title": "Post execution review",
            },
            "workflow_repair_route": True,
            "repair_routing": {
                "target_issue": "ALP-2418",
                "target_mode": "post_execution_review",
                "repair_instruction": "Authorize ALP-2419 in the accepted gate Execute list.",
            },
        },
        {"NANCY_TASK_DIR": str(tmp_path)},
    )

    assert "INFO: Workflow repair route" in output
    assert "BLOCKER" not in output
    assert "Target issue: `ALP-2418` Post execution review" in output
    assert "Target mode: `post_execution_review`" in output
    assert "Repair instruction: Authorize ALP-2419" in output
    assert not list(tmp_path.rglob("PAUSE"))


def test_render_loop_blocker_surfaces_classifier_fields():
    output = _render(
        "linear::selector:render_loop_blocker",
        {
            "selected_mode": "agent_stuck",
            "selected_issue": None,
            "eligibility_reason": "Agent is stuck in a self diagnosed loop",
            "human_direction": {
                "identifier": "ALP-3002",
                "title": "Post execution review",
                "state": "In Progress",
                "blocker": "Outcome: Needs human direction.",
                "classification": "loop",
                "classifier_body": "\n".join(
                    [
                        "Outcome: Needs human direction.",
                        "Classification: loop",
                        "What was tried: Repaired the gate twice.",
                        "Loop evidence: Same unauthorized issue returned.",
                        "Smallest unblock: Confirm escalation.",
                    ]
                ),
            },
        },
    )

    assert "BLOCKER: Agent stuck" in output
    assert "Issue: `ALP-3002` Post execution review" in output
    assert "What was tried: Repaired the gate twice." in output
    assert "Loop evidence: Same unauthorized issue returned." in output
    assert "Smallest unblock imagined: Confirm escalation." in output


def test_render_decision_blocker_surfaces_classifier_fields():
    output = _render(
        "linear::selector:render_decision_blocker",
        {
            "selected_mode": "product_decision",
            "selected_issue": None,
            "eligibility_reason": "Product or scope decision needed from human",
            "human_direction": {
                "identifier": "ALP-3002",
                "title": "Post execution review",
                "state": "Todo",
                "blocker": "Exact unresolved question: Should smoke run before publish?",
                "classification": "decision",
                "classifier_body": "\n".join(
                    [
                        "Outcome: Needs human direction.",
                        "Classification: decision",
                        "Exact unresolved question: Should smoke run before publish?",
                        "Positions: before publish reduces risk; after publish matches client timing.",
                        "Smallest Stuart decision: pick release smoke timing.",
                        "Safe work while waiting: Update docs.",
                    ]
                ),
            },
        },
    )

    assert "BLOCKER: Product decision needed" in output
    assert "Issue: `ALP-3002` Post execution review" in output
    assert "Question: Should smoke run before publish?" in output
    assert "Positions: before publish reduces risk" in output
    assert "Smallest decision: pick release smoke timing." in output
    assert "Safe work while waiting: Update docs." in output


def test_render_prompt_context_includes_workflow_repair_instruction():
    output = _render(
        "linear::selector:render_prompt_context",
        {
            "selected_mode": "workflow_repair",
            "selected_issue": {
                "identifier": "ALP-2418",
                "title": "Post execution review",
            },
            "eligibility_reason": "Workflow repair required",
            "repair_routing": {
                "target_issue": "ALP-2418",
                "target_mode": "post_execution_review",
                "repair_instruction": "Authorize ALP-2419 in the accepted gate Execute list.",
            },
        },
    )

    assert "- Mode: `workflow_repair`" in output
    assert "- Issue: `ALP-2418` Post execution review" in output
    assert (
        "- Repair instruction: Authorize ALP-2419 in the accepted gate Execute list."
        in output
    )
