# Session History Feature Research

**Date:** 2026-01-21
**Feature:** session-history skill
**Status:** Research Complete

---

## Executive Summary

The `session-history` skill provides CLI-level access to Claude Code session JSONL files, allowing users to search past work, continue from previous sessions, and debug what happened. However, it is **passive** (must be explicitly invoked) and **read-only** (cannot auto-inject context at session start). This research identifies key limitations and proposes improvements leveraging Claude Code's native hooks and the `--continue`/`--resume` flags.

---

## Current Implementation

### Location

```
skills/session-history/
  SKILL.md     # 2,221 chars - skill definition with commands reference
  session.sh   # 194 lines - bash helper for session operations
```

### Core Components

**SKILL.md** - Loaded when Claude detects session-related intent:

- Description triggers: "continue from previous session", "what did we do", "search sessions"
- Commands reference table
- Data location documentation
- Example usage patterns

**session.sh** - Standalone bash script:

```bash
# Key commands
session.sh status      # Overview: current + previous session summaries
session.sh list        # All sessions with first prompt and summaries
session.sh tail [n]    # Last N messages from current session
session.sh prompts     # All user prompts from session (intent trail)
session.sh summaries   # Auto-generated summaries
session.sh grep <term> # Search across all project sessions
session.sh files       # Files touched (from tool calls)
```

### Data Sources

**Adhoc sessions** (user runs `claude` directly):

```
~/.claude/projects/<encoded-cwd>/
  <uuid>.jsonl  <- each session
```

**Nancy worker sessions** (orchestrated via `nancy start`):

```
.nancy/tasks/<task>/session-state/
  nancy-<task>-iter<N>.jsonl  <- copied from ~/.claude/projects/
.nancy/tasks/<task>/sessions/
  session_<timestamp>_iter<N>.md  <- exported summary
```

### JSONL Format (Claude Code Native)

```json
{"type": "user", "uuid": "...", "message": {"content": "..."}}
{"type": "assistant", "uuid": "...", "message": {"content": [...], "model": "..."}}
{"type": "summary", "summary": "Auto-generated after N turns"}
{"type": "file-history-snapshot", ...}
```

### Integration Points

1. **Skills/check-tokens** - Can query session to estimate context usage
2. **src/task/session.sh** - Generates session IDs for Nancy tasks
3. **src/cli/drivers/claude.sh** - Copies session JSONL to task directory, exports summaries
4. **templates/PROMPT.md.template** - Worker prompt with `{{SESSION_ID}}` placeholder

---

## How It Works

### Skill Trigger Flow

1. User asks: "What did we do last session?"
2. Claude Code matches semantic intent to skill description
3. SKILL.md body is loaded into context
4. Claude executes bash commands from session.sh
5. Results displayed to user

### Session Storage Flow (Nancy Worker)

```
nancy start <task>
    |
    +-> session::init() generates session ID: nancy-<task>-iter<N>
    |
    +-> cli::run_prompt() with --session-id <uuid>
    |
    +-> Claude writes to ~/.claude/projects/<encoded>/<uuid>.jsonl
    |
    +-> _copy_project_session() copies JSONL to task dir
    |
    +-> cli::export_session() creates markdown summary
```

### Environment Variables

- `HW_SESSION_DIR` - Override for worker agents (HumanWork/Nancy)
- `HW_SESSION_ID` - Explicit session ID for workers
- `NANCY_SESSION_ID` - Exported for skills

---

## Drawbacks and Limitations

### 1. Passive Invocation Required

**Problem:** User must explicitly invoke the skill. Context is not automatically loaded at session start.

**Impact:** New sessions start "cold" without previous context. Users often forget to check history.

**Example:**

```
# User starts new claude session
claude
# Claude has no idea what happened yesterday
# User must manually type: "What did we do last session?"
```

### 2. No Auto-Resume Capability

**Problem:** Nancy creates new session UUIDs each iteration. The `--continue` flag could preserve context, but Nancy doesn't use it.

**Impact:** Each Nancy iteration starts fresh, losing accumulated context from previous turns.

**Current behavior:**

```bash
# src/cli/drivers/claude.sh line 137
uuid=$(uuid::generate)  # Always new UUID
args+=("--session-id" "$uuid")
```

**Could be:**

```bash
# Continue from previous iteration
args+=("--continue")
```

### 3. jq Dependency Without Fallback

**Problem:** session.sh requires `jq` for JSONL parsing. No fallback for systems without it.

**Impact:** Silent failures or cryptic errors on systems missing jq.

### 4. Cross-Platform stat Compatibility

**Problem:** Uses BSD `stat` syntax with GNU fallback, but can fail silently.

```bash
# Current approach - fragile
mtime=$(stat -f '%m' "$file" 2>/dev/null || stat -c '%Y' "$file" 2>/dev/null)
```

### 5. Large Session Files

**Problem:** Session JSONL files can grow very large (89k+ tokens observed). Reading/parsing them is slow.

**Example from testing:**

```
.nancy/tasks/testing-session-history/session-state/nancy-testing-session-history-iter1.jsonl
- 89,139 tokens
- Too large to read in one pass
```

### 6. No Semantic Search

**Problem:** `session_grep` does simple text matching. Cannot search by intent or concept.

**Example:** Searching for "authentication" won't find sessions where you worked on "login" or "OAuth".

### 7. Summary Quality Varies

**Problem:** Auto-generated summaries (`type: "summary"`) depend on Claude's internal summarization, which can miss important details.

### 8. No Inter-Session Linking

**Problem:** Sessions are isolated. No way to link related sessions or create a "project history" view.

### 9. HW_SESSION_DIR Confusion

**Problem:** Environment variable naming (`HW_` prefix) is legacy from HumanWork. Confusing for Nancy users.

### 10. Skill Triggering Unreliable

**Problem:** As documented in `.planning/phases/3.1-skills-deep-dive/3.1-RESEARCH.md`, skills don't always trigger reliably.

**Current description:**

```yaml
description: Access session history to continue work, see what happened, or search past sessions. Use this instead of relying on memory - the raw data is always more accurate.
```

---

## Research Findings

### Claude Code Native Capabilities

**Session Resume Flags** ([Claude Code Docs](https://code.claude.com/docs/en/common-workflows)):

- `claude --continue` - Resume most recent conversation in current directory
- `claude --resume` - Interactive session picker
- `claude --resume <id>` - Resume specific session by ID
- In-session `/resume` command to switch conversations

**Session Storage:**

- All conversations saved to `~/.claude/projects/<encoded-cwd>/<uuid>.jsonl`
- History searchable via `/history` command
- Ctrl+R for fuzzy search in active session

**Hooks System** ([Hooks Reference](https://code.claude.com/docs/en/hooks)):

- `SessionStart` hook fires on session startup/resume
- Can inject `additionalContext` via JSON output:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "Previous session summary..."
  }
}
```

- Known bugs: SessionStart hooks may not fire consistently for new sessions ([Issue #10373](https://github.com/anthropics/claude-code/issues/10373))

**Limitations:**

- `--resume` fails to restore context after hitting usage limits ([Issue #3138](https://github.com/anthropics/claude-code/issues/3138))
- SessionStart hook additionalContext doesn't persist to transcript ([Issue #11906](https://github.com/anthropics/claude-code/issues/11906))

### Other AI CLI Tools

**Codex CLI** ([OpenAI Codex Docs](https://developers.openai.com/codex/cli/)):

- `codex resume` - Interactive picker of recent sessions
- `codex resume --last` - Jump to most recent
- `codex resume --all` - Show sessions across all directories
- `/compact` command - Summarize conversation to save tokens
- `codex.md` file - Auto-loaded project context (like CLAUDE.md)

**Cursor** ([Context Management](https://stevekinney.com/courses/ai-development/cursor-context)):

- `@Past Chats` reference for continuity
- `.cursor/rules` for persistent project context
- Automatic truncation/summarization of old messages

**Common Patterns:**

1. **Auto-loading context files** (codex.md, CLAUDE.md, .cursor/rules)
2. **Session compaction** (`/compact`) to preserve context within token limits
3. **Resume commands** with interactive pickers
4. **Fuzzy search** across session history

### Best Practices from Community

**Kent Gigger's Approach** ([Blog Post](https://kentgigger.com/posts/claude-code-conversation-history)):

- Custom `/history` command in `~/.claude/commands/`
- Search by content, find session ID, resume with `--resume`
- Descriptive session naming via `/rename`

**Session Management Course** ([Steve Kinney](https://stevekinney.com/courses/ai-development/claude-code-session-management)):

- Use `--continue` for quick resumption
- Name sessions early with `/rename`
- Use `/clear` between distinct tasks
- `/compact` for long sessions approaching limits

**LaunchDarkly Integration** ([GitHub](https://github.com/launchdarkly-labs/claude-code-session-start-hook)):

- SessionStart hook loads dynamic instructions
- Feature-flagged context injection
- Repository-aware configuration

---

## Improvement Proposals

### Proposal 1: SessionStart Hook for Auto-Context

**Goal:** Automatically inject previous session summary at session start.

**Implementation:**

```
.claude/hooks/
  hooks.json
  session-start.sh  # or session-start.py
```

**hooks.json:**

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "./session-start.sh"
          }
        ]
      }
    ]
  }
}
```

**session-start.sh:**

```bash
#!/bin/bash
# Get previous session summary
SH=~/.claude/skills/session-history/session.sh
prev_summary=$($SH summaries $($SH previous) 2>/dev/null | head -500)

if [[ -n "$prev_summary" ]]; then
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "## Previous Session Context\n\n$prev_summary"
  }
}
EOF
fi
```

**Pros:**

- Automatic context injection
- No user action required
- Works for adhoc sessions

**Cons:**

- SessionStart hooks have known bugs
- May not work consistently

### Proposal 2: --continue Flag for Nancy Iterations

**Goal:** Use Claude's native `--continue` to preserve context across iterations.

**Change in src/cli/drivers/claude.sh:**

```bash
cli::claude::run_prompt() {
    local prompt_text="$1"
    local nancy_session_id="$2"
    # ...

    local args=("--dangerously-skip-permissions")

    # Check if we should continue from previous iteration
    if [[ "${NANCY_CONTINUE_SESSION:-}" == "true" ]]; then
        args+=("--continue")
    else
        local uuid=$(uuid::generate)
        args+=("--session-id" "$uuid")
    fi
    # ...
}
```

**Add to config.json:**

```json
{
  "continue_sessions": true
}
```

**Pros:**

- Leverages Claude's native session continuity
- Full context preservation
- No manual intervention

**Cons:**

- May hit context limits faster
- Could accumulate stale context

### Proposal 3: /history Custom Command

**Goal:** Make session history searchable via slash command.

**Location:** `.claude/commands/history.md`

````markdown
---
name: history
description: Search and browse session history for this project
---

# Session History Browser

Search your past sessions and resume from any point.

## Commands

```bash
SH=~/.claude/skills/session-history/session.sh

# Quick status
$SH status

# List all sessions
$SH list

# Search for term
$SH grep "$ARGUMENTS"
```
````

## Resume Instructions

To resume a session, exit and run:

```bash
claude --resume <session-id>
```

```

**Pros:**
- Discoverable via `/history`
- Consistent with Claude Code patterns
- Can be invoked mid-conversation

**Cons:**
- Still requires explicit invocation

### Proposal 4: Hybrid Skill + Hook Approach

**Goal:** Combine automatic context loading with manual search capability.

**Components:**

1. **SessionStart hook** - Auto-loads previous session summary (light context)
2. **session-history skill** - Deep search when needed (detailed context)
3. **/history command** - Quick access to search/browse

**Flow:**
```

Session Start
|
+-> Hook injects: "Previous session: Fixed auth bug, touched 3 files"
|
User works...
|
User: "What files did we change yesterday?"
|
+-> Skill loads, runs: session.sh files $(session.sh previous)
|
+-> Shows detailed file list

````

**Pros:**
- Best of both worlds
- Graceful degradation if hook fails
- User can always go deeper

**Cons:**
- More complex setup
- Multiple components to maintain

### Proposal 5: Enhanced session.sh with Fallbacks

**Goal:** Make session.sh more robust.

**Improvements:**

1. **jq fallback using grep/sed:**
```bash
session_prompts() {
    if command -v jq &>/dev/null; then
        # jq approach
    else
        # grep/sed fallback
        grep '"type":"user"' "$file" | sed 's/.*"content":"\([^"]*\)".*/\1/'
    fi
}
````

1. **Semantic search via embeddings** (future):

```bash
session_search() {
    # Use local embedding model to find semantically similar sessions
    # Would require additional setup
}
```

1. **Session compaction:**

```bash
session_compact() {
    # Summarize old messages, keep recent ones
    # Write compacted JSONL for faster loading
}
```

### Proposal 6: Project-Level Session Index

**Goal:** Create a searchable index of all sessions.

**Structure:**

```
.nancy/session-index.json
{
  "sessions": [
    {
      "id": "nancy-auth-iter1",
      "date": "2026-01-20",
      "summary": "Implemented JWT auth",
      "files": ["src/auth.ts", "tests/auth.test.ts"],
      "keywords": ["authentication", "JWT", "tokens"]
    }
  ]
}
```

**Benefits:**

- Fast searching without parsing large JSONL files
- Keywords for semantic matching
- Cross-session linking

---

## Recommended Approach

### Phase 1: Quick Wins (Low Effort, High Impact)

1. **Add /history command** - Simple, discoverable, follows patterns
2. **Enable --continue for Nancy** - Configuration flag, easy to implement
3. **Improve skill description** - Better trigger phrases

### Phase 2: Auto-Context (Medium Effort)

1. **Implement SessionStart hook** - Accept known bugs, provide value when it works
2. **Add jq fallback** - Improve reliability

### Phase 3: Deep Integration (High Effort)

1. **Session index** - For large projects with many sessions
2. **Semantic search** - Future enhancement when tooling matures

### Implementation Priority

| Priority | Proposal          | Effort | Impact |
| -------- | ----------------- | ------ | ------ |
| 1        | /history command  | Low    | High   |
| 2        | --continue flag   | Low    | High   |
| 3        | SessionStart hook | Medium | Medium |
| 4        | jq fallback       | Low    | Low    |
| 5        | Session index     | High   | Medium |

---

## Sources

### Primary Documentation

- [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks)
- [Claude Code Common Workflows](https://code.claude.com/docs/en/common-workflows)
- [OpenAI Codex CLI](https://developers.openai.com/codex/cli/)

### Community Resources

- [Kent Gigger - Claude Code's Hidden Conversation History](https://kentgigger.com/posts/claude-code-conversation-history)
- [Steve Kinney - Claude Code Session Management](https://stevekinney.com/courses/ai-development/claude-code-session-management)
- [Mehmet Baykar - Resume Claude Code Sessions](https://mehmetbaykar.com/posts/resume-claude-code-sessions-after-restart/)
- [Nick Porter - Teaching Claude to Remember (Part 3)](https://medium.com/@porter.nicholas/teaching-claude-to-remember-part-3-sessions-and-resumable-workflow-1c356d9e442f)

### GitHub Issues & Feature Requests

- [Session Resumption Feature Request #1340](https://github.com/anthropics/claude-code/issues/1340)
- [SessionStart Hooks Bug #10373](https://github.com/anthropics/claude-code/issues/10373)
- [Resume Flag Context Loss Bug #3138](https://github.com/anthropics/claude-code/issues/3138)
- [SessionStart additionalContext Bug #11906](https://github.com/anthropics/claude-code/issues/11906)
- [Native Session Persistence Request #18417](https://github.com/anthropics/claude-code/issues/18417)

### Related Tools

- [LaunchDarkly Session Start Hook](https://github.com/launchdarkly-labs/claude-code-session-start-hook)
- [Claude Code History Viewer](https://github.com/jhlee0409/claude-code-history-viewer)
- [Cursor Context Management](https://github.com/BuildSomethingAI/Cursor-Context-Management)

---

## Appendix: Code Snippets

### Current Skill Description (SKILL.md)

```yaml
name: session-history
description: Access session history to continue work, see what happened, or search past sessions. Use this instead of relying on memory - the raw data is always more accurate.
```

### Proposed Improved Description

```yaml
name: session-history
description: Access CLI session history for continuing work, searching past conversations, or debugging what happened. Triggers on: continue from last session, what did we do, search sessions, session history, previous work, yesterday's session. Use instead of memory - raw data is more accurate.
```

### Sample SessionStart Hook Output

```json
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "## Previous Session Context\n\nLast session (2026-01-20):\n- Fixed authentication bug in src/auth.ts\n- Added JWT token validation\n- Tests passing\n\nFiles modified: src/auth.ts, tests/auth.test.ts"
  }
}
```

---

_Research completed: 2026-01-21_
_Ready for implementation: Yes_
