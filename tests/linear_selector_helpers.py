import json
import subprocess
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


def _labels(*names):
    return {
        "nodes": [
            {"name": name, "parent": {"name": "Agent Role" if name.endswith("-engineer") else "Type"}}
            for name in names
        ]
    }


def _issue(
    identifier,
    title,
    state="Todo",
    sort=0,
    description="",
    children=None,
    blockers=None,
    labels=None,
    comments=None,
):
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


def _accepted_gate(execute_line, comments=None):
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
        comments=comments,
    )
