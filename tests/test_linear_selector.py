import json
import subprocess
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


def _labels(*names):
    return {"nodes": [{"name": name, "parent": {"name": "Agent Role" if name.endswith("-engineer") else "Type"}} for name in names]}


def _issue(identifier, title, state="Todo", sort=0, description="", children=None, blockers=None, labels=None, comments=None):
    return {
        "identifier": identifier,
        "title": title,
        "description": description,
        "priorityLabel": "High",
        "subIssueSortOrder": sort,
        "state": {"name": state},
        "labels": _labels(*(labels or [])),
        "comments": {
            "nodes": [
                {
                    "body": comment["body"],
                    "createdAt": comment.get("createdAt", f"2026-01-01T00:00:0{idx}Z"),
                    "updatedAt": comment.get("updatedAt", f"2026-01-01T00:00:0{idx}Z"),
                }
                for idx, comment in enumerate(comments or [])
            ]
        },
        "relations": {"nodes": []},
        "inverseRelations": {
            "nodes": [
                {
                    "type": "blocks",
                    "issue": {
                        "identifier": blocker["identifier"],
                        "title": blocker.get("title", blocker["identifier"]),
                        "state": {"name": blocker["state"]},
                    },
                }
                for blocker in blockers or []
            ]
        },
        "children": {"nodes": children or []},
    }


def _tree(*issues):
    return {"data": {"issues": {"nodes": list(issues)}}}


def _select(issue_tree):
    return _select_with_status(issue_tree, issue_tree)


def _select_with_status(issue_tree, status_tree):
    script = (
        "source src/linear/selector.sh; "
        "linear::selector:evaluate \"$1\" \"$2\""
    )
    result = subprocess.run(
        ["bash", "-c", script, "selector", json.dumps(issue_tree), json.dumps(status_tree)],
        cwd=REPO_ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    assert result.returncode == 0, result.stderr
    return json.loads(result.stdout)


def _markers(issue_tree, selection):
    script = (
        "source src/linear/selector.sh; "
        "jq -r --argjson selector \"$2\" \"$(linear::selector:row_marker_jq) "
        ".data.issues.nodes[] | (.children.nodes[]? // .) | [.identifier, (. | marker(\\$selector))] | @tsv\" <<<\"$1\""
    )
    result = subprocess.run(
        ["bash", "-c", script, "markers", json.dumps(issue_tree), json.dumps(selection)],
        cwd=REPO_ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    assert result.returncode == 0, result.stderr
    return dict(line.split("\t", 1) for line in result.stdout.strip().splitlines())


def _accepted_gate(execute_line):
    return _issue(
        "ALP-2220",
        "Gate review and execution readiness",
        state="Worker Done",
        sort=1,
        description=(
            "Planning complete. Outcome: Ready for execution.\n"
            "Authorized execution parent: `ALP-2226` Backlog.\n"
            f"Execute: {execute_line}.\n"
        ),
    )


def test_backlog_children_are_unauthorized_before_gate_acceptance():
    backlog_child = _issue("ALP-2225", "Implement gate mode prompt templates", sort=1)
    issue_tree = _tree(
        _issue("ALP-2217", "Plan Linear issue selection", sort=1),
        _issue("ALP-2220", "Gate review and execution readiness", sort=2),
        _issue("ALP-2226", "Backlog", sort=3, children=[backlog_child]),
    )

    selected = _select(issue_tree)

    assert selected["selected_mode"] == "planning"
    assert selected["selected_issue"]["identifier"] == "ALP-2217"
    assert selected["unauthorized_backlog_candidates"] == [
        {
            "identifier": "ALP-2225",
            "title": "Implement gate mode prompt templates",
            "state": "Todo",
            "parent_identifier": "ALP-2226",
            "gate_review_issue": "ALP-2220",
        }
    ]


def test_worker_done_blocker_releases_downstream_execution_issue():
    issue_tree = _tree(
        _accepted_gate("`ALP-2227`, `ALP-2225`"),
        _issue(
            "ALP-2226",
            "Backlog",
            children=[
                _issue("ALP-2227", "Implement selector", state="Worker Done", sort=1),
                _issue(
                    "ALP-2225",
                    "Implement prompts",
                    sort=2,
                    blockers=[{"identifier": "ALP-2227", "state": "Worker Done"}],
                ),
            ],
        ),
    )

    selected = _select(issue_tree)

    assert selected["selected_mode"] == "execution"
    assert selected["selected_issue"]["identifier"] == "ALP-2225"
    assert selected["blocked_candidates"] == []
    assert selected["completion_threshold"]["blocker_release_states"] == [
        "Worker Done",
        "Done",
        "Canceled",
        "Duplicate",
    ]


def test_unreleased_blocker_is_reported_and_not_selected():
    issue_tree = _tree(
        _accepted_gate("`ALP-2227`, `ALP-2225`"),
        _issue(
            "ALP-2226",
            "Backlog",
            children=[
                _issue("ALP-2227", "Implement selector", sort=1),
                _issue(
                    "ALP-2225",
                    "Implement prompts",
                    sort=2,
                    blockers=[{"identifier": "ALP-2227", "state": "Todo"}],
                ),
            ],
        ),
    )

    selected = _select(issue_tree)

    assert selected["selected_issue"]["identifier"] == "ALP-2227"
    assert selected["blocked_candidates"][0]["identifier"] == "ALP-2225"
    assert selected["blocked_candidates"][0]["blockers"] == ["ALP-2227"]
    assert _markers(issue_tree, selected)["ALP-2225"] == "BLOCKED: ALP-2227"


def test_corrective_issue_outranks_post_execution_review():
    review = _issue("ALP-3002", "Post execution review", sort=1)
    corrective = _issue("ALP-3001", "Fix regression", sort=2, labels=["Corrective"])
    issue_tree = _tree(
        _accepted_gate("`ALP-3002`, `ALP-3001`"),
        _issue("ALP-2226", "Backlog", children=[review, corrective]),
    )

    selected = _select(issue_tree)

    assert selected["selected_mode"] == "corrective_resolution"
    assert selected["selected_issue"]["identifier"] == "ALP-3001"
    assert selected["corrective_priority_evidence"]["corrective_outranks_review"] is True


def test_open_backlog_child_outside_accepted_gate_requires_human_direction():
    issue_tree = _tree(
        _accepted_gate("`ALP-3000`"),
        _issue(
            "ALP-2226",
            "Backlog",
            children=[
                _issue("ALP-3000", "Implemented worker issue", state="Worker Done", sort=1),
                _issue("ALP-3001", "Corrective: Fix reviewed defect", sort=2),
            ],
        ),
    )

    selected = _select(issue_tree)

    assert selected["selected_mode"] == "needs_human_direction"
    assert selected["selected_issue"] is None
    assert selected["requires_human_direction"] is True
    assert "outside accepted gate" in selected["eligibility_reason"]
    assert selected["unauthorized_backlog_candidates"][0]["identifier"] == "ALP-3001"


def test_post_execution_review_accepts_worker_done_blockers():
    issue_tree = _tree(
        _accepted_gate("`ALP-3000`, `ALP-3002`"),
        _issue(
            "ALP-2226",
            "Backlog",
            children=[
                _issue("ALP-3000", "Implemented worker issue", state="Worker Done", sort=1),
                _issue(
                    "ALP-3002",
                    "Post execution review",
                    sort=2,
                    blockers=[{"identifier": "ALP-3000", "state": "Worker Done"}],
                ),
            ],
        ),
    )

    selected = _select(issue_tree)

    assert selected["selected_mode"] == "post_execution_review"
    assert selected["selected_issue"]["identifier"] == "ALP-3002"
    assert selected["blocked_candidates"] == []
    assert selected["completion_threshold"]["blocker_release_states"] == [
        "Worker Done",
        "Done",
        "Canceled",
        "Duplicate",
    ]


def test_canceled_or_duplicate_blocker_does_not_block_selection():
    issue_tree = _tree(
        _accepted_gate("`ALP-3001`, `ALP-3002`"),
        _issue(
            "ALP-2226",
            "Backlog",
            children=[
                _issue(
                    "ALP-3001",
                    "Has canceled blocker",
                    sort=1,
                    blockers=[{"identifier": "ALP-9999", "state": "Canceled"}],
                ),
                _issue(
                    "ALP-3002",
                    "Has duplicate blocker",
                    sort=2,
                    blockers=[{"identifier": "ALP-9998", "state": "Duplicate"}],
                ),
            ],
        ),
    )

    selected = _select(issue_tree)

    assert selected["selected_mode"] == "execution"
    assert selected["selected_issue"]["identifier"] == "ALP-3001"
    assert selected["blocked_candidates"] == []


def test_grandchildren_trigger_needs_human_direction():
    grandchild = _issue("ALP-4001", "Too deep", sort=1)
    issue_tree = _tree(
        _accepted_gate("`ALP-3001`"),
        _issue(
            "ALP-2226",
            "Backlog",
            children=[
                _issue("ALP-3001", "Has children", sort=1, children=[grandchild]),
            ],
        ),
    )

    selected = _select(issue_tree)

    assert selected["selected_mode"] == "needs_human_direction"
    assert selected["selected_issue"] is None
    assert selected["requires_human_direction"] is True


def test_post_execution_review_needs_human_direction_blocks_final_completion():
    issue_tree = _tree(
        _accepted_gate("`ALP-3000`, `ALP-3002`"),
        _issue(
            "ALP-2226",
            "Backlog",
            children=[
                _issue("ALP-3000", "Implemented worker issue", state="Worker Done", sort=1),
            ],
        ),
    )
    status_tree = _tree(
        _accepted_gate("`ALP-3000`, `ALP-3002`"),
        _issue(
            "ALP-2226",
            "Backlog",
            children=[
                _issue("ALP-3000", "Implemented worker issue", state="Worker Done", sort=1),
                _issue(
                    "ALP-3002",
                    "Post execution review",
                    state="Done",
                    sort=2,
                    comments=[
                        {
                            "body": "Outcome: Needs human direction. Smallest Stuart decision: pick release smoke timing.",
                            "createdAt": "2026-01-01T00:00:01Z",
                            "updatedAt": "2026-01-01T00:00:01Z",
                        }
                    ],
                ),
            ],
        ),
    )

    selected = _select_with_status(issue_tree, status_tree)

    assert selected["selected_mode"] == "needs_human_direction"
    assert selected["selected_issue"] is None
    assert selected["human_direction"]["identifier"] == "ALP-3002"
    assert "Needs human direction" in selected["human_direction"]["blocker"]


def test_human_direction_comment_releases_review_back_to_post_execution_review():
    old_blocker = {
        "body": "Outcome: Needs human direction. Smallest Stuart decision: pick release smoke timing.",
        "createdAt": "2026-01-01T00:00:01Z",
        "updatedAt": "2026-01-01T00:00:01Z",
    }
    human_answer = {
        "body": "Human direction: smoke after publish.",
        "createdAt": "2026-01-01T00:00:02Z",
        "updatedAt": "2026-01-01T00:00:02Z",
    }
    issue_tree = _tree(
        _accepted_gate("`ALP-3000`, `ALP-3002`"),
        _issue(
            "ALP-2226",
            "Backlog",
            children=[
                _issue("ALP-3000", "Implemented worker issue", state="Worker Done", sort=1),
                _issue(
                    "ALP-3002",
                    "Post execution review",
                    sort=2,
                    comments=[old_blocker, human_answer],
                ),
            ],
        ),
    )

    selected = _select(issue_tree)

    assert selected["selected_mode"] == "post_execution_review"
    assert selected["selected_issue"]["identifier"] == "ALP-3002"
    assert selected["human_direction"] is None


def test_post_execution_review_names_one_worker_review_target():
    issue_tree = _tree(
        _accepted_gate("`ALP-3000`, `ALP-3001`, `ALP-3002`"),
        _issue(
            "ALP-2226",
            "Backlog",
            children=[
                _issue("ALP-3000", "First worker", state="Worker Done", sort=1),
                _issue("ALP-3001", "Second worker", state="Worker Done", sort=2),
                _issue("ALP-3002", "Post execution review", sort=3),
            ],
        ),
    )

    selected = _select(issue_tree)

    assert selected["selected_mode"] == "post_execution_review"
    assert selected["selected_issue"]["identifier"] == "ALP-3002"
    assert selected["review_target"] == {
        "identifier": "ALP-3000",
        "title": "First worker",
        "state": "Worker Done",
    }


def test_post_execution_review_target_advances_after_review_marker():
    issue_tree = _tree(
        _accepted_gate("`ALP-3000`, `ALP-3001`, `ALP-3002`"),
        _issue(
            "ALP-2226",
            "Backlog",
            children=[
                _issue("ALP-3000", "First worker", state="Worker Done", sort=1),
                _issue("ALP-3001", "Second worker", state="Worker Done", sort=2),
                _issue(
                    "ALP-3002",
                    "Post execution review",
                    sort=3,
                    comments=[
                        {
                            "body": "Reviewed worker issue: ALP-3000\nPost execution review passed for ALP-3000.",
                            "createdAt": "2026-01-01T00:00:01Z",
                            "updatedAt": "2026-01-01T00:00:01Z",
                        }
                    ],
                ),
            ],
        ),
    )

    selected = _select(issue_tree)

    assert selected["selected_mode"] == "post_execution_review"
    assert selected["review_target"]["identifier"] == "ALP-3001"


def test_post_execution_review_ignores_pass_comment_without_reviewed_prefix():
    issue_tree = _tree(
        _accepted_gate("`ALP-3000`, `ALP-3001`, `ALP-3002`"),
        _issue(
            "ALP-2226",
            "Backlog",
            children=[
                _issue("ALP-3000", "First worker", state="Worker Done", sort=1),
                _issue("ALP-3001", "Second worker", state="Worker Done", sort=2),
                _issue(
                    "ALP-3002",
                    "Post execution review",
                    sort=3,
                    comments=[
                        {
                            "body": "Post execution review passed for ALP-3000.",
                            "createdAt": "2026-01-01T00:00:01Z",
                            "updatedAt": "2026-01-01T00:00:01Z",
                        }
                    ],
                ),
            ],
        ),
    )

    selected = _select(issue_tree)

    assert selected["selected_mode"] == "post_execution_review"
    assert selected["review_target"]["identifier"] == "ALP-3000"


def test_closed_review_with_unreviewed_worker_requires_human_direction():
    issue_tree = _tree(
        _accepted_gate("`ALP-3000`, `ALP-3001`, `ALP-3002`"),
        _issue(
            "ALP-2226",
            "Backlog",
            children=[
                _issue("ALP-3000", "First worker", state="Worker Done", sort=1),
                _issue("ALP-3001", "Second worker", state="Worker Done", sort=2),
            ],
        ),
    )
    status_tree = _tree(
        _accepted_gate("`ALP-3000`, `ALP-3001`, `ALP-3002`"),
        _issue(
            "ALP-2226",
            "Backlog",
            children=[
                _issue("ALP-3000", "First worker", state="Worker Done", sort=1),
                _issue("ALP-3001", "Second worker", state="Worker Done", sort=2),
                _issue(
                    "ALP-3002",
                    "Post execution review",
                    state="Done",
                    sort=3,
                    comments=[
                        {
                            "body": "Reviewed worker issue: ALP-3000\nOutcome: Review passed",
                            "createdAt": "2026-01-01T00:00:01Z",
                            "updatedAt": "2026-01-01T00:00:01Z",
                        }
                    ],
                ),
            ],
        ),
    )

    selected = _select_with_status(issue_tree, status_tree)

    assert selected["selected_mode"] == "needs_human_direction"
    assert selected["selected_issue"] is None
    assert selected["review_target"] is None
    assert selected["requires_human_direction"] is True
    assert "closed before every worker issue was reviewed" in selected["eligibility_reason"]


def test_all_authorized_work_terminal_selects_final_completion():
    issue_tree = _tree(
        _accepted_gate("`ALP-3000`, `ALP-3002`, `ALP-3003`, `ALP-3001`"),
        _issue(
            "ALP-2226",
            "Backlog",
            children=[
                _issue("ALP-3000", "Implemented worker issue", state="Worker Done", sort=1),
            ],
        ),
    )
    status_tree = _tree(
        _accepted_gate("`ALP-3000`, `ALP-3002`, `ALP-3003`, `ALP-3001`"),
        _issue(
            "ALP-2226",
            "Backlog",
            children=[
                _issue("ALP-3000", "Implemented worker issue", state="Worker Done", sort=1),
                _issue(
                    "ALP-3002",
                    "Post execution review",
                    state="Done",
                    sort=2,
                    comments=[
                        {
                            "body": "Reviewed worker issue: ALP-3000\nOutcome: Review passed",
                            "createdAt": "2026-01-01T00:00:01Z",
                            "updatedAt": "2026-01-01T00:00:01Z",
                        }
                    ],
                ),
                _issue("ALP-3003", "corrective: Fix reviewed defect", state="Worker Done", sort=3),
                _issue("ALP-3001", "Post execution review final aggregate", state="Done", sort=4),
            ],
        ),
    )

    selected = _select_with_status(issue_tree, status_tree)

    assert selected["selected_mode"] == "final_completion"
    assert selected["selected_issue"] is None
    assert selected["blocked_candidates"] == []
