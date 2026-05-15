import os
import subprocess
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
PROMPT_MODE_DIR = REPO_ROOT / "templates" / "modes"
FORBIDDEN_EXECUTION_TEXT = [
    "Implement all issues",
    "Mark the checkbox",
    "echo \"done\"",
    "just check && just build && just test",
]
NON_EXECUTION_MODES = [
    "planning",
    "agent_issue_review",
    "post_execution_review",
    "agent_stuck",
    "product_decision",
]
REQUIRED_MODES = [
    "planning",
    "agent_issue_review",
    "execution",
    "corrective_resolution",
    "post_execution_review",
    "agent_stuck",
    "product_decision",
]
REPAIR_RESOLUTION_SHAPE = (
    '{"repair_attempts_resolved":{"target_issue":"ISSUE-ID",'
    '"repair_instruction":"TEXT","iteration_timestamp":"YYYY-MM-DDTHH:MM:SSZ",'
    '"resolution":"TEXT"}}'
)


def _mode_instructions(mode):
    script = (
        "source src/prompt/index.sh; "
        "prompt::mode_instructions \"$1\""
    )
    result = subprocess.run(
        ["bash", "-c", script, "prompt-mode", mode],
        cwd=REPO_ROOT,
        env={"NANCY_FRAMEWORK_ROOT": str(REPO_ROOT)},
        text=True,
        capture_output=True,
        check=False,
    )
    assert result.returncode == 0, result.stderr
    return result.stdout


def _worker_prompt(
    mode,
    selector_context,
    project_title="Project Title",
    project_description="Description",
    agent="codex",
):
    script = r'''
        export NANCY_FRAMEWORK_ROOT="$PWD"
        export NANCY_PROJECT_ROOT="$(mktemp -d)"
        export NANCY_CURRENT_TASK_DIR="$NANCY_PROJECT_ROOT/.nancy/tasks/ALP-1"
        source src/prompt/index.sh
        source src/cmd/start.sh
        mkdir -p "$NANCY_CURRENT_TASK_DIR"

        _NEXT_PROMPT_MODE="$TEST_PROMPT_MODE"
        _NEXT_SELECTOR_PROMPT_CONTEXT="$TEST_SELECTOR_CONTEXT"

        _start_render_worker_prompt \
            ALP-1 session-1 ALP-1 \
            "$TEST_PROJECT_TITLE" "$TEST_PROJECT_DESCRIPTION" \
            /tmp/worktree "" "$TEST_AGENT"
    '''

    result = subprocess.run(
        ["bash", "-c", script],
        cwd=REPO_ROOT,
        env={
            **os.environ,
            "TEST_PROMPT_MODE": mode,
            "TEST_SELECTOR_CONTEXT": selector_context,
            "TEST_PROJECT_TITLE": project_title,
            "TEST_PROJECT_DESCRIPTION": project_description,
            "TEST_AGENT": agent,
        },
        text=True,
        capture_output=True,
        check=False,
    )

    assert result.returncode == 0, result.stderr + result.stdout
    return result.stdout


def test_required_prompt_mode_templates_exist():
    for mode in REQUIRED_MODES:
        assert (PROMPT_MODE_DIR / f"{mode}.md.template").exists()


def test_non_execution_prompt_modes_exclude_execution_only_instructions():
    for mode in NON_EXECUTION_MODES:
        instructions = _mode_instructions(mode)

        for forbidden in FORBIDDEN_EXECUTION_TEXT:
            assert forbidden not in instructions


def test_agent_stuck_template_records_loop_classifier_fields():
    instructions = _mode_instructions("agent_stuck")

    for expected in [
        "recording a Layer B human pause",
        "post-execution-review-workflow.md#outcome-classification",
        "Classification: loop",
        "What was tried:",
        "What kept repeating:",
        "Last two relevant issue IDs:",
        "Smallest unblock the agent can imagine:",
        "Do not write new code, create speculative issues, or mark anything Done.",
    ]:
        assert expected in instructions

    assert len((PROMPT_MODE_DIR / "agent_stuck.md.template").read_text().splitlines()) < 35


def test_product_decision_template_records_decision_classifier_fields():
    instructions = _mode_instructions("product_decision")

    for expected in [
        "recording a Layer C human pause",
        "post-execution-review-workflow.md#outcome-classification",
        "Classification: decision",
        "Question:",
        "Agent position:",
        "Alternative positions:",
        "Smallest decision needed:",
        "Safe work while waiting:",
        "Do not write new code, create speculative issues, or mark anything Done.",
    ]:
        assert expected in instructions

    assert (
        len((PROMPT_MODE_DIR / "product_decision.md.template").read_text().splitlines())
        < 35
    )


def test_human_pause_prompt_modes_use_split_templates():
    selector_context_tail = """- Issue: `ALP-2` Post execution review
- Eligibility: fixture selector output
"""

    agent_prompt = _worker_prompt(
        "agent_stuck",
        "## Selected Work\n\n- Mode: `agent_stuck`\n" + selector_context_tail,
    )
    decision_prompt = _worker_prompt(
        "product_decision",
        "## Selected Work\n\n- Mode: `product_decision`\n" + selector_context_tail,
    )

    assert "## Mode: Agent Stuck" in agent_prompt
    assert "Classification: loop" in agent_prompt
    assert "## Mode: Product Decision" in decision_prompt
    assert "Classification: decision" in decision_prompt
    assert "Mode: Needs Human Direction" not in agent_prompt + decision_prompt


def test_corrective_resolution_requires_post_execution_finding_context():
    instructions = _mode_instructions("corrective_resolution")

    assert "concrete post execution finding" in instructions
    assert "completed worker issue" in instructions


def test_post_execution_review_requires_one_target_and_no_aggregate_review():
    instructions = _mode_instructions("post_execution_review")

    assert "review only that target" in instructions
    assert "do not review source or the execution set" in instructions
    assert "Do not review more than one worker issue" in instructions
    assert "Do not perform aggregate execution set review" in instructions


def test_post_execution_review_repair_instruction_renders_gate_authority_branch():
    selector_context = """## Selected Work

- Mode: `workflow_repair`
- Issue: `ALP-2418` Post execution review
- Eligibility: Workflow repair route
- Repair instruction: Extend accepted gate `ALP-2411` Execute line to include `ALP-2419`.
"""

    prompt = _worker_prompt("post_execution_review", selector_context)

    assert "- Repair instruction: Extend accepted gate `ALP-2411`" in prompt
    assert "repair only gate authority" in prompt
    assert "extend its `Execute:` line" in prompt
    assert REPAIR_RESOLUTION_SHAPE in prompt
    assert "one-line Linear comment on the gate" in prompt
    assert "post-execution-review-workflow.md#outcome-classification" in prompt
    assert (
        "Do not perform a worker review or reconciliation when a Repair instruction is present"
        in prompt
    )
    assert "{{MODE_INSTRUCTIONS_SECTION}}" not in prompt


def test_post_execution_review_template_stays_under_loc_limit():
    lines = (
        (PROMPT_MODE_DIR / "post_execution_review.md.template")
        .read_text()
        .splitlines()
    )

    assert len(lines) < 50


def test_execution_prompt_completes_issue_not_task():
    instructions = _mode_instructions("execution")

    assert 'state: "Worker Done"' in instructions
    assert "CODE_COMPLETE" not in instructions
    assert "Do not write `COMPLETE`" not in instructions


def test_corrective_resolution_does_not_repeat_complete_sentinel_warning():
    instructions = _mode_instructions("corrective_resolution")

    assert "Do not write `COMPLETE`" not in instructions


def test_worker_prompt_preserves_ampersands_in_mode_instructions():
    selector_context = """## Selected Work

- Mode: `execution`
- Issue: `ALP-2` Test issue
- Eligibility: test
"""

    prompt = _worker_prompt(
        "execution",
        selector_context,
        project_title="Project & Title",
        project_description="Description & context",
    )

    assert "just check && just build && just test" in prompt
    assert "{{MODE_INSTRUCTIONS_SECTION}}" not in prompt
