import copy
import json
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SCHEMA_PATH = REPO_ROOT / "schemas" / "decision-record-v2.schema.json"
FIXTURE_PATH = REPO_ROOT / "tests" / "fixtures" / "decision_records" / "v2_cases.json"


def _load_json(path):
    return json.loads(path.read_text())


def _schema_enums(schema):
    prompt_modes = schema["properties"]["prompt_mode"]["oneOf"][0]["enum"]
    gate_outcomes = schema["properties"]["gate"]["properties"]["outcome"]["enum"]
    return {
        "mode": schema["properties"]["mode"]["enum"],
        "actor": schema["properties"]["actor"]["enum"],
        "prompt_mode": prompt_modes,
        "required_agent_config": schema["properties"]["required_agent_config"]["enum"],
        "sidecar_mode": schema["properties"]["sidecar_mode"]["enum"],
        "gate_outcome": gate_outcomes,
    }


def _require_keys(mapping, keys, path):
    missing = [key for key in keys if key not in mapping]
    if missing:
        raise AssertionError(f"{path} missing required keys: {missing}")


def _validate_issue(issue, required, path):
    if not isinstance(issue, dict):
        raise AssertionError(f"{path} must be an object")
    _require_keys(issue, required, path)
    if not issue["identifier"].startswith("ALP-"):
        raise AssertionError(f"{path}.identifier must be a Linear identifier")


def _validate_decision_record(record, schema):
    enums = _schema_enums(schema)
    _require_keys(record, schema["required"], "record")
    if record["version"] != 2:
        raise AssertionError("record.version must be 2")
    for key in ("mode", "actor", "required_agent_config", "sidecar_mode"):
        if record[key] not in enums[key]:
            raise AssertionError(f"record.{key} is not in schema enum")
    if record["prompt_mode"] is not None and record["prompt_mode"] not in enums["prompt_mode"]:
        raise AssertionError("record.prompt_mode is not in schema enum")
    if record["transition"]["to"] != record["mode"]:
        raise AssertionError("transition.to must match mode")
    if record["gate"]["outcome"] not in enums["gate_outcome"]:
        raise AssertionError("gate.outcome is not in schema enum")
    if record["mode"] in schema["x-selected-issue-required-modes"]:
        _validate_issue(record["selected_issue"], ["identifier", "title", "state", "parent_identifier", "agent_role"], "selected_issue")
    elif record["selected_issue"] is not None:
        raise AssertionError("terminal or pause modes cannot select an issue")
    if record["mode"] in schema["x-review-target-required-modes"]:
        _validate_issue(record["review_target"], ["identifier", "title", "state"], "review_target")
    elif record["review_target"] is not None:
        raise AssertionError("review_target is only valid for post execution review")
    for key in schema["properties"]["runtime"]["required"]:
        if not isinstance(record["runtime"][key], bool):
            raise AssertionError(f"runtime.{key} must be boolean")
    for key in schema["properties"]["terminal"]["required"]:
        if not isinstance(record["terminal"][key], bool):
            raise AssertionError(f"terminal.{key} must be boolean")
    if record["runtime"]["launch_agent"] != (record["mode"] in schema["x-agent-launch-modes"]):
        raise AssertionError("runtime.launch_agent does not match mode")
    if record["runtime"]["write_complete"] != (record["mode"] == "final_completion"):
        raise AssertionError("runtime.write_complete is only valid for final_completion")
    active_terminal = [key for key, value in record["terminal"].items() if value]
    if len(active_terminal) > 1:
        raise AssertionError("only one terminal flag can be active")
    expected_terminal = {
        "final_completion": record["mode"] == "final_completion",
        "task_complete": record["mode"] == "task_complete",
        "paused": record["mode"] == "paused",
        "stopped": record["mode"] == "stopped",
    }
    if record["terminal"] != expected_terminal:
        raise AssertionError("terminal flags must match mode")


def test_decision_record_schema_declares_contract_fields():
    schema = _load_json(SCHEMA_PATH)
    assert set(schema["required"]) == {
        "version",
        "task_id",
        "mode",
        "actor",
        "prompt_mode",
        "selected_issue",
        "review_target",
        "transition",
        "reason",
        "required_agent_config",
        "sidecar_mode",
        "gate",
        "thresholds",
        "evidence",
        "runtime",
        "terminal",
    }
    assert set(schema["properties"]["gate"]["required"]) == {
        "issue",
        "outcome",
        "authorized_parent",
        "authorized_issue_ids",
    }
    assert set(schema["properties"]["runtime"]["required"]) == {
        "launch_agent",
        "write_pause",
        "write_complete",
        "fail_closed",
    }
    assert set(schema["properties"]["terminal"]["required"]) == {
        "final_completion",
        "task_complete",
        "paused",
        "stopped",
    }


def test_valid_decision_record_fixtures_cover_every_v2_mode():
    schema = _load_json(SCHEMA_PATH)
    fixtures = _load_json(FIXTURE_PATH)["valid"]
    records = [fixture["record"] for fixture in fixtures]
    assert {record["mode"] for record in records} == set(schema["properties"]["mode"]["enum"])
    for record in records:
        _validate_decision_record(record, schema)


def test_invalid_decision_record_fixtures_are_rejected():
    schema = _load_json(SCHEMA_PATH)
    fixtures = _load_json(FIXTURE_PATH)["invalid"]
    for fixture in fixtures:
        record = copy.deepcopy(fixture["record"])
        try:
            _validate_decision_record(record, schema)
        except AssertionError:
            continue
        raise AssertionError(f"{fixture['name']} unexpectedly passed validation")


def test_invalid_selector_output_fixture_is_not_one_json_object():
    fixtures = _load_json(FIXTURE_PATH)["invalid_selector_output"]
    for raw_output in fixtures:
        try:
            json.loads(raw_output)
        except json.JSONDecodeError as exc:
            assert "Extra data" in str(exc)
            continue
        raise AssertionError("invalid selector output unexpectedly parsed")
