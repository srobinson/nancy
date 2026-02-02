# Research: check-directives Skill

**Date:** 2026-01-21
**Researcher:** Claude
**Status:** Complete

## Executive Summary

The `check-directives` skill is part of Nancy's orchestrator-worker communication system. It enables worker agents to receive and process messages (directives) from an orchestrator agent during autonomous task execution. However, the current implementation has significant UX issues, as documented in `.planning/TODO-auto-injection-updates.md` - specifically, the skill teaches manual polling when auto-injection is now available.

**Key Finding:** The skill is partially obsolete. Auto-injection via fswatch now pushes `nancy inbox` commands directly into the worker pane when directives arrive. The skill should be refactored to document this behavior, not teach manual polling.

---

## Current Implementation

### Files Involved

| File                                    | Purpose                                                       |
| --------------------------------------- | ------------------------------------------------------------- |
| `skills/check-directives/skill.md`      | Skill definition - teaches worker how to check for directives |
| `src/comms/comms.sh`                    | Core IPC library - bidirectional file-based messaging         |
| `src/cmd/inbox.sh`                      | Command implementation - `nancy inbox`                        |
| `src/cmd/direct.sh`                     | Command for orchestrator to send directives                   |
| `src/notify/watcher.sh`                 | fswatch-based watcher that auto-injects inbox checks          |
| `src/notify/inject.sh`                  | tmux send-keys injection for Claude Code                      |
| `TMP/skills copy/check-directives/*.sh` | Archived shell scripts (not in use)                           |

### Skill Content (929 characters)

```yaml
---
name: check-directives
description: Check for orchestrator messages. Use at turn start, after major tasks, and ALWAYS before marking task complete.
---
```

The skill instructs the worker to:

1. Run `nancy inbox` to check for pending directives
2. Process each message by type (`directive`, `guidance`, `stop`)
3. Archive messages after acting with `nancy archive <filename>`
4. Check at: session start, after major tasks, ALWAYS before completion

### Communication Flow

```
Orchestrator                          Worker
    |                                    |
    |-- nancy direct TASK "message" ---> |
    |                                    |
    |   [File written to worker/inbox]   |
    |                                    |
    |   [fswatch detects new file]       |
    |                                    |
    |   [inject.sh sends "nancy inbox"]  |
    |                                    |
    |                       <-- worker reads, acts, archives
    |                                    |
    |-- nancy msg TYPE "message" <-------|
    |                                    |
```

### Directory Structure

```
.nancy/tasks/<task>/comms/
├── orchestrator/
│   └── inbox/         # Messages FROM worker TO orchestrator
├── worker/
│   └── inbox/         # Directives FROM orchestrator TO worker
└── archive/           # Processed messages
```

### Message Types

**From Orchestrator to Worker:**

- `directive` - Specific instruction to follow
- `guidance` - Suggestions, non-mandatory
- `stop` - End task immediately

**From Worker to Orchestrator:**

- `blocker` - Worker is stuck
- `progress` - Status update
- `review-request` - Work ready for review

---

## How It Works

### 1. Directive Sending (Orchestrator)

```bash
nancy direct <task> "Focus on tests first" --type guidance
```

This calls `cmd::direct` which uses `comms::orchestrator_send` to write a timestamped markdown file to `comms/worker/inbox/`.

### 2. Notification (fswatch)

The `notify::watch_comms` function (in `watcher.sh`) uses fswatch to monitor both inboxes. When a file is created in `worker/inbox/`:

```bash
notify::inject_directive_check "$win.$pane_worker"
# Injects: "nancy inbox" + Enter key
```

### 3. Worker Processing (Auto or Manual)

When `nancy inbox` runs, it:

1. Discovers the active task directory
2. Lists files in `comms/worker/inbox/`
3. Shows metadata (type, priority) and full paths
4. Prompts worker to use `nancy read <filename>` and `nancy archive <filename>`

### 4. Skill Invocation

The skill is triggered when Claude detects phrases like:

- "check inbox"
- "orchestrator messages"
- "any directives"

Or when the worker follows the PROMPT.md template which instructs periodic checking.

---

## Drawbacks and Limitations

### 1. Obsolete Polling Instructions

**Problem:** The skill teaches manual polling (`nancy inbox`) when auto-injection now handles this automatically.

**Impact:**

- Workers may poll unnecessarily, wasting tokens
- Documentation is out of sync with actual behavior
- New users may not understand the auto-injection system

**Evidence:** From `.planning/TODO-auto-injection-updates.md`:

> "This skill may need deprecation or major refactoring"

### 2. No Acknowledgment of Auto-Injection

**Problem:** The skill doesn't mention that directives are auto-pushed. Workers don't know the difference between:

- Auto-injected `nancy inbox` (directive just arrived)
- Manual `nancy inbox` (worker checking proactively)

**Impact:** Confusion about when/why to check inbox.

### 3. Completion Check is Manual

**Problem:** The skill says "ALWAYS before marking task COMPLETE" but this isn't enforced. A worker can mark complete without checking.

**Impact:** Unread directives may exist when worker marks complete.

**Better approach:** Use a Stop hook to verify inbox is empty before allowing completion.

### 4. Archive is Manual

**Problem:** Workers must remember to archive each message after acting.

**Impact:**

- Messages may be re-processed
- Inbox accumulates old messages
- Worker may skip archiving

### 5. Skill Doesn't Load Script

**Problem:** The archived shell scripts in `TMP/skills copy/check-directives/` are not used. The skill only provides documentation.

**Impact:** No programmatic verification that directives were processed.

### 6. Three-Step Process is Verbose

**Problem:** Check -> Read -> Archive requires three separate commands.

**Impact:** Increases likelihood of missed steps, especially archiving.

### 7. No Priority-Based Handling

**Problem:** All directive types are treated similarly. `stop` directives should interrupt immediately.

**Impact:** Worker may continue working after receiving `stop` if they don't process quickly.

### 8. Description Relies on Triggers

**Problem:** Skill triggers on phrases like "check inbox" but worker may not say those words.

**Impact:** Skill may not be invoked when worker needs guidance.

---

## Research Findings

### Multi-Agent Orchestration Patterns

From [Anthropic's Multi-Agent Research System](https://www.anthropic.com/engineering/multi-agent-research-system):

> "Rather than requiring subagents to communicate everything through the lead agent, implement artifact systems where specialized agents can create outputs that persist independently."

**Implication:** Nancy's file-based inbox pattern aligns with this - directives are artifacts that persist until processed.

### Stop Hooks for Completion Verification

From [Claude Code Hooks Documentation](https://code.claude.com/docs/en/hooks):

> "A Stop hook can check for specific conditions, such as verifying all tasks in a checklist are marked done. If the condition is not met, it outputs JSON with 'decision': 'block'."

**Implication:** Nancy should use a Stop hook to verify the inbox is empty before allowing worker to complete. This makes the pre-completion check automatic and enforceable.

Example pattern:

```json
{
  "Stop": [
    {
      "matcher": "*",
      "hooks": [
        {
          "type": "command",
          "command": "nancy inbox --check-empty"
        }
      ]
    }
  ]
}
```

### Push vs Poll Communication

From [AWS A2A Protocol Blog](https://aws.amazon.com/blogs/opensource/open-protocols-for-agent-interoperability-part-4-inter-agent-communication-on-a2a/):

> "For long-running operations, A2A enhances each transport with Server-Sent Events (SSE) for streaming and webhook-based push notifications. Developers get intuitive options to handle asynchronous task updates and real-time progress monitoring without complex polling logic."

**Implication:** Nancy's fswatch-based auto-injection is the right pattern. The skill should embrace push semantics, not teach polling.

### Prompt-Based Hooks for Context-Aware Decisions

From [Claude Code Hook Development](https://claude.com/blog/how-to-configure-hooks):

> "Prompt-based hooks use an LLM to evaluate whether to allow or block an action. They enable intelligent, context-aware decisions."

**Implication:** For `stop` directives, a prompt-based Stop hook could evaluate whether the worker has truly acknowledged and acted on the stop request.

### Artifact Systems for Communication

From [ByteByteGo on Anthropic's Multi-Agent System](https://blog.bytebytego.com/p/how-anthropic-built-a-multi-agent):

> "Subagents call tools to store their work in external systems, then pass lightweight references back to the coordinator. This prevents information loss during multi-stage processing and reduces token overhead."

**Implication:** The current file-based approach is correct. Enhancements should focus on making the reference (inbox notification) more actionable, not replacing the file system.

---

## Improvement Proposals

### Proposal 1: Stop Hook for Completion Verification (HIGH PRIORITY)

**Problem Solved:** Workers can complete with unread directives.

**Implementation:**

Create a Stop hook that checks inbox before allowing completion:

```bash
#!/bin/bash
# hooks/check-inbox-on-stop.sh

# Read hook input
HOOK_INPUT=$(cat)

# Check if this is a nancy task
TASK_DIR=$(find .nancy/tasks -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1)
if [[ -z "$TASK_DIR" ]]; then
    exit 0  # No task, allow stop
fi

INBOX_DIR="$TASK_DIR/comms/worker/inbox"
if [[ ! -d "$INBOX_DIR" ]]; then
    exit 0  # No inbox, allow stop
fi

# Count pending directives
PENDING=$(find "$INBOX_DIR" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')

if [[ "$PENDING" -gt 0 ]]; then
    # Block stop - there are unread directives
    jq -n \
        --arg count "$PENDING" \
        '{
            "decision": "block",
            "reason": "You have unread directives in your inbox. Run `nancy inbox` to check and process them before completing.",
            "systemMessage": "Inbox has " + $count + " pending directive(s). Process before completing."
        }'
else
    # Allow stop
    jq -n '{"decision": "approve"}'
fi

exit 0
```

**Benefits:**

- Enforces the "check before complete" rule automatically
- No behavior change needed from worker
- Fits Claude Code's hook model

### Proposal 2: Combined Read-and-Archive Command (MEDIUM PRIORITY)

**Problem Solved:** Three-step process (check, read, archive) is verbose.

**Implementation:**

Add `nancy inbox --process` that:

1. Reads each directive
2. Displays content with clear formatting
3. Asks "Mark as processed? (y/n/skip)"
4. Archives on confirmation

Or even simpler, auto-archive after read:

```bash
nancy read <filename>  # Already shows content, now also archives
```

**Benefits:**

- Single command for most common workflow
- Reduces forgotten archives

### Proposal 3: Update Skill for Push Semantics (HIGH PRIORITY)

**Problem Solved:** Skill teaches polling, but push is now available.

**New Skill Content:**

````markdown
---
name: check-directives
description: Check for orchestrator messages. Use at turn start, after major tasks, and ALWAYS before marking task complete.
---

# Check Directives

## Automatic Delivery

When the orchestrator sends a directive, `nancy inbox` is automatically
injected into your session. You will see it run without typing.

**Just process the result.** No need to poll manually.

## Processing Directives

For each directive shown:

1. **Read** the content carefully
2. **Act** based on type:
   - `stop` - End task immediately, do not continue
   - `directive` - Follow the specific instruction
   - `guidance` - Adjust your approach accordingly
3. **Archive** after acting:
   ```bash
   nancy archive <filename>
   ```
````

## Manual Fallback

If you suspect missed messages (long pause, re-entering session):

```bash
nancy inbox
```

## Pre-Completion Check

Before creating the COMPLETE file:

1. Run `nancy inbox` manually
2. Process and archive ALL pending directives
3. Only mark complete when inbox is empty

**Warning:** The Stop hook will block completion if inbox has messages.

````

**Benefits:**
- Accurate documentation
- Explains push semantics
- Mentions Stop hook enforcement

### Proposal 4: Priority-Based Auto-Handling (LOW PRIORITY)

**Problem Solved:** `stop` directives should interrupt immediately.

**Implementation:**

Modify `inject.sh` to parse directive type and inject different commands:

```bash
# For stop directives
notify::inject_prompt "$pane" "STOP: Orchestrator sent stop directive. Cease work immediately and run: nancy inbox"

# For urgent directives
notify::inject_prompt "$pane" "URGENT: New directive. Run: nancy inbox"

# For normal directives
notify::inject_prompt "$pane" "nancy inbox"
````

**Benefits:**

- Stop directives get immediate attention
- Priority levels become meaningful

### Proposal 5: SessionStart Hook for Fresh Session (LOW PRIORITY)

**Problem Solved:** Worker may not check inbox at session start.

**Implementation:**

Add a SessionStart hook that runs `nancy inbox` on new sessions:

```json
{
  "SessionStart": [
    {
      "matcher": "*",
      "hooks": [
        {
          "type": "command",
          "command": "nancy inbox 2>/dev/null || true"
        }
      ]
    }
  ]
}
```

**Benefits:**

- Ensures missed messages from previous sessions are seen
- Automatic, no worker action needed

---

## Recommended Approach

### Phase 1: Documentation Update (Immediate)

1. Update `skills/check-directives/skill.md` with push semantics (Proposal 3)
2. Update `templates/PROMPT.md.template` to remove polling language
3. Update `skills/README.md` description

### Phase 2: Stop Hook for Completion (Next Sprint)

1. Implement Stop hook (Proposal 1)
2. Add to Nancy's hook configuration
3. Test with various inbox states
4. Document in skill

### Phase 3: UX Improvements (Future)

1. Consider combined read-and-archive (Proposal 2)
2. Evaluate priority-based handling (Proposal 4)
3. Consider SessionStart hook (Proposal 5)

---

## Implementation Recommendation

**Start with Proposal 3 (Skill Update)** - This is low-risk, addresses the documentation gap identified in `TODO-auto-injection-updates.md`, and provides immediate value.

**Then implement Proposal 1 (Stop Hook)** - This is the most impactful improvement, making the pre-completion check enforceable rather than advisory.

The other proposals can be evaluated based on user feedback after the core improvements are in place.

---

## Appendix: Related Files

| File                                                                                         | Relevance                               |
| -------------------------------------------------------------------------------------------- | --------------------------------------- |
| `.planning/TODO-auto-injection-updates.md`                                                   | Identifies this skill as needing update |
| `.planning/phases/03-message-notification-prototypes/03-RESEARCH.md`                         | fswatch/notification research           |
| `.planning/phases/02-worker-outbound-messages/02-01-PLAN.md`                                 | Bidirectional comms plan                |
| `src/notify/watcher.sh`                                                                      | Auto-injection implementation           |
| `.claude/plugins/marketplaces/claude-plugins-official/plugins/nancy-loop/hooks/stop-hook.sh` | Example Stop hook                       |

---

## Sources

### Internal Codebase

- `skills/check-directives/skill.md` - Current implementation
- `src/comms/comms.sh` - IPC library
- `src/notify/watcher.sh` - Auto-injection
- `.planning/TODO-auto-injection-updates.md` - Known issues

### External Research

- [Anthropic Multi-Agent Research System](https://www.anthropic.com/engineering/multi-agent-research-system)
- [Claude Code Hooks Documentation](https://code.claude.com/docs/en/hooks)
- [Claude Code Hook Power User Guide](https://claude.com/blog/how-to-configure-hooks)
- [AWS A2A Protocol](https://aws.amazon.com/blogs/opensource/open-protocols-for-agent-interoperability-part-4-inter-agent-communication-on-a2a/)
- [ByteByteGo: How Anthropic Built Multi-Agent System](https://blog.bytebytego.com/p/how-anthropic-built-a-multi-agent)
- [Claude Code Stop Hook Quality Gates](https://jpcaparas.medium.com/claude-code-use-hooks-to-enforce-end-of-turn-quality-gates-5bed84e89a0d)

---

_Research completed: 2026-01-21_
