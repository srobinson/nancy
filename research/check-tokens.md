# Check-Tokens Feature Research

**Date:** 2026-01-21
**Status:** Research Complete
**Researcher:** Claude (via Nancy research task)

---

## Executive Summary

The `check-tokens` skill in Nancy is designed to help worker agents monitor their context window usage and make decisions about when to wrap up or end their turn. While the implementation is functional, it has several significant limitations that impact its effectiveness. This document analyzes the current implementation, identifies drawbacks, reviews industry best practices, and proposes improvements.

**Key Finding:** The current skill-based approach requires manual invocation by the agent, making it unreliable. A hook-based automatic injection approach would be more effective and align with emerging best practices for Claude Code extensions.

---

## 1. Current Implementation

### 1.1 Location and Files

| File                                   | Purpose                                                         |
| -------------------------------------- | --------------------------------------------------------------- |
| `/skills/check-tokens/SKILL.md`        | Skill definition and documentation                              |
| `/skills/check-tokens/check-tokens.sh` | Bash script that reads session files and calculates token usage |
| `/templates/PROMPT.md.template`        | Worker prompt referencing the skill                             |
| `/src/cmd/setup.sh`                    | Sets `token_threshold` config                                   |
| `/src/config/config.sh`                | Exports `NANCY_TOKEN_THRESHOLD`                                 |

### 1.2 How It Works

The `check-tokens` skill is a Claude Code skill that:

1. **Is manually invoked** by the worker agent using the skill system
2. **Reads session JSONL files** from Claude's project directory (`~/.claude/projects/<encoded-path>/<uuid>.jsonl`)
3. **Extracts token usage** from the last assistant message's `.message.usage` field
4. **Calculates metrics:**
   - `cache_read_input_tokens` + `cache_creation_input_tokens` + `input_tokens` = Total context used
   - Compares against assumed 200,000 token limit
5. **Returns a recommendation** based on percentage remaining:

| Remaining | Recommendation | Action                                       |
| --------- | -------------- | -------------------------------------------- |
| > 50%     | `CONTINUE`     | Work freely, start new tasks                 |
| 40-50%    | `WRAP_UP`      | Finish current task, don't start new ones    |
| < 40%     | `END_TURN`     | Stop immediately, commit, summarize progress |

### 1.3 Token Calculation Method (Claude)

```bash
# From check-tokens.sh lines 246-264
cache_read=$(echo "$LATEST" | jq -r '.message.usage.cache_read_input_tokens // 0')
cache_create=$(echo "$LATEST" | jq -r '.message.usage.cache_creation_input_tokens // 0')
input_tokens=$(echo "$LATEST" | jq -r '.message.usage.input_tokens // 0')

# Total context = cached context + new input
TOKENS_USED=$((cache_read + cache_create + input_tokens))
```

### 1.4 Environment Variables

| Variable                 | Description                     | Default      |
| ------------------------ | ------------------------------- | ------------ |
| `NANCY_CLI`              | Which CLI (copilot, claude)     | `copilot`    |
| `NANCY_CURRENT_TASK_DIR` | Current task directory          | (none)       |
| `NANCY_PROJECT_ROOT`     | Project root for session lookup | `$(pwd)`     |
| `NANCY_TOKEN_THRESHOLD`  | End turn threshold              | `0.20` (20%) |
| `NANCY_SESSION_ID`       | Current Nancy session ID        | (none)       |

### 1.5 Session File Discovery

The script has a complex session file resolution process:

1. Check task-local `session-state/` directory (copied by Nancy after each run)
2. Derive task directory from session ID pattern (`nancy-<task>-iter<N>`)
3. Look up UUID from `session-uuids.json` mapping file
4. Check if session ID is already a UUID
5. For new sessions, return 100% remaining with a "new-session" note

---

## 2. How It Works (Detailed Flow)

### 2.1 Worker Prompt Integration

From `/templates/PROMPT.md.template`:

```markdown
## 1. Initiate

**Check tokens** (use skill):

- Compare against `token_threshold` in config

## 5. Tokens

Check periodically using `skills/check-tokens/SKILL.md`.

When approaching threshold:

- **CONTINUE**: Work freely
- **WRAP_UP**: Finish current task, commit, stop
- **END_TURN**: Commit immediately, stop
```

### 2.2 Invocation Pattern

The agent is instructed to:

1. Check tokens at turn start
2. Check periodically during long tasks
3. Act on the recommendation

### 2.3 Output Format

```json
{
  "tokenLimit": 200000,
  "tokensUsed": 92835,
  "tokensRemaining": 107165,
  "percentUsed": 46,
  "percentRemaining": 54,
  "recommendation": "CONTINUE",
  "timestamp": "2026-01-11T12:00:00.000Z",
  "session": "nancy-my-task-iter5",
  "cli": "claude"
}
```

### 2.4 Terminal Display Integration

The Claude driver in `/src/cli/drivers/claude.sh` formats token check results with colored output:

```jq
if $parsed.recommendation then
    ($parsed.recommendation) as $rec |
    ($parsed.percentRemaining // 100) as $pct |
    (if $rec == "END_TURN" then red elif $rec == "WRAP_UP" then yellow else green end) as $color |
    "\($color)Tokens: \($pct)% remaining -> \($rec)\(reset)"
```

---

## 3. Drawbacks and Limitations

### 3.1 Fundamental Issues

| Issue                          | Severity | Description                                                                 |
| ------------------------------ | -------- | --------------------------------------------------------------------------- |
| **Manual Invocation Required** | HIGH     | Agent must remember to call the skill; no automatic checking                |
| **Late Detection**             | HIGH     | By the time agent checks, it may already be too late                        |
| **Session File Lag**           | MEDIUM   | Session file only updated after responses; can't check mid-generation       |
| **Approximation Only**         | MEDIUM   | Token calculation is an approximation (cache_read + cache_creation + input) |
| **No Real-Time Visibility**    | HIGH     | Claude Code doesn't expose live token counts to extensions                  |

### 3.2 UX Issues

| Issue                       | Description                                                                            |
| --------------------------- | -------------------------------------------------------------------------------------- |
| **Skill May Not Trigger**   | Claude Code skill discovery can be unreliable; agent may not invoke it                 |
| **No Progress Indicator**   | Human operator has no visibility into context usage unless checking logs               |
| **Config Complexity**       | `NANCY_TOKEN_THRESHOLD` is defined but never actually used in the recommendation logic |
| **Inconsistent Thresholds** | Script uses hardcoded 40%/50% thresholds, ignoring the configurable threshold          |

### 3.3 Technical Issues

| Issue                         | Description                                                        |
| ----------------------------- | ------------------------------------------------------------------ |
| **Complex Session Discovery** | 7+ fallback mechanisms for finding session files                   |
| **UUID Mapping Complexity**   | Requires maintaining `session-uuids.json` mapping files            |
| **Race Condition Risk**       | Session file may be written while being read                       |
| **BC Dependency**             | Uses `bc` for decimal-to-integer conversion (not always installed) |

### 3.4 Current Threshold Logic Bug

The `NANCY_TOKEN_THRESHOLD` config option is read but **never used** in the recommendation logic:

```bash
# Token threshold is loaded but ignored:
TOKEN_THRESHOLD="${TOKEN_THRESHOLD:-20}"

# Recommendation uses hardcoded values:
if [[ $PERCENT_REMAINING -lt 40 ]]; then
    RECOMMENDATION="END_TURN"
elif [[ $PERCENT_REMAINING -le 50 ]]; then
    RECOMMENDATION="WRAP_UP"
else
    RECOMMENDATION="CONTINUE"
fi
```

### 3.5 Claude Code Auto-Compact Interaction

Claude Code has its own auto-compact feature that:

- Triggers at ~75% usage (25% remaining) in VSCode extension
- Triggers at ~95% usage (5% remaining) in CLI
- May compact conversation without Nancy's knowledge
- Can invalidate Nancy's token tracking

---

## 4. Research Findings

### 4.1 Claude Code Context Management (Official)

Sources: [Context Windows - Claude Docs](https://platform.claude.com/docs/en/build-with-claude/context-windows), [Managing Context](https://www.anthropic.com/news/context-management)

**Key Features:**

- 200,000 token standard context window
- **Context Editing**: Automatically clears stale tool calls (84% token reduction)
- **Memory Tool**: Store information outside context window
- **Auto-Compact**: Summarizes conversation when approaching limits

**Best Practice:** "Avoid using the final 20% of your context window for complex tasks, as performance degrades significantly when approaching limits."

### 4.2 Claude Code Hooks (additionalContext)

Sources: [Hooks Reference](https://code.claude.com/docs/en/hooks), [Issue #15345](https://github.com/anthropics/claude-code/issues/15345)

**PreToolUse hooks can inject context:**

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "additionalContext": "Your reminder or context here"
  }
}
```

**Benefits:**

- Runs before every tool call
- Context visible to Claude
- No manual invocation needed
- Reliable injection mechanism

### 4.3 Aider's Approach

Sources: [Aider Options](https://aider.chat/docs/config/options.html), [Aider Repo Map](https://aider.chat/docs/repomap.html)

**Aider provides:**

- `/tokens` command to report context usage
- `--map-tokens` to set repo map token budget
- `--max-chat-history-tokens` for auto-summarization
- PageRank-based algorithm for prioritizing context

**Key Insight:** "Aider never enforces token limits, it only reports token limit errors from the API provider."

### 4.4 Cursor's Approach

Sources: [Developer Toolkit](https://developertoolkit.ai/en/shared-workflows/context-management/context-windows/)

**Challenges identified:**

- "Cursor's context window limitations create productivity bottlenecks"
- "Failures at 80% context utilization"
- "Agent mode context degradation"

### 4.5 Session Handoffs Pattern

Source: [DEV Community](https://dev.to/dorothyjb/session-handoffs-giving-your-ai-assistant-memory-that-actually-persists-je9)

**Recommended approach:**

- "Session handoffs are structured documents that capture session context"
- "Human-readable, AI-readable, searchable, tool-agnostic, version-controlled"
- "Begin each new session with 'Read the context files and continue where we left off'"

---

## 5. Improvement Proposals

### 5.1 Proposal A: Hook-Based Automatic Token Warning

**Approach:** Use a PreToolUse hook to automatically check tokens and inject warnings into Claude's context.

**Implementation:**

```json
// .claude/settings.local.json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "${NANCY_FRAMEWORK_ROOT}/hooks/check-tokens-hook.sh"
          }
        ]
      }
    ]
  }
}
```

```bash
#!/usr/bin/env bash
# hooks/check-tokens-hook.sh

# Quick exit if no task context
[[ -z "$NANCY_CURRENT_TASK_DIR" ]] && echo '{"hookSpecificOutput":{"permissionDecision":"allow"}}' && exit 0

# Run token check
RESULT=$("$NANCY_FRAMEWORK_ROOT/skills/check-tokens/check-tokens.sh" 2>/dev/null)
REC=$(echo "$RESULT" | jq -r '.recommendation // "CONTINUE"')
PCT=$(echo "$RESULT" | jq -r '.percentRemaining // 100')

# Only inject context for WRAP_UP or END_TURN
if [[ "$REC" == "WRAP_UP" ]] || [[ "$REC" == "END_TURN" ]]; then
    CONTEXT="[NANCY TOKEN WARNING] ${PCT}% context remaining. Recommendation: ${REC}. "
    if [[ "$REC" == "END_TURN" ]]; then
        CONTEXT+="STOP immediately - commit progress and end turn."
    else
        CONTEXT+="Finish current task, then stop."
    fi

    cat <<EOF
{
  "hookSpecificOutput": {
    "permissionDecision": "allow",
    "additionalContext": "$CONTEXT"
  }
}
EOF
else
    echo '{"hookSpecificOutput":{"permissionDecision":"allow"}}'
fi
```

**Pros:**

- Automatic - no manual invocation needed
- Runs before every tool call
- Non-blocking (allows tool to proceed)
- Only adds context when necessary

**Cons:**

- Adds latency to every tool call
- Requires Claude Code 2.1.9+ for additionalContext support
- May flood context if checking too frequently

### 5.2 Proposal B: Stop Hook Token Gate

**Approach:** Use a Stop hook to prevent premature completion and require explicit acknowledgment of token status.

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "${NANCY_FRAMEWORK_ROOT}/hooks/stop-token-check.sh"
          }
        ]
      }
    ]
  }
}
```

**Behavior:**

- When agent tries to stop, hook checks token usage
- If > 50% remaining, ask agent to confirm it completed work
- If < 50%, allow stop (expected behavior)
- If < 20%, force stop and summarize

**Pros:**

- Catches premature completion
- Integrates with Nancy's loop behavior

**Cons:**

- Only runs at stop time, not during work

### 5.3 Proposal C: Periodic Token Reporter (Separate Process)

**Approach:** Run a background process that monitors session files and logs token usage.

```bash
# Run alongside Nancy
while true; do
    RESULT=$(check-tokens.sh "$NANCY_SESSION_ID")
    echo "[$(date)] Token Check: $(echo "$RESULT" | jq -r '.percentRemaining')% remaining"
    sleep 30
done
```

**Pros:**

- Non-intrusive
- Visible to human operator
- Works with any CLI

**Cons:**

- No way to communicate to agent
- Purely informational

### 5.4 Proposal D: Integrated UI Status Bar

**Approach:** Display token status in Nancy's terminal output alongside the streaming response.

**Implementation:** Enhance `_claude_format_stream` in `src/cli/drivers/claude.sh` to periodically output token status.

**Pros:**

- Human operator visibility
- No agent overhead

**Cons:**

- Requires terminal integration
- Still no way to communicate to agent automatically

### 5.5 Proposal E: Skill Improvement + Hook Hybrid

**Approach:** Keep the skill for on-demand checking but add a lightweight PreToolUse hook that only runs every N tool calls.

```bash
# hooks/periodic-token-check.sh
COUNTER_FILE="/tmp/nancy-token-check-counter-$$"
COUNT=$(($(cat "$COUNTER_FILE" 2>/dev/null || echo 0) + 1))
echo "$COUNT" > "$COUNTER_FILE"

# Only check every 10 tool calls
if [[ $((COUNT % 10)) -ne 0 ]]; then
    echo '{"hookSpecificOutput":{"permissionDecision":"allow"}}'
    exit 0
fi

# Run actual check...
```

**Pros:**

- Reduced overhead
- Automatic but not overwhelming
- Skill still available for immediate check

**Cons:**

- Counter management complexity
- May miss critical moments

---

## 6. Recommended Approach

### Primary Recommendation: Proposal A (Hook-Based) + E (Periodic)

**Implementation Strategy:**

1. **Deploy a PreToolUse hook** that checks tokens every 5-10 tool calls
2. **Only inject additionalContext** when threshold crossed (WRAP_UP or END_TURN)
3. **Keep the skill** for explicit on-demand checking
4. **Fix the threshold bug** - use `NANCY_TOKEN_THRESHOLD` in recommendation logic
5. **Add human visibility** - log token status to Nancy's terminal output

### Configuration

```json
// .nancy/config.json
{
  "token_threshold": 0.4,
  "token_check_interval": 5,
  "token_warning_enabled": true
}
```

### Hook Design Principles

1. **Minimal overhead** - Only run full check every N tool calls
2. **Non-blocking** - Always allow tool to proceed
3. **Contextual warnings** - Only add context when actionable
4. **Graceful degradation** - Work without hooks for older CLI versions

### Migration Path

| Phase | Action                                                 |
| ----- | ------------------------------------------------------ |
| 1     | Fix threshold bug in current script                    |
| 2     | Deploy PreToolUse hook with periodic checking          |
| 3     | Enhance terminal output with token status              |
| 4     | Add configuration options for thresholds and intervals |
| 5     | Document hook deployment in Nancy setup process        |

---

## 7. Implementation Checklist

### Immediate Fixes

- [ ] Fix `check-tokens.sh` to use `NANCY_TOKEN_THRESHOLD` in recommendation logic
- [ ] Add fallback for missing `bc` command (use pure bash arithmetic)
- [ ] Simplify session file discovery (too many fallbacks)

### Hook Implementation

- [ ] Create `/hooks/check-tokens-hook.sh`
- [ ] Create hook configuration for PreToolUse
- [ ] Add hook deployment to `nancy setup`
- [ ] Version-gate hooks (require Claude Code 2.1.9+)

### Configuration

- [ ] Add `token_check_interval` config option
- [ ] Add `token_warning_enabled` config option
- [ ] Document all token-related configuration

### Testing

- [ ] Test hook with various token levels
- [ ] Test fallback behavior without hooks
- [ ] Test with auto-compact interaction
- [ ] Measure hook latency impact

---

## 8. Open Questions

1. **Auto-compact interaction**: How should Nancy handle Claude Code's auto-compact? Should we track compaction events?

2. **Extended thinking**: Claude's extended thinking tokens are handled specially. Do we need to account for this?

3. **Multi-agent scenarios**: If Nancy supports multiple workers, should each have independent token tracking?

4. **Cost tracking**: Should token checking also estimate/report API costs?

---

## Sources

### Primary Sources

- [Context Windows - Claude Docs](https://platform.claude.com/docs/en/build-with-claude/context-windows)
- [Managing Context - Anthropic](https://www.anthropic.com/news/context-management)
- [Hooks Reference - Claude Code](https://code.claude.com/docs/en/hooks)
- [Claude Code Best Practices](https://www.anthropic.com/engineering/claude-code-best-practices)

### Claude Code Issues & Features

- [Issue #15345 - additionalContext in PreToolUse](https://github.com/anthropics/claude-code/issues/15345)
- [Issue #14281 - Hook additionalContext duplication](https://github.com/anthropics/claude-code/issues/14281)
- [Issue #18264 - autoCompact threshold issues](https://github.com/anthropics/claude-code/issues/18264)

### Industry Practices

- [Aider Documentation](https://aider.chat/docs/config/options.html)
- [Developer Toolkit - Context Windows](https://developertoolkit.ai/en/shared-workflows/context-management/context-windows/)
- [Session Handoffs Pattern](https://dev.to/dorothyjb/session-handoffs-giving-your-ai-assistant-memory-that-actually-persists-je9)

### Nancy Codebase

- `/skills/check-tokens/SKILL.md`
- `/skills/check-tokens/check-tokens.sh`
- `/docs/ARCHITECTURE-CLI-INTEGRATION.md`
- `/templates/PROMPT.md.template`
- `/.planning/phases/3.1-skills-deep-dive/3.1-RESEARCH.md`

---

_Research completed: 2026-01-21_
