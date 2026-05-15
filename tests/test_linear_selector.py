from tests.linear_selector_helpers import _accepted_gate, _issue, _markers, _select, _select_with_status, _tree


def test_backlog_children_are_not_repair_candidates_before_gate_acceptance():
    backlog_child = _issue("ALP-2225", "Implement gate mode prompt templates", sort=1)
    issue_tree = _tree(
        _issue("ALP-2217", "Plan Linear issue selection", sort=1),
        _issue("ALP-2220", "Gate review and execution readiness", sort=2),
        _issue("ALP-2226", "Backlog", sort=3, children=[backlog_child]),
    )

    selected = _select(issue_tree)

    assert selected["selected_mode"] == "planning"
    assert selected["selected_issue"]["identifier"] == "ALP-2217"
    assert selected["workflow_repair_route"] is False
    assert selected["unauthorized_backlog_candidates"] == []


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


def test_backlog_state_corrective_outranks_human_direction_review():
    review = _issue(
        "ALP-3002",
        "Post execution review",
        state="Worker Done",
        sort=1,
        comments=[
            {
                "body": "Reviewed worker issue: ALP-3000\nOutcome: Needs human direction",
                "createdAt": "2026-01-01T00:00:01Z",
                "updatedAt": "2026-01-01T00:00:01Z",
            }
        ],
    )
    corrective = _issue("ALP-3001", "Corrective: Fix reviewed defect", state="Backlog", sort=2)
    issue_tree = _tree(
        _accepted_gate("`ALP-3000`, `ALP-3002`, `ALP-3001`"),
        _issue(
            "ALP-2226",
            "Backlog",
            children=[
                _issue("ALP-3000", "Implemented worker issue", state="Worker Done", sort=1),
                review,
                corrective,
            ],
        ),
    )

    selected = _select(issue_tree)

    assert selected["selected_mode"] == "corrective_resolution"
    assert selected["selected_issue"]["identifier"] == "ALP-3001"


def test_open_backlog_child_outside_accepted_gate_routes_workflow_repair():
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

    assert selected["selected_mode"] == "workflow_repair"
    assert selected["selected_issue"]["identifier"] == "ALP-2220"
    assert selected["workflow_repair_route"] is True
    assert "requires_human_direction" not in selected
    assert "outside accepted gate" in selected["eligibility_reason"]
    assert selected["unauthorized_backlog_candidates"][0]["identifier"] == "ALP-3001"
    assert selected["repair_routing"]["repair_instruction"] == (
        "Authorize ALP-3001 in the accepted gate Execute list before continuing post execution review."
    )


def test_backlog_state_child_outside_accepted_gate_routes_workflow_repair():
    issue_tree = _tree(
        _accepted_gate("`ALP-3000`"),
        _issue(
            "ALP-2226",
            "Backlog",
            children=[
                _issue("ALP-3000", "Implemented worker issue", state="Worker Done", sort=1),
                _issue("ALP-3001", "Corrective: Fix reviewed defect", state="Backlog", sort=2),
            ],
        ),
    )

    selected = _select(issue_tree)

    assert selected["selected_mode"] == "workflow_repair"
    assert selected["workflow_repair_route"] is True
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


def test_grandchildren_route_workflow_repair():
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

    assert selected["selected_mode"] == "workflow_repair"
    assert selected["selected_issue"]["identifier"] == "ALP-3001"
    assert selected["workflow_repair_route"] is True
    assert selected["repair_routing"]["target_mode"] == "planning"


def test_post_execution_review_product_decision_blocks_final_completion():
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
                    state="Todo",
                    sort=2,
                    comments=[
                        {
                            "body": (
                                "Outcome: Needs human direction. Smallest Stuart decision: pick release smoke timing.\n"
                                "Classification: decision"
                            ),
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
    assert selected["agent_stuck"] is False
    assert selected["product_decision_needed"] is True
    assert selected["human_direction"]["identifier"] == "ALP-3002"
    assert "Needs human direction" in selected["human_direction"]["blocker"]


def test_human_direction_comment_releases_review_back_to_post_execution_review():
    old_blocker = {
        "body": (
            "Outcome: Needs human direction. Smallest Stuart decision: pick release smoke timing.\n"
            "Classification: decision"
        ),
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


def test_post_execution_review_ignores_review_issue_worker_blockers():
    review = _issue(
        "ALP-3003",
        "Post execution review",
        state="Todo",
        sort=4,
        blockers=[
            {"identifier": "ALP-3000", "state": "Worker Done"},
            {"identifier": "ALP-3001", "state": "Todo"},
            {"identifier": "ALP-3002", "state": "Todo"},
        ],
    )
    issue_tree = _tree(
        _accepted_gate("`ALP-3000`, `ALP-3001`, `ALP-3002`, `ALP-3003`"),
        _issue(
            "ALP-2226",
            "Backlog",
            children=[
                _issue("ALP-3000", "First worker", state="Worker Done", sort=1),
                _issue("ALP-3001", "Second worker", state="Todo", sort=2),
                _issue("ALP-3002", "Third worker", state="Todo", sort=3),
                review,
            ],
        ),
    )

    selected = _select(issue_tree)

    assert selected["selected_mode"] == "post_execution_review"
    assert selected["selected_issue"]["identifier"] == "ALP-3003"
    assert selected["review_target"]["identifier"] == "ALP-3000"
    assert selected["blocked_candidates"] == []


def test_post_execution_review_interleaves_with_open_execution_pool():
    issue_tree = _tree(
        _accepted_gate("`ALP-3000`, `ALP-3001`, `ALP-3002`, `ALP-3003`"),
        _issue(
            "ALP-2226",
            "Backlog",
            children=[
                _issue("ALP-3000", "First worker", state="Worker Done", sort=1),
                _issue("ALP-3001", "Second worker", state="Todo", sort=2),
                _issue("ALP-3002", "Third worker", state="Todo", sort=3),
                _issue("ALP-3003", "Post execution review", sort=4),
            ],
        ),
    )

    selected = _select(issue_tree)

    assert selected["selected_mode"] == "post_execution_review"
    assert selected["selected_issue"]["identifier"] == "ALP-3003"
    assert selected["review_target"] == {
        "identifier": "ALP-3000",
        "title": "First worker",
        "state": "Worker Done",
    }


def test_execution_resumes_after_interleaved_review_marker_recorded():
    review = _issue(
        "ALP-3003",
        "Post execution review",
        state="Todo",
        sort=4,
        comments=[
            {
                "body": "Reviewed worker issue: ALP-3000\nOutcome: Review passed",
                "createdAt": "2026-01-01T00:00:01Z",
                "updatedAt": "2026-01-01T00:00:01Z",
            }
        ],
    )
    issue_tree = _tree(
        _accepted_gate("`ALP-3000`, `ALP-3001`, `ALP-3002`, `ALP-3003`"),
        _issue(
            "ALP-2226",
            "Backlog",
            children=[
                _issue("ALP-3000", "First worker", state="Worker Done", sort=1),
                _issue("ALP-3001", "Second worker", state="Todo", sort=2),
                _issue("ALP-3002", "Third worker", state="Todo", sort=3),
                review,
            ],
        ),
    )

    selected = _select(issue_tree)

    assert selected["selected_mode"] == "execution"
    assert selected["selected_issue"]["identifier"] == "ALP-3001"
    assert selected["review_target"] is None


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


def test_post_execution_review_candidate_in_worker_done_resumes_one_target_review():
    review = _issue(
        "ALP-3002",
        "Review implementation and release readiness",
        state="Worker Done",
        sort=3,
        description="## Type\n\nPost execution review candidate from `ALP-2999`.",
        comments=[
            {
                "body": "Post execution review outcome.\n\nCorrective work:\n\n* Created `ALP-3003`.",
                "createdAt": "2026-01-01T00:00:01Z",
                "updatedAt": "2026-01-01T00:00:01Z",
            }
        ],
    )
    issue_tree = _tree(
        _accepted_gate("`ALP-3000`, `ALP-3001`, `ALP-3002`, `ALP-3003`"),
        _issue(
            "ALP-2226",
            "Backlog",
            children=[
                _issue("ALP-3000", "First worker", state="Worker Done", sort=1),
                _issue("ALP-3001", "Second worker", state="Worker Done", sort=2),
                review,
                _issue("ALP-3003", "Corrective: Fix reviewed defect", state="Worker Done", sort=4),
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


def test_corrective_reference_to_post_execution_review_is_not_review_issue():
    issue_tree = _tree(
        _accepted_gate("`ALP-3000`, `ALP-3001`, `ALP-3002`"),
        _issue(
            "ALP-2226",
            "Backlog",
            children=[
                _issue("ALP-3000", "First worker", state="Worker Done", sort=1),
                _issue(
                    "ALP-3001",
                    "Corrective: Fix reviewed defect",
                    state="Worker Done",
                    sort=2,
                    description="## Type\n\nCorrective implementation issue from the post execution review.",
                ),
                _issue(
                    "ALP-3002",
                    "Review implementation and release readiness",
                    state="Worker Done",
                    sort=3,
                    description="## Type\n\nPost execution review candidate from `ALP-2999`.",
                ),
            ],
        ),
    )

    selected = _select(issue_tree)

    assert selected["selected_mode"] == "post_execution_review"
    assert selected["selected_issue"]["identifier"] == "ALP-3002"
    assert selected["corrective_priority_evidence"]["open_review"] == [
        {
            "identifier": "ALP-3002",
            "title": "Review implementation and release readiness",
            "state": "Worker Done",
        }
    ]


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


def test_closed_review_with_unreviewed_worker_routes_workflow_repair():
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

    assert selected["selected_mode"] == "workflow_repair"
    assert selected["selected_issue"]["identifier"] == "ALP-3002"
    assert selected["review_target"] is None
    assert selected["workflow_repair_route"] is True
    assert selected["repair_routing"] == {
        "target_issue": "ALP-3002",
        "target_mode": "post_execution_review",
        "repair_instruction": "Resume post execution review for ALP-3001 before final completion.",
    }
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
