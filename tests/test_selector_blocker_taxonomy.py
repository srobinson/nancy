from tests.linear_selector_helpers import _accepted_gate, _issue, _select, _tree


def _direction_review(classification=None):
    body = "Outcome: Needs human direction. Smallest Stuart decision: pick release smoke timing."
    if classification == "loop":
        body = "\n".join(
            [
                "Outcome: Needs human direction.",
                "Classification: loop",
                "What was tried: Repaired the gate twice and reran the selector.",
                "Loop evidence: The same unauthorized issue reappeared after both repairs.",
                "Smallest unblock: Confirm whether to stop repair escalation.",
            ]
        )
    elif classification == "decision":
        body = "\n".join(
            [
                "Outcome: Needs human direction.",
                "Classification: decision",
                "Exact unresolved question: Should smoke run before or after publish?",
                "Positions: before publish reduces release risk; after publish matches client timing.",
                "Smallest Stuart decision: pick release smoke timing.",
                "Safe work while waiting: Update docs that do not depend on timing.",
            ]
        )
    elif classification:
        body += f"\nClassification: {classification}"
    return _issue(
        "ALP-3002",
        "Post execution review",
        sort=2,
        comments=[
            {
                "body": body,
                "createdAt": "2026-01-01T00:00:01Z",
                "updatedAt": "2026-01-01T00:00:01Z",
            }
        ],
    )


def _review_decision_tree(review):
    return _tree(
        _accepted_gate("`ALP-3000`, `ALP-3002`"),
        _issue(
            "ALP-2226",
            "Backlog",
            children=[
                _issue("ALP-3000", "Implemented worker issue", state="Worker Done", sort=1),
                review,
            ],
        ),
    )


def test_layer_b_loop_classification_sets_agent_stuck_only():
    selected = _select(_review_decision_tree(_direction_review("loop")))

    assert selected["selected_mode"] == "agent_stuck"
    assert selected["selected_issue"] is None
    assert selected["workflow_repair_route"] is False
    assert selected["agent_stuck"] is True
    assert selected["product_decision_needed"] is False
    assert selected["human_direction"]["identifier"] == "ALP-3002"
    assert selected["human_direction"]["classification"] == "loop"
    assert "Loop evidence:" in selected["human_direction"]["classifier_body"]
    assert selected["repair_routing"] is None


def test_layer_c_decision_classification_sets_product_decision_only():
    selected = _select(_review_decision_tree(_direction_review("decision")))

    assert selected["selected_mode"] == "product_decision"
    assert selected["selected_issue"] is None
    assert selected["workflow_repair_route"] is False
    assert selected["agent_stuck"] is False
    assert selected["product_decision_needed"] is True
    assert selected["human_direction"]["identifier"] == "ALP-3002"
    assert selected["human_direction"]["classification"] == "decision"
    assert "Exact unresolved question:" in selected["human_direction"]["classifier_body"]
    assert selected["repair_routing"] is None


def test_unclassified_human_direction_is_not_synthesized_from_review_text():
    selected = _select(_review_decision_tree(_direction_review()))

    assert selected["selected_mode"] == "post_execution_review"
    assert selected["selected_issue"]["identifier"] == "ALP-3002"
    assert selected["agent_stuck"] is False
    assert selected["product_decision_needed"] is False
    assert selected["human_direction"] is None


def test_alp_2408_unauthorized_corrective_routes_to_post_execution_review_repair():
    gate = _issue(
        "ALP-2411",
        "Gate review: harness driver boundary execution readiness",
        state="Worker Done",
        sort=1,
        description=(
            "Planning complete. Outcome: Ready for execution.\n"
            "Authorized execution parent: `ALP-2412` Backlog.\n"
            "Execute: `ALP-2413`, `ALP-2414`, `ALP-2415`, `ALP-2416`, `ALP-2417`, `ALP-2418`.\n"
        ),
    )
    issue_tree = _tree(
        gate,
        _issue(
            "ALP-2412",
            "Backlog",
            children=[
                _issue(
                    "ALP-2413",
                    "Characterize provider selection before harness movement",
                    state="Worker Done",
                    sort=1,
                ),
                _issue(
                    "ALP-2414",
                    "Characterize shared launch supervision before driver extraction",
                    state="Worker Done",
                    sort=2,
                ),
                _issue(
                    "ALP-2415",
                    "Introduce static harness driver contract and registry",
                    state="Worker Done",
                    sort=3,
                ),
                _issue("ALP-2416", "Move Claude launch onto ManagedClient supervision", sort=4),
                _issue("ALP-2417", "Expose harness capabilities to desktop and web", sort=5),
                _issue("ALP-2418", "Post execution review: harness driver boundary", sort=6),
                _issue(
                    "ALP-2419",
                    "Correct ALP-2415: commit harness registry and record verification",
                    state="Backlog",
                    sort=7,
                ),
            ],
        ),
    )

    selected = _select(issue_tree)

    assert selected["selected_mode"] == "workflow_repair"
    assert selected["selected_issue"]["identifier"] == "ALP-2418"
    assert selected["workflow_repair_route"] is True
    assert selected["agent_stuck"] is False
    assert selected["product_decision_needed"] is False
    assert selected["unauthorized_backlog_candidates"][0]["identifier"] == "ALP-2419"
    assert selected["repair_routing"] == {
        "target_issue": "ALP-2418",
        "target_mode": "post_execution_review",
        "repair_instruction": "Authorize ALP-2419 in the accepted gate Execute list before continuing post execution review.",
    }
