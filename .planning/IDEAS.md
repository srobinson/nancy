<!-- b_path:: .planning/IDEAS.md -->

# Ideas & Future Work

Captured: 2026-01-13 (Post Phase 3 milestone)

---

## 1. Capture Initial Intent

**Problem:** When user runs `nancy start` or creates a new task, there's an interactive conversation that shapes the task - but this context is lost. The SPEC.md captures the _result_ but not the _reasoning_ or _discussion_ that led to it.

**Value:**

- Worker would understand WHY decisions were made
- Better context for course corrections
- Audit trail of intent vs outcome
- Could inform future similar tasks

**Possible approaches:**

- Capture the interactive session transcript
- Store as `INTENT.md` or `GENESIS.md` alongside SPEC
- Hook into Claude Code's session transcript?

**Status:** Research needed

---

## 2. Claude History File Investigation

**Question:** What is `/Users/alphab/.claude/history.jsonl`?

**Observations:**

- One-way: only captures user prompts, not Claude responses
- Why does Claude Code create this?
- Is there value we can extract?
- Could it complement our comms logging?

**Action:** Research Claude Code internals to understand purpose

**Status:** Research needed

---

## 3. Skills Deep Dive

**Problem:** Skills are powerful but we're not using them optimally. Current skills are ad-hoc, untested, and hard to iterate on.

**Research questions:**

- What makes an optimal skill? Structure, length, specificity?
- How do we test skills in isolation before deploying?
- Can we create a skill development workflow?
- How do other Claude Code users structure skills?
- Are there patterns/anti-patterns documented?

**Deliverables:**

- Best practices document
- Skill testing framework/approach
- Improved existing skills

**Status:** Research project needed

---

## 4. Context Efficiency - Less is More

**Insight:** Research shows more context stuffed into chat = less impactful responses. Smaller, focused context performs better.

**Implications for Nancy:**

- Don't dump everything into worker context
- Iterate more with focused context per iteration
- Quality of context > quantity of context

**Current problem:** We try to give worker "all the context" upfront. This may be counterproductive.

**Better approach:**

- Minimal context per iteration
- Worker asks for what it needs
- Orchestrator provides targeted guidance

**Status:** Rethink context strategy

---

## 5. Session History as First-Class Data

**Insight:** Claude CLI already captures full session transcripts (.jsonl files) FOR FREE. This is goldmine data we're underutilizing.

**Current state:**

- Sessions saved to `.nancy/tasks/<task>/sessions/`
- Raw JSONL format - verbose, not indexed
- Previous session read on startup (sometimes)

**Ideas:**

### 5a. Handover Documents

Instead of raw transcript, outgoing agent creates structured handover:

- What was accomplished
- What's remaining
- Key decisions made
- Blockers encountered
- Recommended next steps

**Trigger:** Agent creates this before session ends (or as part of COMPLETE)

### 5b. Completion Indexing

On COMPLETION, trigger post-processing:

- Summarize session transcript
- Extract key decisions/actions
- Index for future search
- Create structured session summary

**Value:**

- Future sessions can query "what happened when X"
- Pattern recognition across sessions
- Better context loading (load summary, not raw transcript)

### 5c. Session Search

Enable querying across sessions:

- "When did we decide to use terminal-notifier?"
- "What blockers have we hit?"
- "Show all decisions in phase 3"

**Status:** High potential, needs design

---

## 6. Iteration Over Context

**Philosophy shift:** Instead of one long context-heavy session, prefer:

- Multiple short focused iterations
- Clear handover between iterations
- Worker requests context as needed
- Orchestrator provides just-in-time guidance

**Benefits:**

- Fresh context each iteration
- Less token waste on stale context
- Clearer checkpoints
- Better error recovery (restart iteration, not whole task)

**Status:** Architectural consideration

---

## 7. Self-Evolving System Prompt

**Current state:**

- `nancy start` injects a templated PROMPT.md (system prompt)
- Static, one-size-fits-all
- Same instructions regardless of task type

**Problem:**

- Different tasks need different guidance
- A bug fix task ≠ a new feature task ≠ a refactor task
- Static prompt can't adapt to what's working/not working

**Dream:**
The nancy loop (worker + orchestrator + review) could:

1. Start with base PROMPT.md
2. Observe what's working/failing during execution
3. **Revise and optimize the prompt** for this specific task
4. Each iteration gets better-tuned instructions

**This is meta:** The agent improves its own operating instructions.

**Implementation thoughts:**

- Review phase analyzes: "What instructions helped? What caused confusion?"
- Orchestrator can inject prompt amendments via directives
- PROMPT.md becomes versioned: `PROMPT-v1.md`, `PROMPT-v2.md`
- Or: dynamic `PROMPT-AMENDMENTS.md` that layers on base

**Value:**

- Task-specific optimization
- Learning from execution
- Prompts evolve with understanding
- Could feed back into base template improvements

**Challenges:**

- How to measure "prompt effectiveness"?
- Avoiding prompt drift/degradation
- When to lock vs keep evolving

**Status:** Ambitious - needs design

---

## 8. Planning Phase Improvements

**Observation:** The GSD (Get Shit Done) planning flow is powerful but nancy's task creation/planning needs similar rigor.

**Current gap:**

- `nancy init` creates task structure
- `nancy start` begins execution
- But the PLANNING that happens (user ↔ Claude conversation) isn't captured or structured

**Desired:**

- Structured planning phase before execution
- Intent capture (idea #1)
- SPEC refinement loop
- Clear "planning complete, ready for execution" gate

**Related to:** GSD workflow, could adopt similar patterns

**Status:** Integrate GSD learnings

---

## 9. Orchestration UI - Sidebar Navigation

**Current layout:**

```
┌─────────────┬─────────────┐
│ Orchestrator│ Worker      │
│             ├─────────────┤
│             │ Inbox       │
└─────────────┴─────────────┘
```

3 panes, fixed layout. Works but doesn't scale.

**Vision:**

```
┌────┬────────────────────────┐
│ NAV│                        │
│    │                        │
│[W] │    ACTIVE PANE         │
│ O  │    (Worker by default) │
│ I  │                        │
│    │                        │
│    │                        │
└────┴────────────────────────┘
  15%         85%
```

**Sidebar (15%):**

- List of available panes/agents
- Visual indicator for active pane
- **Unread badge** when new messages arrive
- Click/select to switch main view
- Could scale to 10+ panes in future

**Main area (85%):**

- Shows selected pane content
- Default: Worker
- Switch between Worker, Orchestrator, Inbox, future agents

**Notification flow:**

1. Worker sends message
2. Popup appears (current)
3. Inbox item in sidebar gets unread indicator (●)
4. User can switch to Inbox to read, or stay on Worker

**Benefits:**

- Scales beyond 3 panes
- Always visible status of all panes
- Quick navigation
- Unread indicators reduce context switching

**Implementation approach:**

- All panes exist simultaneously in tmux
- Sidebar pane: fixed 15% width, always visible
- Other panes: only ONE expanded at a time (85%)
- Non-active panes: collapsed to 0px (or 1px if tmux requires)
- Selecting from sidebar: `tmux resize-pane` to expand/collapse

```
# Pseudo-implementation
select_pane() {
  # Collapse current active to 0
  tmux resize-pane -t $current -x 0
  # Expand selected to fill
  tmux resize-pane -t $selected -x 85%
}
```

**Sidebar pane:**

- Simple bash/gum TUI listing panes
- Updates indicators when messages arrive
- Keyboard nav (j/k) or click to select

**Status:** UX enhancement - prototype with tmux resize-pane

---

## 10. Fan-Out/Fan-In - Parallel Agents

**Current limitation:** Fixed topology - 1 orchestrator, 1 worker, 1 inbox. Rigid.

**Vision:** Dynamic, on-demand agent spawning.

### Fan-Out Patterns

**Research phase:**

```bash
nancy spawn 3 researchers "Explore authentication approaches"
# Creates: researcher-1, researcher-2, researcher-3
# Each has own inbox, own context, own exploration path
```

**Implementation phase:**

```bash
nancy spawn 3 workers "Implement the auth module"
# 3 parallel implementations
# Compare approaches, pick best or synthesize
```

**Experimentation:**

```bash
nancy spawn 3 variants "Build login form"
# Same task, 3 different outputs
# A/B/C testing of approaches
```

### Fan-In Patterns

After fan-out, need to collect:

- **Synthesize:** Merge findings from 3 researchers into one recommendation
- **Compare:** Diff 3 implementations, pick winner
- **Vote:** Agents review each other's work, consensus

### Dynamic Config

Not rigid config file, but conversational:

```
User: "I want 3 researchers collaborating on this idea"
Nancy: [spawns 3 researcher agents, each with inbox]
Nancy: [creates orchestrator view to manage all 3]
```

### Topology Examples

```
# Research fan-out
         ┌─ Researcher 1 ─┐
Human ── Orchestrator ─┼─ Researcher 2 ─┼── Synthesis
         └─ Researcher 3 ─┘

# Implementation variants
         ┌─ Worker A (approach 1) ─┐
Spec ────┼─ Worker B (approach 2) ─┼── Review & Pick
         └─ Worker C (approach 3) ─┘

# Collaborative implementation
         ┌─ Worker 1 (module A) ─┐
Spec ────┼─ Worker 2 (module B) ─┼── Integration
         └─ Worker 3 (module C) ─┘
```

### Each Agent Has

- Own pane (collapsible per idea #9)
- Own inbox
- Own session history
- Shared access to artifacts (SPEC, code, etc.)

**Status:** Major architectural evolution - design phase topology

---

## Triage

| #   | Idea                   | Priority | Effort    | Next Step                  |
| --- | ---------------------- | -------- | --------- | -------------------------- |
| 1   | Initial Intent Capture | High     | Medium    | Design capture mechanism   |
| 2   | History.jsonl          | Low      | Low       | Quick research             |
| 3   | Skills Deep Dive       | High     | High      | Dedicated research phase   |
| 4   | Context Efficiency     | High     | Medium    | Rethink PROMPT.md strategy |
| 5   | Session History        | High     | High      | Design handover + indexing |
| 6   | Iteration Over Context | Medium   | Low       | Philosophical shift        |
| 7   | Self-Evolving Prompt   | High     | High      | Design feedback loop       |
| 8   | Planning Phase         | High     | Medium    | Adopt GSD patterns         |
| 9   | Sidebar Navigation UI  | Medium   | High      | Research tmux resize-pane  |
| 10  | Fan-Out/Fan-In         | High     | Very High | Design topology system     |

**Themes emerging:**

- **Data capture** (1, 2, 5) - We have data, use it better
- **Context optimization** (4, 6) - Less is more, iterate
- **Tooling quality** (3) - Skills need rigor
- **Meta-learning** (7, 8) - System improves itself
- **UX/UI** (9) - Scale the interface
- **Parallelism** (10) - Multiple agents, dynamic topology
