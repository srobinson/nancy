import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from test_decision_record_schema import SCHEMA_PATH, _load_json, _validate_decision_record
from test_linear_selector import _accepted_gate, _issue, _select, _tree


REPO_ROOT = SCHEMA_PATH.parents[1]


def _decision_record(task_id, raw_selection):
    script = (
        "source src/linear/selector.sh; "
        "linear::selector:decision_record \"$1\" \"$2\""
    )
    return subprocess.run(
        ["bash", "-c", script, "decision-record", task_id, raw_selection],
        cwd=REPO_ROOT,
        text=True,
        capture_output=True,
        check=False,
    )


def test_selector_decision_record_emits_one_compact_v2_object():
    issue_tree = _tree(
        _accepted_gate("`ALP-2366`"),
        _issue("ALP-2226", "Backlog", children=[_issue("ALP-2366", "Add schema fixtures")]),
    )
    legacy_selection = _select(issue_tree)

    result = _decision_record("ALP-2359", json.dumps(legacy_selection))

    assert result.returncode == 0, result.stderr
    assert result.stderr == ""
    assert len(result.stdout.splitlines()) == 1
    record = json.loads(result.stdout)
    assert result.stdout == json.dumps(record, separators=(",", ":")) + "\n"
    assert legacy_selection["selected_mode"] == "execution"
    assert record["mode"] == "execution"
    assert record["selected_issue"]["identifier"] == "ALP-2366"
    _validate_decision_record(record, _load_json(SCHEMA_PATH))


def test_invalid_selector_decision_record_fails_closed_without_jq_noise():
    cases = [
        ('{"version":2,"mode":"execution"}\ntrailing garbage', "Selector JSON invalid", "invalid_selector_json"),
        ('{"selected_mode":"review_churn","selected_issue":null}', "Selector state invalid", "invalid_selector_state"),
    ]
    for raw_selection, reason, invalid_state in cases:
        result = _decision_record("ALP-2359", raw_selection)

        assert result.returncode == 0
        assert result.stderr == ""
        assert len(result.stdout.splitlines()) == 1
        record = json.loads(result.stdout)
        assert record["mode"] == "needs_human_direction"
        assert record["reason"] == reason
        assert record["runtime"]["fail_closed"] is True
        assert record["evidence"]["invalid_states"] == [invalid_state]
        _validate_decision_record(record, _load_json(SCHEMA_PATH))
