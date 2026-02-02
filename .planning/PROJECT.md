<!-- b_path:: .planning/PROJECT.md -->

# Nancy Orchestration Evolution

## What This Is

Evolving Nancy's orchestration model with bidirectional communication, automated review, and formal requirements. A clean-break redesign of how orchestrator and worker interact, how tasks are specified, and how work is validated.

## Core Value

**Seamless two-way communication and automated review for autonomous task execution.**

The worker should be able to request help, report progress, and trigger reviews. The reviewer should have formal acceptance criteria to validate against. No more flying blind.

## Requirements

### Validated

(None yet — ship to validate)

### Active

**Two-Way Comms:**

- [ ] Worker can send messages to orchestrator (blockers, progress, review requests)
- [ ] Multiple notification mechanisms explored (tmux display-message, signals, pane relay)
- [ ] New comms directory layout supporting inbox/outbox pattern
- [ ] Message types: blocker, progress, review-request

**Review Process:**

- [ ] Post-completion review flow triggered after worker exits
- [ ] User prompt: "Review work? [Y/n]" with 10s auto-review timeout
- [ ] Review agent checks acceptance criteria systematically
- [ ] Review agent runs in repurposed pane

**Logs Pane Transformation:**

- [ ] Repurpose Logs pane (currently useless repetition of worker output)
- [ ] Options: message relay (watches worker outbox) OR review pane (post-completion)
- [ ] Possibly both: relay during execution, review after completion

**Planning Enhancement:**

- [ ] Planning adapter pattern (like CLI drivers in `src/cli/`)
- [ ] `minimal` driver: current simple SPEC.md approach
- [ ] `prd` driver: full PRD.json with features, acceptance criteria
- [ ] Worker uses acceptance criteria for self-verification
- [ ] Reviewer uses same criteria for validation

### Out of Scope

- **Backward compatibility** — ZERO. Clean break. Existing .nancy/ structures may be incompatible.
- **Tech debt cleanup** — No jq optimization, claude driver refactor, or performance work alongside
- **New CLI drivers** — Focus on Claude Code; Copilot is secondary
- **Multi-worker support** — Single worker per task for now

## Context

**Existing Assets:**

- `schemas/prd.schema.json` — Rich PRD schema with features, Gherkin acceptance criteria, success criteria
- `schemas/task.schema.json` — Minimal task schema (goal, constraints, criteria)
- `src/comms/comms.sh` — Current one-way directive system
- `src/cli/` — Driver pattern to replicate for planning adapters

**Current Pain Points:**

- Planning produces only SPEC.md, no formal acceptance criteria
- No automated review process after worker completes

**Technical Environment:**

- Bash 4+ framework
- tmux for orchestration UI
- File-based IPC (directives, acks)
- Claude Code as primary CLI

## Constraints

- **ZERO backward compatibility** — Can redesign .nancy/ structure freely
- **No new external dependencies** — Use existing tools (bash, tmux, jq, gum)
- **Adapter pattern for extensibility** — Planning system must support future frameworks

## Key Decisions

| Decision                                 | Rationale                                                     | Outcome   |
| ---------------------------------------- | ------------------------------------------------------------- | --------- |
| Clean break (no backward compat)         | Allows proper redesign without legacy constraints             | — Pending |
| Adapter pattern for planning             | Enables experimentation with different requirement frameworks | — Pending |
| Repurpose Logs pane                      | Currently useless, has real estate for value                  | — Pending |
| Explore multiple notification mechanisms | No clear winner yet, need to prototype                        | — Pending |

---

_Last updated: 2026-01-13 after initialization_
