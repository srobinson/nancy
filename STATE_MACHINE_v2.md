# Nancy State Machine v2

Status: ALP-2359 planning contract, pending ALP-2364 gate review.

This document defines the centralized decision contract for Bash Nancy's gate
aware Linear loop. It replaces scattered workflow ownership across selector jq,
runner globals, prompt rendering, sentinels, sidecar state, Linear comments, and
review instructions with one explicit decision boundary.

The active runtime is Bash Nancy. The removed Rust live path is design evidence
only. A future Rust successor must preserve the same contract before changing
supervision mechanics.

## Contract Boundary

Nancy evaluates one loop with this boundary:

```text
ObservedState -> ClassifiedGraph -> DecisionRecord -> RuntimeActions
```

Only `ClassifiedGraph` parses Linear titles, labels, descriptions, states,
relations, comments, and task sentinels. Prompt rendering, `ISSUES.md`, agent
launch, sidecar launch, pause handling, stop handling, completion, and operator
messages consume `DecisionRecord`.

## Sources Of Truth

Linear is durable authority for:

- issue graph shape, parentage, dependencies, blockers, labels, and state
- planning issue state and review acceptance
- gate review outcome and authorized execution set
- worker, corrective, and post execution review terminal state
- comments that mark reviewed workers
- comments that record `Needs human direction` or `Human direction:`
- final parent issue state

Local Nancy files are operational state:

| File | Meaning |
| --- | --- |
| `ISSUES.md` | generated selector evidence and prompt context |
| `HANDOVER.md` | relay coordination only |
| `PAUSE` | loop must not launch another worker turn yet |
| `STOP` | operator requested loop exit after current pipeline returns |
| `COMPLETE` | local task completion after selector `final_completion` |
| `.worker_completed` | sidecar observed turn exit and rotated the worker |
| `.worker_pid` | active foreground worker process |
| `.sidecar_session` | active tmux sidecar session |

`ISSUES.md` and checkboxes never authorize work. `PAUSE`, `STOP`, and
`.worker_completed` never complete a workflow. `COMPLETE` is written only by
the `final_completion` runtime action.

## State Vocabulary

Workflow modes:

| Mode | Actor | Selected issue | Purpose |
| --- | --- | --- | --- |
| `planning` | worker | direct planning or gate review issue | author or repair planning state |
| `agent_issue_review` | reviewer | planning issue just authored | review planning output |
| `execution` | worker | authorized worker issue | implement accepted work |
| `corrective_resolution` | worker | authorized corrective issue | fix a reviewed defect |
| `post_execution_review` | reviewer | authorized review issue | review exactly one accepted worker target |
| `needs_human_direction` | human | none | pause automation for explicit Linear direction |
| `final_completion` | runtime | none | close the master after all authorized work is terminal |
| `task_complete` | none | none | local task is complete and loop exits |
| `stopped` | none | none | operator stopped the loop |
| `paused` | none | none | local process wait state |

`CODE_COMPLETE` is not a local sentinel and not a launch mode in v2. The
contract keeps `execution_queue_empty` as an event that can lead to post
execution review or final completion. Existing prompt text can mention code
complete as a human concept, but no file named `CODE_COMPLETE` should be added.

## Events

Linear graph events:

- `open_planning_found`
- `open_gate_review_found`
- `accepted_gate_found`
- `multiple_accepted_gates_found`
- `authorized_worker_found`
- `authorized_corrective_found`
- `authorized_review_found`
- `unauthorized_backlog_found`
- `unsupported_hierarchy_found`
- `blocker_unreleased`
- `execution_queue_empty`
- `review_target_found`
- `review_marker_found`
- `review_closed_with_unreviewed_target`
- `unresolved_human_direction_found`
- `human_direction_released`
- `all_authorized_work_terminal`

Runtime events:

- `fresh_start`
- `worker_exit_success`
- `worker_exit_failure`
- `reviewer_exit_success`
- `reviewer_exit_failure`
- `sidecar_completion_rotation`
- `operator_pause`
- `operator_unpause`
- `operator_stop`
- `single_run_requested`
- `invalid_selector_json`

## Actions And Side Effects

Decision actions:

| Action | Side effects |
| --- | --- |
| `render_prompt` | write `PROMPT.<task>.md` from `DecisionRecord` |
| `render_issues` | write selector summary and issue table to `ISSUES.md` |
| `launch_worker` | run worker config, sidecar mode `worker`, write `.worker_pid` |
| `launch_reviewer` | run reviewer config, sidecar mode `review`, write `.worker_pid` |
| `write_pause` | write `PAUSE`, print blocker, do not write `COMPLETE` |
| `wait_pause` | block while `PAUSE` exists |
| `clear_pause` | remove `PAUSE` only |
| `write_stop` | stop sidecar, kill worker if present, write `STOP`, remove `PAUSE` |
| `exit_stopped` | remove observed `STOP`, stop watchers, exit loop |
| `write_complete` | mark parent `Worker Done`, write `COMPLETE`, print task complete |
| `normalize_rotation` | treat sidecar driven nonzero exit as success, remove `.worker_completed` |
| `fail_closed` | refuse launch, print explicit evidence, leave Linear unchanged |

Fresh `nancy go` clears stale `STOP` and `COMPLETE` before Linear evaluation.
It does not clear `PAUSE`; pausing is operator intent.

## Decision Record

The selector must emit one JSON object per evaluation:

```json
{
  "version": 2,
  "task_id": "ALP-2359",
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
  "gate": {
    "issue": "ALP-2364",
    "outcome": "ready_for_execution",
    "authorized_parent": "ALP-2365",
    "authorized_issue_ids": ["ALP-2401", "ALP-2402"]
  },
  "thresholds": {
    "blocker_release_states": ["Worker Done", "Done", "Canceled", "Duplicate"],
    "worker_terminal_states": ["Worker Done", "Done"],
    "corrective_terminal_states": ["Worker Done", "Done"],
    "review_terminal_states": ["Done"]
  },
  "evidence": {
    "blocked_candidates": [],
    "unauthorized_backlog_candidates": [],
    "open_corrective": [],
    "open_review": ["ALP-2330"],
    "reviewed_worker_ids": ["ALP-2325"],
    "human_direction": null,
    "invalid_states": []
  },
  "runtime": {
    "launch_agent": true,
    "write_pause": false,
    "write_complete": false,
    "fail_closed": false
  }
}
```

All downstream rendering and launch code consumes this record. No downstream
component reparses Linear prose or recomputes workflow authority.

## Classification Rules

Role detection:

| Role | Detection |
| --- | --- |
| `backlog_parent` | title equals `Backlog` |
| `gate_review` | title matches `Gate review` or `execution readiness` |
| `corrective` | label `Corrective` or title contains `corrective` |
| `post_execution_review` | label `Post Execution Review`, matching title, or matching description marker |
| `planning` | direct open issue that is not Backlog and not gate review |
| `execution` | authorized issue that is not corrective and not review |

Selectable states are `Backlog`, `Todo`, and `In Progress`.

`In Progress` remains selectable for Bash MVP compatibility because Nancy does
not yet have a durable per issue lease. v2 should mark it as recovery evidence
when no active process owns the selected issue. A future lease can restrict
ordinary selection to `Backlog` and `Todo`.

Accepted worker and corrective states are `Worker Done` and `Done`. A post
execution review issue is final only in `Done`.

Blockers are released by `Worker Done`, `Done`, `Canceled`, or `Duplicate`.

## Gate Policy

A gate is accepted only when:

- no open planning issue remains
- no open gate review issue remains
- exactly one gate review issue is accepted
- the accepted gate records one outcome
- the accepted gate names one authorized parent
- the accepted gate records a closed authorized issue set

Accepted outcomes:

```text
ready_for_execution
pre_execution_blockers_required
needs_human_direction
```

Structured v2 evidence:

```text
Nancy-Gate:
  outcome: ready_for_execution
  authorized_parent: ALP-2365
  execute:
    - ALP-2401
    - ALP-2402
```

Legacy Bash evidence remains readable during migration:

```text
Planning complete. Outcome: Ready for execution.
Authorized execution parent: `ALP-2365`.
Execute: ALP-2401, ALP-2402.
```

When both forms exist, structured evidence wins. If they disagree, select
`needs_human_direction`.

Multiple accepted gate review issues are invalid. Nancy must select
`needs_human_direction` and name the conflicting gate issue identifiers.

The accepted `execute` list is closed authority. Open Backlog children outside
that set are invalid until the gate is repaired.

## Transition Priority

The graph reducer chooses the first matching guard:

| Priority | Guard | Mode |
| --- | --- | --- |
| 1 | invalid selector JSON or malformed decision | fail closed |
| 2 | unsupported hierarchy exists | `needs_human_direction` |
| 3 | multiple accepted gates exist | `needs_human_direction` |
| 4 | open planning issue exists | `planning` |
| 5 | open gate review issue exists | `planning` |
| 6 | accepted gate authorizes parent but open Backlog issue is outside `execute` | `needs_human_direction` |
| 7 | open authorized corrective issue exists | `corrective_resolution` |
| 8 | execution queue empty and unresolved review direction exists | `needs_human_direction` |
| 9 | review issue closed before all workers were reviewed | `needs_human_direction` |
| 10 | execution and corrective queues clear, open review issue exists | `post_execution_review` |
| 11 | all authorized work terminal and no review target remains | `final_completion` |
| 12 | accepted gate has authorized worker IDs | `execution` |
| 13 | fallback | `planning` |

This priority preserves ALP-2155: authorized corrective work outranks an
unresolved post execution review pause. It also preserves ALP-2323: when no
authorized corrective work is available, unresolved review direction pauses
automation instead of launching repeated review turns.

## Review Policy

Post execution review is one target per turn.

The selected review issue is the first open authorized review issue. The
selected `review_target` is the first authorized worker issue that:

- is in `Worker Done` or `Done`
- is ordered first by Linear sort order
- has no authorized review comment beginning `Reviewed worker issue: ISSUE-ID`

Informal pass comments do not count.

Review outcomes:

| Outcome | Required Linear evidence | Next graph effect |
| --- | --- | --- |
| accepted | `Reviewed worker issue: ISSUE-ID` comment | next review target or final readiness |
| defect | corrective issue plus review comment | `corrective_resolution` if authorized |
| unsafe decision | `Needs human direction` comment | `needs_human_direction` |

`Human direction:` releases only the latest unresolved review direction event.
`nancy unpause <task>` removes `PAUSE`; it does not provide Linear direction. If
Linear still records unresolved direction, the next evaluation writes `PAUSE`
again.

## Runtime Policy

Runtime handles local events in this order:

| Event | Action |
| --- | --- |
| `STOP` exists | stop sidecar, remove `STOP`, stop watchers, exit |
| `PAUSE` exists before launch | wait until removed |
| `.worker_completed` exists after launch | normalize exit, clear sentinel, evaluate graph |
| `worker_exit_failure` | stop with failure evidence |
| `reviewer_exit_failure` | stop with failure evidence |
| `single_run_requested` after one turn | exit without completion |

`agent_issue_review` becomes a first class transition after successful
`planning` when reviewer config exists. Current Bash still implements it as a
runner follow up.

`post_execution_review` uses reviewer actor and reviewer config in the v2
contract. Current Bash primary pass still uses worker config. That mismatch is
a migration candidate, not contract intent.

## Terminal Conditions

`final_completion` is valid only when:

- an accepted gate exists
- all authorized issue IDs resolve in status evidence
- worker issues are `Worker Done` or `Done`
- corrective issues are `Worker Done` or `Done`
- post execution review issues are `Done`
- every accepted worker has a `Reviewed worker issue:` marker
- no unresolved human direction remains
- no unauthorized Backlog issue remains
- no unsupported hierarchy remains

`task_complete` follows only from `final_completion` actions:

1. mark the parent issue `Worker Done`
2. write `COMPLETE`
3. print task complete
4. exit the loop

## Invalid States

Nancy must fail closed or pause for human direction for:

- selector output is not exactly one valid JSON object
- selected mode has no selected issue outside `needs_human_direction` or
  `final_completion`
- direct master child is executable work outside an authorized execution parent
- Backlog child is open after gate acceptance but missing from `execute`
- deeper than parent, child, grandchild hierarchy
- multiple accepted gate review issues
- structured and legacy gate evidence disagree
- accepted gate points to a parent that is missing from Linear evidence
- authorized issue ID is missing from status evidence
- post execution review issue is terminal before every accepted worker is
  reviewed
- unresolved human direction exists and no authorized corrective work is open
- final completion is requested while `PAUSE` or unresolved direction remains

Invalid states never launch workers by falling back to checkbox order.

## Replay Scenarios

### ALP-2155

Given:

- accepted gate authorizes Backlog `ALP-X`
- accepted `execute` includes corrective issue `ALP-C`
- `ALP-C` is `Backlog`, `Todo`, or `In Progress`
- review issue records unresolved `Needs human direction`

Then:

- mode is `corrective_resolution`
- selected issue is `ALP-C`
- no `PAUSE` is written by that evaluation

Invalid variant:

- if `ALP-C` is under Backlog but absent from `execute`, mode is
  `needs_human_direction` for gate repair

### ALP-2323

Given:

- post publish smoke review cannot decide safely
- review issue records `Needs human direction`
- no authorized corrective issue is open

Then:

- mode is `needs_human_direction`
- selected issue is none
- `PAUSE` is written or preserved
- `COMPLETE` is not written
- no review turn launches until a later `Human direction:` comment releases it

### Invalid selector render

Given selector output contains a valid object followed by trailing garbage,
Nancy must canonicalize once, emit explicit `invalid_selector` evidence, and
refuse launch. Raw jq parse noise is not the operator interface.

### Operator controls

`nancy pause <task>` writes `PAUSE` and asks the active worker to end cleanly.
`nancy unpause <task>` removes `PAUSE` only. `nancy stop <task>` stops sidecar,
kills the current worker when possible, writes `STOP`, removes `PAUSE`, and
exits after the loop observes `STOP`.

## Bash Migration Candidates

These are Backlog candidates for `ALP-2365` after ALP-2364 authorizes
execution. They are intentionally not direct children of `ALP-2359`.

1. Define `DecisionRecord` schema and golden fixtures. Add a command or helper
   that prints the next decision as one JSON object while preserving current
   selector results.
2. Extract selector policies from `src/linear/selector.sh` into named state
   helpers. Preserve existing test behavior, including ALP-2155 and ALP-2323.
3. Add structured `Nancy-Gate` parsing with legacy fallback. Fail closed on
   multiple accepted gates and structured or legacy disagreement.
4. Move `cmd::start` from `_NEXT_*` globals to one per iteration
   `DecisionRecord` variable consumed by prompt render, agent config routing,
   sidecar mode, pause, and completion.
5. Promote `agent_issue_review` and `post_execution_review` routing to explicit
   decision outputs. Route `post_execution_review` through reviewer config after
   prompt and tests confirm parity.
6. Add replay fixtures for invalid selector JSON, unauthorized Backlog,
   operator pause, operator stop, `Human direction:` release, final completion,
   and stale `STOP` or `COMPLETE`.

## Rust Successor Constraints

The Rust live path was removed because subprocess supervision and JSONL parsing
did not preserve current foreground pane control. A Rust successor must start
from the same `DecisionRecord` contract and preserve:

- Linear first selection
- foreground pane worker control
- sidecar observation rather than hidden ownership
- operator pause, stop, and unpause semantics
- `ISSUES.md` as evidence
- `HANDOVER.md` as coordination state
- `COMPLETE` only after selector final completion

Use plain enums and structs first. Typestate can protect dangerous actions
later, especially parent closure, review closure, pause, completion, and
corrective issue creation.

## Acceptance For This Contract

The planning gate is ready for ALP-2364 review when:

- the contract names states, events, actions, side effects, terminal conditions,
  and invalid states
- Linear and local sentinel boundaries are explicit
- planning, issue review, execution, corrective resolution, post execution
  review, human direction, pause, stop, final completion, and task completion
  are covered
- ALP-2155 and ALP-2323 replay scenarios are explicit
- Backlog candidates are named but not authorized before gate review
- ALP-2364 records exactly one reviewed outcome
