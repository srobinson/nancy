# Nancy State Machine v2

Status: proposal.

This document defines the target centralized state machine for Nancy's gate
aware Linear loop. It complements `TMP/STATE_MACHINE.md`, which records current
behavior. The goal here is a durable contract that other projects and
`linear-workflows` can integrate against.

## Why This Exists

Nancy now works, but the workflow contract is split across:

- `src/linear/selector.sh`: graph classification, mode selection, gate parsing,
  review target derivation, blocker checks, evidence.
- `src/cmd/start.sh`: runtime loop, prompt mode routing, reviewer handoff,
  null selection handling, pause and completion behavior.
- `src/sidecar/sidecar.sh`: worker process observation, handover requests,
  `<END_TURN>` detection, sidecar rotation state.
- `templates/modes/*.md.template`: agent behavior constraints.
- Linear issue descriptions and comments: accepted gate text, review outcome
  markers, human direction markers.
- Task files: `ISSUES.md`, `HANDOVER.md`, `PAUSE`, `STOP`, `COMPLETE`,
  `.worker_completed`, `.worker_pid`, `.sidecar_session`.

The failure mode is repeated recomputation. Each component owns a slice of the
truth, so small inconsistencies can create loops, false completion, or workers
that do not rotate after ending their turn.

v2 creates one boundary:

```text
ObservedState
  -> ClassifiedGraph
  -> DecisionRecord
  -> prompt rendering, agent launch, sidecar policy, evidence files
```

## Non Negotiables

- Linear remains the durable source of truth for issue state and planning truth.
- Nancy mode is separate from Linear issue state.
- `ISSUES.md` is evidence and prompt context. It is not authority.
- Agents work one selected issue or review target per turn.
- `needs_human_direction` must not close the master parent or write `COMPLETE`.
- `final_completion` must be explicit. It must not be inferred from stale local
  files.
- Sidecar rotation state is process control, not workflow completion.

## Mode Vocabulary

Keep the existing names:

```text
planning
agent_issue_review
execution
corrective_resolution
post_execution_review
needs_human_direction
final_completion
```

`final_completion` is a selector result, not an agent prompt.

`agent_issue_review` is currently a runtime follow up after `planning`. In v2 it
becomes a first class transition so routing does not live only in `start.sh`.

## Observed State

The state machine consumes read only observations.

```text
ObservedState
  task_id
  parent_issue
  open_graph
  status_graph
  task_runtime
  last_turn_event
  config
```

`open_graph` is the current open Linear issue tree.

`status_graph` includes terminal issues needed for audit, especially `Done`
review issues and comments.

`task_runtime` includes:

- `STOP` exists.
- `PAUSE` exists.
- `COMPLETE` exists.
- `.worker_completed` exists.
- `.worker_pid` exists and process liveness.
- `.sidecar_session` exists and tmux session liveness.
- single run mode.
- worker and reviewer CLI config.

`last_turn_event` records what just happened:

```text
worker_exit_success
worker_exit_failure
sidecar_completion_rotation
operator_stop
operator_pause
planning_worker_finished
reviewer_finished
```

## Classified Graph

Classification is the only place that parses Linear titles, labels,
descriptions, states, relations, and comments.

```text
ClassifiedGraph
  direct_issues
  child_issues
  unsupported_hierarchy
  open_planning
  open_gate_review
  accepted_gate
  authorized_parent
  authorized_issue_ids
  authorized_issues
  missing_authorized_status
  open_execution
  open_corrective
  open_post_execution_review
  reviewed_worker_ids
  review_target
  unresolved_human_direction
  review_closed_with_unreviewed_target
  final_ready
  blocked_candidates
  unauthorized_backlog_candidates
```

Every downstream caller consumes these facts instead of repeating regexes or
state checks.

## Role Policy

| Role | Detection |
| --- | --- |
| `backlog_parent` | title equals `Backlog` |
| `gate_review` | title matches `Gate review` or `execution readiness` |
| `corrective` | label `Corrective` or title contains `corrective` |
| `post_execution_review` | label `Post Execution Review` or title matches `^post[ -]execution review` |
| `planning` | direct open issue that is not backlog and not gate review |
| `execution` | authorized issue that is not corrective and not post execution review |

## Gate Policy

A gate is accepted only when:

- No open planning issue remains.
- No open gate review issue remains.
- A gate review issue is in `Worker Done` or `Done`.
- Its description contains one accepted outcome:
  - `Outcome: Ready for execution`
  - `Outcome: Pre execution blockers required`
- Its description names one authorized parent in backticks.
- Its description lists authorized issue IDs.

Legacy accepted text:

```text
Planning complete. Outcome: Ready for execution.
Authorized execution parent: `ISSUE-ID`.
Execute: ISSUE-ID, ISSUE-ID.
```

or:

```text
Planning complete. Outcome: Pre execution blockers required.
Authorized blocker parent: `ISSUE-ID`.
Execute blockers only: ISSUE-ID, ISSUE-ID.
```

v2 should also write a structured block while continuing to read legacy text:

```text
Nancy-Gate:
  outcome: ready_for_execution
  authorized_parent: ISSUE-ID
  execute:
    - ISSUE-ID
    - ISSUE-ID
```

## Review Outcome Policy

Post execution review is one target per turn.

The selected review issue is the open authorized post execution review issue.
The selected `review_target` is the first authorized worker issue, ordered by
`subIssueSortOrder`, that is accepted and not yet reviewed.

Accepted worker states:

```text
Worker Done
Done
```

A worker is reviewed only when the selected review issue has a comment line that
starts with:

```text
Reviewed worker issue: ISSUE-ID
```

Informal comments do not count.

If a review finds a defect, the agent creates a corrective issue, comments the
review outcome, and ends the turn. The next graph evaluation selects
`corrective_resolution` before any further post execution review.

If review needs Stuart, the agent records `Needs human direction` and ends the
turn. The loop pauses instead of completing.

Human direction is released only by a later direction event containing:

```text
Human direction:
```

## Blocker Policy

The current selector releases blockers in these states:

```text
Worker Done
Done
Canceled
Duplicate
```

v2 should keep blocker release policy as named data in the decision record.

Final acceptance is role specific:

| Role | Terminal for final completion |
| --- | --- |
| worker issue | `Worker Done` or `Done` |
| corrective issue | `Worker Done` or `Done` |
| post execution review issue | `Done` |
| gate review issue | `Worker Done` or `Done` |

Final completion also requires no remaining `review_target`.

## Runtime Sentinel Policy

Local files are process control, not planning truth.

| File | Meaning |
| --- | --- |
| `STOP` | operator requested loop exit after current pipeline returns |
| `PAUSE` | loop waits before launching next iteration |
| `COMPLETE` | local Nancy task completion after selector `final_completion` |
| `.worker_completed` | sidecar saw completion output and rotated the process |
| `.worker_pid` | current worker process |
| `.sidecar_session` | current tmux sidecar session |

`COMPLETE` must be written only by final completion handling.

`.worker_completed` must never be treated as task completion. It only normalizes
nonzero exits caused by sidecar rotation.

At the start of a fresh `nancy go`, stale `STOP` and `COMPLETE` are cleared
before Linear is evaluated.

## Turn Exit Policy

The appended runtime Turn Exit instruction is part of Nancy's control protocol.
It survives skill specific confirmation steps.

If a skill says to report a path or status, the agent does that first, then
prints the required turn exit marker:

```text
<END_TURN>
```

or, for Claude prompts that require backticks:

```text
`<END_TURN>`
```

The sidecar must detect common UI prefixes and summaries, including:

```text
<END_TURN>
`<END_TURN>`
<glyph> <END_TURN>
Log saved:
Session summary:
Worked for
Cooked for
```

## Decision Record

The state machine emits one JSON object per evaluation.

```json
{
  "version": 2,
  "task_id": "ALP-2155",
  "mode": "post_execution_review",
  "actor": "reviewer",
  "prompt_mode": "post_execution_review",
  "selected_issue": {
    "identifier": "ALP-2330",
    "title": "Post execution review",
    "state": "Todo",
    "parent_identifier": "ALP-2324",
    "agent_role": ""
  },
  "review_target": {
    "identifier": "ALP-2326",
    "title": "Worker issue title",
    "state": "Worker Done"
  },
  "transition": {
    "from": "execution",
    "event": "execution_queue_empty",
    "to": "post_execution_review"
  },
  "reason": "Post execution review is eligible after execution and corrective queues are clear",
  "required_agent_config": "reviewer",
  "sidecar_mode": "review",
  "blocker_release_states": ["Worker Done", "Done", "Canceled", "Duplicate"],
  "final_acceptance_states": ["Done"],
  "gate": {
    "issue": "ALP-2220",
    "outcome": "ready_for_execution",
    "authorized_parent": "ALP-2226",
    "authorized_issue_ids": ["ALP-2325", "ALP-2326", "ALP-2330"]
  },
  "evidence": {
    "blocked_candidates": [],
    "unauthorized_backlog_candidates": [],
    "open_corrective": [],
    "open_review": ["ALP-2330"],
    "reviewed_worker_ids": ["ALP-2325"],
    "human_direction": null
  },
  "runtime": {
    "launch_agent": true,
    "write_pause": false,
    "write_complete": false,
    "clear_stale_stop_and_complete": false
  }
}
```

Prompt rendering, `ISSUES.md`, sidecar launch, reviewer routing, logs, and
operator output consume this record. They do not recompute ownership.

## Graph Priority

The graph reducer chooses in this order:

| Priority | Guard | Mode | Actor |
| --- | --- | --- | --- |
| 1 | unsupported hierarchy exists | `needs_human_direction` | human |
| 2 | open planning issue exists | `planning` | worker |
| 3 | open gate review issue exists | `planning` | worker |
| 4 | open authorized corrective issue exists | `corrective_resolution` | worker |
| 5 | execution clear and unresolved human direction exists | `needs_human_direction` | human |
| 6 | review issue closed before all workers reviewed | `needs_human_direction` | human |
| 7 | execution and corrective queues clear, open review issue exists | `post_execution_review` | reviewer |
| 8 | all authorized issues terminal and no review target remains | `final_completion` | runtime |
| 9 | accepted gate has authorized IDs | `execution` | worker |
| 10 | fallback | `planning` | worker |

`post_execution_review` actor is the desired v2 owner. The current Bash runtime
may still launch it through worker config during migration. The decision record
should make that mismatch visible until routing is centralized.

## Turn Event Priority

After a launched agent exits, runtime events are handled before graph
evaluation:

| Current mode | Event | Decision |
| --- | --- | --- |
| any | `STOP` exists | stop loop |
| any | `PAUSE` exists | wait |
| any | sidecar completion rotation | normalize exit, clear `.worker_completed`, evaluate graph |
| `planning` | success and reviewer configured | `agent_issue_review` |
| `planning` | success and reviewer missing | configuration error |
| `planning` | failure | stop with failure evidence |
| `agent_issue_review` | success | evaluate graph |
| `execution` | success | evaluate graph |
| `corrective_resolution` | success | evaluate graph |
| `post_execution_review` | success | evaluate graph |

## Bash Migration

Add a state module without changing behavior first:

```text
src/state/index.sh
src/state/machine.sh
src/state/policies.sh
src/state/render.sh
```

Suggested functions:

```bash
state::machine::decide "$issue_tree" "$status_tree" "$runtime_json" "$event_json"
state::machine::classify_graph "$issue_tree" "$status_tree"
state::machine::select_graph_mode "$classified_json"
state::machine::apply_runtime_event "$graph_decision" "$runtime_json" "$event_json"
state::machine::render_prompt_context "$decision_json"
state::machine::render_issues_summary "$decision_json"
```

Keep compatibility:

```bash
linear::selector:evaluate() {
  state::machine::decide "$@"
}
```

Then move `cmd::start` from globals:

```text
_NEXT_PROMPT_MODE
_NEXT_AGENT_ROLE
_NEXT_SELECTOR_PROMPT_CONTEXT
```

to one `decision` variable per iteration.

## Rust Shape

The Rust successor should model the same contract with plain enums and structs:

```rust
enum WorkflowMode {
    Planning,
    AgentIssueReview,
    Execution,
    CorrectiveResolution,
    PostExecutionReview,
    NeedsHumanDirection,
    FinalCompletion,
}

enum Actor {
    Worker,
    Reviewer,
    Human,
    Runtime,
}

struct StateDecision {
    version: u8,
    task_id: String,
    mode: WorkflowMode,
    actor: Actor,
    selected_issue: Option<SelectedIssue>,
    review_target: Option<SelectedIssue>,
    transition: Transition,
    gate: Option<GateDecision>,
    evidence: Evidence,
    runtime: RuntimeActions,
}
```

Do not start with typestate for every mode. Use transition validation for
dangerous lifecycle actions: parent closure, review issue closure, pause,
completion, and corrective issue creation.

## Migration Plan

### Phase 1: Freeze The Contract

- Track this file at repo root.
- Add a `state decision` JSON schema.
- Add golden selector fixtures for known Linear shapes.
- Keep current selector tests passing.

### Phase 2: Extract Policies

- Move role detection into named helpers.
- Move gate parsing into named helpers.
- Move review marker parsing into named helpers.
- Move blocker and final acceptance rules into named helpers.
- Keep the selector output byte compatible.

### Phase 3: Centralize Runtime

- Move `agent_issue_review` handoff into state machine events.
- Route actor, prompt mode, sidecar mode, and required agent config from the
  decision record.
- Make `needs_human_direction` produce pause actions from the decision record.
- Make `final_completion` produce parent closure and `COMPLETE` actions from the
  decision record.

### Phase 4: Structure Gate Evidence

- Write `Nancy-Gate` blocks from planning gate workflow.
- Parse both structured and legacy gate text.
- Prefer structured blocks when both exist.

### Phase 5: Port To Rust

- Reuse Bash golden fixtures as Rust tests.
- Keep Linear as the issue source of truth.
- Preserve `ISSUES.md` and `HANDOVER.md` as audit and coordination artifacts.

## Acceptance Criteria

- One command prints the next decision as JSON.
- `cmd::start` consumes one decision record per iteration.
- Prompt rendering consumes the decision record.
- Sidecar launch consumes the decision record.
- No prompt mode ownership logic is duplicated outside state code.
- `agent_issue_review` is a transition event, not a hidden `start.sh` special
  case.
- `post_execution_review` carries exactly one `review_target`.
- Unresolved human direction pauses without `COMPLETE`.
- Final completion requires every accepted worker to have a review marker.
- Sidecar `.worker_completed` never closes the task.
- Tests cover live bugs already seen:
  - planning and review ping pong
  - stale `COMPLETE`
  - closed review issue with unreviewed workers
  - repeated `Needs human direction`
  - single agent reviewing many issues
  - Claude prefixed `<END_TURN>`
  - skill handover confirmation suppressing turn exit

## Open Questions

- Should Bash v2 switch `post_execution_review` to reviewer config immediately,
  or keep current worker config until all prompts are audited?
- Should structured gate evidence live in issue description, a Linear comment,
  or both?
- Should review outcomes eventually move from comments into a structured Nancy
  block, while comments remain human readable?
- Should `ISSUES.md` checkboxes be removed once the decision record is the only
  prompt input agents need?
