<!-- b_path:: .planning/ROADMAP.md -->
# Roadmap: Nancy Orchestration Evolution

**Milestone 1: Bidirectional Communication & Automated Review**

## Phase 1: Comms Directory Redesign ✓
**Status:** Complete (2026-01-13)

**Goal:** Restructure comms directory for bidirectional message flow with inbox/outbox pattern.

**Delivered:**
- New directory structure: `comms/{orchestrator,worker}/{inbox,outbox}/`
- Message format: markdown with Type, From, Priority, Time headers
- Message types: blocker, progress, review-request (worker) + directive, guidance, stop (orchestrator)
- Archive pattern with timestamp prefix

**Research:** No

---

## Phase 2: Worker Outbound Messages ✓
**Status:** Complete (2026-01-13)

**Goal:** Enable worker to write messages that can be read by orchestrator.

**Delivered:**
- Updated cmd::direct to use comms::orchestrator_send
- New send-message skill for worker → orchestrator messaging
- Updated check-directives skill for new inbox path
- Updated orchestrator skill to receive worker messages
- Complete bidirectional message flow

**Research:** No

---

## Phase 3: Message Notification Prototypes
**Status:** In Progress (2/3 plans)

**Goal:** Prototype multiple notification mechanisms to interrupt orchestrator.

**Scope:**
- Prototype 1: tmux `display-message` interrupts
- Prototype 2: Signal-based (SIGUSR1 to orchestrator PID)
- Prototype 3: File watcher in separate pane
- Evaluate each for reliability and UX
- Select best approach or combination

**Research:** Yes - Explore tmux capabilities, signal handling in bash, inotifywait alternatives

---

## Phase 3.1: Skills Deep Dive (INSERTED)
**Status:** Complete (2026-01-13)

**Goal:** Research Claude Code skill internals, establish best practices, improve Nancy skills.

**Scope:**
- How does Claude Code process skills? (internals)
- What makes a skill effective? (structure, length, specificity)
- How to test skills in isolation?
- What are community patterns?
- How do our current Nancy skills measure up?
- Improve existing skills based on findings

**Depends on:** Phase 3
**Research:** Yes - Claude Code skill processing, community best practices

---

## Phase 4: Logs Pane as Message Relay ✓
**Status:** Complete (2026-01-13) - Absorbed into Phase 3

**Goal:** Transform useless Logs pane into active message relay during execution.

**Delivered:**
- `_logs` command updated to watch both inboxes
- Real-time message display with fswatch
- tmux display-message for orchestrator notifications
- tmux display-popup for urgent/blocking messages

**Research:** No

---

## Phase 4.1: Sidebar Navigation UI (INSERTED)
**Status:** In Progress (1/2 plans)

**Goal:** Replace fixed 3-pane layout with scalable sidebar navigation.

**Scope:**
- Research tmux pane collapse/hide techniques
- Understand tmux-sidebar plugin approach
- Fix mouse click interaction with gum choose
- Design scalable layout for 3+ panes
- Implement unread indicators

**Prototype attempted:** Failed - resize-pane approach didn't achieve true collapse.

**Research:** Yes - tmux pane management, sidebar plugins, mouse interaction

---

## Phase 5: Post-Completion Review Flow
**Goal:** Implement user prompt flow after worker completes task.

**Scope:**
- Detect worker completion/exit
- Display prompt: "Review work? [Y/n]"
- 10-second timeout with auto-review default
- Handle user choice (review, exit, timeout)
- Transition to review mode

**Research:** No

---

## Phase 6: Review Agent Implementation
**Goal:** Review agent validates work against acceptance criteria.

**Scope:**
- Review agent runs in repurposed Logs/Review pane
- Reads acceptance criteria from SPEC.md or PRD.json
- Systematic validation of each criterion
- Report generation (pass/fail with details)
- Integration with orchestrator for results

**Research:** No

---

## Phase 7: Planning Adapter Foundation
**Goal:** Create adapter pattern for pluggable planning systems.

**Scope:**
- `src/planning/` module structure
- `planning::dispatch` for driver selection
- Driver interface: `init`, `generate`, `validate`, `get_criteria`
- Config option for planning driver selection
- Mirror CLI driver pattern from `src/cli/`

**Research:** No

---

## Phase 8: Minimal Planning Driver
**Goal:** Implement current SPEC.md approach as `minimal` driver.

**Scope:**
- `src/planning/drivers/minimal.sh`
- Wrap existing SPEC.md generation
- Extract criteria from SPEC.md format
- Backward-compatible behavior as default driver

**Research:** No

---

## Phase 9: PRD Planning Driver
**Goal:** Full PRD.json driver with features and Gherkin acceptance criteria.

**Scope:**
- `src/planning/drivers/prd.sh`
- Generate PRD.json using existing schema
- Feature extraction (F-001 format)
- Gherkin acceptance criteria (Given/When/Then)
- Success criteria with verification methods

**Research:** No

---

## Phase 10: Acceptance Criteria Integration
**Goal:** Worker and reviewer use formal acceptance criteria for self-verification.

**Scope:**
- Worker reads criteria during execution for self-check
- Reviewer validates against same criteria
- Criteria status tracking (pending, passed, failed)
- Update SPEC.md or PRD.json with verification results
- Final validation report

**Research:** No

---

## Dependencies

```
Phase 1 ─┬─► Phase 2 ───► Phase 4
         │
         └─► Phase 3 ───► Phase 4

Phase 4 ───► Phase 5 ───► Phase 6

Phase 7 ───► Phase 8 ───► Phase 9 ───► Phase 10

Phase 6 + Phase 10 ───► Complete
```

## Notes

- **ZERO backward compatibility** - Clean break allowed
- Phases 1-6 focus on bidirectional comms and review
- Phases 7-10 focus on planning enhancement
- Both tracks can proceed somewhat in parallel after initial phases
- Review agent (Phase 6) will need acceptance criteria from planning track

---
*Created: 2026-01-13*
*Depth: Comprehensive (10 phases)*
