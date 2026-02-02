# Nancy CLI Agent Integration Architecture

## Design Proposal

**Version:** 1.0
**Date:** 2026-01-20
**Status:** Draft

---

## Executive Summary

This document proposes a formal architecture for integrating Nancy with multiple CLI agents (Claude Code, GitHub Copilot, and future CLIs). The design centers on a driver-based abstraction layer, a deployment mechanism for hooks/skills, and a hook-based communication system that replaces unreliable tmux injection.

---

## 1. Current State Analysis

### Existing Driver Architecture

Nancy already has a partial driver architecture at `/src/cli/drivers/`:

```
src/cli/
├── dispatch.sh          # CLI dispatcher - routes to appropriate driver
├── index.sh             # Module loader
└── drivers/
    ├── index.sh         # Loads all drivers
    ├── claude.sh        # Claude Code driver
    └── copilot.sh       # GitHub Copilot driver
```

**Current Driver Interface** (implicit):

- `cli::<name>::detect()` - Check if CLI is available
- `cli::<name>::version()` - Get CLI version
- `cli::<name>::name()` - Get CLI name
- `cli::<name>::run_interactive()` - Run CLI interactively
- `cli::<name>::run_prompt()` - Run CLI with prompt
- `cli::<name>::session_dir()` - Get session directory
- `cli::<name>::session_file()` - Get session file path
- `cli::<name>::init_session()` - Initialize session
- `cli::<name>::supports_resume()` - Resume capability flag
- `cli::<name>::supports_export()` - Export capability flag

### Scattered CLI-Specific Code

CLI-specific code is scattered across several locations:

1. **`/src/notify/inject.sh`** - tmux injection with `NOTIFY_CLI_TYPE` switch
2. **`/src/notify/watcher.sh`** - fswatch-based inbox watching with CLI-specific injection calls
3. **Skills deployed to `~/.claude/skills/`** - Claude Code specific location
4. **Session handling differs** - Claude uses UUIDs, Copilot uses names

### Current Communication Mechanism

Nancy currently uses tmux send-keys injection:

```bash
# From inject.sh - current approach
notify::inject_prompt() {
    tmux send-keys -t "$pane" Escape 2>/dev/null
    sleep 0.6
    tmux send-keys -t "$pane" -l "$message" 2>/dev/null
    tmux send-keys -t "$pane" Enter 2>/dev/null
}
```

**Problems:**

1. Unreliable mid-execution - agent may be in the middle of processing
2. CLI-specific escape sequences needed
3. Timing-dependent (sleep delays)
4. No confirmation that message was received
5. Can corrupt agent state if injected at wrong time
6. ESC character gets echoed as `^[` rather than processed as interrupt

---

## 2. Proposed Architecture

### 2.1 Directory Structure

```
/src/cli/
├── index.sh                    # Module exports
├── dispatch.sh                 # CLI selection and routing
├── interfaces/
│   └── driver.sh               # Driver contract definition (documented interface)
└── drivers/
    ├── base/
    │   ├── index.sh            # Shared utilities
    │   ├── session.sh          # Common session handling
    │   └── hooks.sh            # Hook deployment base
    ├── claude-code/
    │   ├── index.sh            # Driver entry point
    │   ├── driver.sh           # Core driver implementation
    │   ├── hooks/
    │   │   ├── pretool-inbox.sh       # PreToolUse inbox check hook
    │   │   └── pretool-inbox.json     # Hook configuration template
    │   ├── skills/
    │   │   ├── check-directives/
    │   │   │   └── SKILL.md
    │   │   └── send-message/
    │   │       └── SKILL.md
    │   ├── settings.sh         # Settings.json deployment
    │   └── deploy.sh           # Deployment orchestration
    ├── copilot/
    │   ├── index.sh
    │   ├── driver.sh
    │   ├── hooks/              # (Future - if Copilot supports hooks)
    │   ├── skills/             # Copilot-specific skill format
    │   └── deploy.sh
    └── registry.sh             # Driver discovery and loading
```

### 2.2 Driver Interface Contract

Each driver MUST implement these functions. Document in `/src/cli/interfaces/driver.sh`:

```bash
# =============================================================================
# NANCY CLI DRIVER INTERFACE CONTRACT
# =============================================================================
# All drivers must implement these functions with the naming convention:
#   cli::<driver-name>::<function-name>
#
# Example for Claude Code: cli::claude::detect, cli::claude::deploy_hooks, etc.
# =============================================================================

# -----------------------------------------------------------------------------
# CORE DETECTION (Required)
# -----------------------------------------------------------------------------

# cli::<name>::detect
#   Returns: 0 if CLI is installed and available, 1 otherwise
#   Example: command -v claude &>/dev/null

# cli::<name>::version
#   Returns: Semantic version string (e.g., "2.1.9")
#   Stdout: Version string

# cli::<name>::name
#   Returns: Canonical driver name
#   Stdout: Driver name (e.g., "claude", "copilot")

# cli::<name>::min_version
#   Returns: Minimum required version for Nancy features
#   Stdout: Version string (e.g., "2.1.9" for additionalContext support)

# -----------------------------------------------------------------------------
# SESSION MANAGEMENT (Required)
# -----------------------------------------------------------------------------

# cli::<name>::session_dir <task_dir>
#   Returns: Path to session storage directory
#   Args: task_dir - Nancy task directory

# cli::<name>::session_file <session_id> <task_dir>
#   Returns: Path to specific session file
#   Args: session_id, task_dir

# cli::<name>::init_session <session_id> <task_name> <task_dir>
#   Initializes a new session (creates mapping files, etc.)

# -----------------------------------------------------------------------------
# EXECUTION (Required)
# -----------------------------------------------------------------------------

# cli::<name>::run_interactive <system_prompt>
#   Starts CLI in interactive mode with optional system prompt

# cli::<name>::run_prompt <prompt_text> <session_id> <export_file> <task_dir>
#   Runs CLI with prompt in non-interactive/autonomous mode

# cli::<name>::auto_approve_flag
#   Returns: CLI flag for auto-approving tool calls
#   Stdout: Flag string (e.g., "--dangerously-skip-permissions")

# cli::<name>::get_model_flag <model>
#   Returns: CLI flag for specifying model
#   Args: model - Model identifier

# -----------------------------------------------------------------------------
# DEPLOYMENT (Required for hook-based communication)
# -----------------------------------------------------------------------------

# cli::<name>::deploy_hooks <task_dir>
#   Deploys all hooks for Nancy communication
#   Returns: 0 on success, 1 on failure

# cli::<name>::deploy_skills <task_dir>
#   Deploys Nancy skills to appropriate location
#   Returns: 0 on success, 1 on failure

# cli::<name>::deploy_settings <task_dir>
#   Deploys/updates CLI settings for Nancy integration
#   Returns: 0 on success, 1 on failure

# cli::<name>::deploy <task_dir>
#   Full deployment (hooks + skills + settings)
#   Returns: 0 on success, 1 on failure

# cli::<name>::cleanup <task_dir>
#   Removes deployed hooks/settings for this task
#   Returns: 0 on success, 1 on failure

# -----------------------------------------------------------------------------
# CAPABILITY FLAGS (Required)
# -----------------------------------------------------------------------------

# cli::<name>::supports_resume
#   Returns: 0 if CLI supports session resume, 1 otherwise

# cli::<name>::supports_export
#   Returns: 0 if CLI supports session export, 1 otherwise

# cli::<name>::supports_hooks
#   Returns: 0 if CLI supports PreToolUse hooks with additionalContext

# cli::<name>::supports_skills
#   Returns: 0 if CLI has a skills/slash-commands system

# -----------------------------------------------------------------------------
# COMMUNICATION (Required if supports_hooks returns 0)
# -----------------------------------------------------------------------------

# cli::<name>::get_inbox_path <task_dir>
#   Returns: Path that hooks should check for directives
#   For Claude Code: <task_dir>/comms/worker/inbox

# cli::<name>::get_hook_output_format
#   Returns: Expected JSON structure for hook additionalContext
#   Stdout: JSON template string
```

### 2.3 Hook Architecture

#### Claude Code PreToolUse Hook for Inbox Checking

When the orchestrator sends a directive, instead of tmux injection, a PreToolUse hook checks the worker's inbox before each tool call and returns `additionalContext` if a directive is found.

**Hook Configuration Template**:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "${NANCY_FRAMEWORK_ROOT}/src/cli/drivers/claude-code/hooks/pretool-inbox.sh"
          }
        ]
      }
    ]
  }
}
```

**Hook Script** (`pretool-inbox.sh`):

```bash
#!/usr/bin/env bash
# PreToolUse hook that checks worker inbox before each tool call
# Returns additionalContext with directive if found

set -euo pipefail

# Read hook input from stdin
INPUT=$(cat)

# Get task directory from environment
TASK_DIR="${NANCY_CURRENT_TASK_DIR:-}"
if [[ -z "$TASK_DIR" ]]; then
    # Allow tool to proceed without context
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
    exit 0
fi

INBOX_DIR="$TASK_DIR/comms/worker/inbox"

# Check if inbox has any messages
if [[ ! -d "$INBOX_DIR" ]]; then
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
    exit 0
fi

# Find most recent directive
DIRECTIVE=$(find "$INBOX_DIR" -name "*.md" -type f 2>/dev/null | sort | head -1)

if [[ -z "$DIRECTIVE" ]]; then
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
    exit 0
fi

# Read directive content
FILENAME=$(basename "$DIRECTIVE")
CONTENT=$(cat "$DIRECTIVE")

# Extract message type and priority from markdown
MSG_TYPE=$(grep -m1 '^\*\*Type:\*\*' "$DIRECTIVE" 2>/dev/null | sed 's/.*\*\*Type:\*\*[[:space:]]*//' || echo "directive")
MSG_PRIORITY=$(grep -m1 '^\*\*Priority:\*\*' "$DIRECTIVE" 2>/dev/null | sed 's/.*\*\*Priority:\*\*[[:space:]]*//' || echo "normal")

# Build context message
CONTEXT="
=== ORCHESTRATOR DIRECTIVE ===
Type: ${MSG_TYPE}
Priority: ${MSG_PRIORITY}
File: ${FILENAME}

${CONTENT}

=== ACTION REQUIRED ===
1. Process this directive immediately
2. Archive after acting: nancy archive ${FILENAME}
================================
"

# Escape for JSON
ESCAPED_CONTEXT=$(echo "$CONTEXT" | jq -Rs .)

# Return hook output with additionalContext
cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "additionalContext": ${ESCAPED_CONTEXT}
  }
}
EOF
```

**Key Benefits:**

1. **Reliable delivery** - Context injected before EVERY tool call
2. **No timing issues** - Hook runs synchronously before tool execution
3. **Agent sees directive** - additionalContext is visible to Claude
4. **No tmux dependency** - Works regardless of terminal setup
5. **Version-gated** - Only enabled for Claude Code 2.1.9+

### 2.4 Deployment Flow

#### `nancy setup` (Project Initialization)

```bash
cmd::setup() {
    # ... existing setup ...

    # Detect CLI and deploy integration
    cli::detect || {
        log::warn "No supported CLI detected - deployment skipped"
        return 0
    }

    # Deploy global hooks/skills for this CLI
    cli::deploy_global
}
```

#### `nancy orchestrate <task>` (Orchestration Start)

```bash
cmd::orchestrate() {
    local task="$1"
    # ... validation ...

    # Deploy task-specific hooks
    cli::deploy "$NANCY_TASK_DIR/$task"

    # ... tmux layout setup ...
}
```

#### Deployment Implementation for Claude Code

```bash
#!/usr/bin/env bash
# Claude Code deployment

CLAUDE_CONFIG_DIR="${HOME}/.claude"
CLAUDE_SETTINGS_LOCAL="${PWD}/.claude/settings.local.json"

# Deploy hooks to project-local settings
cli::claude::deploy_hooks() {
    local task_dir="$1"
    local settings_dir="${PWD}/.claude"
    local settings_file="${settings_dir}/settings.local.json"

    mkdir -p "$settings_dir"

    # Read existing settings or create new
    local existing="{}"
    [[ -f "$settings_file" ]] && existing=$(cat "$settings_file")

    # Get hook command path
    local hook_cmd="${NANCY_FRAMEWORK_ROOT}/src/cli/drivers/claude-code/hooks/pretool-inbox.sh"

    # Merge in Nancy hooks
    local updated
    updated=$(echo "$existing" | jq --arg cmd "$hook_cmd" '
        .hooks.PreToolUse = [
            {
                "matcher": "*",
                "hooks": [
                    {
                        "type": "command",
                        "command": $cmd
                    }
                ]
            }
        ] + (.hooks.PreToolUse // [])
    ')

    echo "$updated" > "$settings_file"
    log::success "Deployed PreToolUse hooks to $settings_file"
}

# Deploy skills to global location
cli::claude::deploy_skills() {
    local task_dir="$1"
    local skills_src="${NANCY_FRAMEWORK_ROOT}/skills"
    local skills_dst="${CLAUDE_CONFIG_DIR}/skills"

    # Skills to deploy
    local skills=("check-directives" "send-message" "check-tokens" "session-history")

    for skill in "${skills[@]}"; do
        local src_dir="${skills_src}/${skill}"
        local dst_dir="${skills_dst}/${skill}"

        if [[ -d "$src_dir" ]]; then
            mkdir -p "$dst_dir"
            cp -r "${src_dir}/"* "$dst_dir/"
            log::debug "Deployed skill: $skill"
        fi
    done

    log::success "Deployed ${#skills[@]} skills to $skills_dst"
}

# Full deployment
cli::claude::deploy() {
    local task_dir="$1"

    log::info "Deploying Claude Code integration..."

    # Check version supports hooks
    local version
    version=$(cli::claude::version)
    if ! _version_gte "$version" "2.1.9"; then
        log::warn "Claude Code $version detected. Version 2.1.9+ required for hook-based communication."
        log::warn "Falling back to tmux injection (less reliable)."
        return 0
    fi

    cli::claude::deploy_hooks "$task_dir"
    cli::claude::deploy_skills "$task_dir"

    log::success "Claude Code integration deployed"
}

# Cleanup deployed artifacts
cli::claude::cleanup() {
    local task_dir="$1"
    local settings_file="${PWD}/.claude/settings.local.json"

    if [[ -f "$settings_file" ]]; then
        # Remove Nancy hooks from settings
        local updated
        updated=$(cat "$settings_file" | jq '
            .hooks.PreToolUse = [
                .hooks.PreToolUse[]? |
                select(.hooks[0].command | contains("nancy") | not)
            ]
        ')
        echo "$updated" > "$settings_file"
        log::info "Removed Nancy hooks from $settings_file"
    fi
}
```

### 2.5 Skills Architecture

Skills live in the Nancy framework but are deployed to CLI-specific locations.

**Nancy Framework Structure:**

```
/skills/
├── README.md                # Documentation and character budget
├── check-directives/
│   └── SKILL.md            # Markdown with YAML frontmatter
├── send-message/
│   └── SKILL.md
├── check-tokens/
│   ├── SKILL.md
│   └── check-tokens.sh     # Associated script
├── session-history/
│   ├── SKILL.md
│   └── session.sh
├── orchestrator/
│   └── SKILL.md
├── create-spec/
│   └── SKILL.md
└── update-spec/
    └── SKILL.md
```

**Deployment Targets:**

- **Claude Code**: `~/.claude/skills/<skill-name>/`
- **Copilot**: (TBD - depends on Copilot skill mechanism)

### 2.6 Configuration Management

**Deployed Config Locations:**

| CLI         | Hooks                         | Skills              | Settings                      |
| ----------- | ----------------------------- | ------------------- | ----------------------------- |
| Claude Code | `.claude/settings.local.json` | `~/.claude/skills/` | `.claude/settings.local.json` |
| Copilot     | (TBD)                         | (TBD)               | (TBD)                         |

**Nancy Config (`/.nancy/config.json`):**

```json
{
  "version": "2.0",
  "cli": "claude",
  "model": "opus",
  "token_threshold": 0.5,
  "deployment": {
    "hooks_deployed": true,
    "hooks_version": "1.0.0",
    "skills_deployed": true,
    "skills_version": "1.0.0",
    "deployed_at": "2026-01-20T00:00:00Z"
  }
}
```

### 2.7 Versioning and Updates

**Hook Versioning:**

- Hook scripts include version header: `# NANCY_HOOK_VERSION: 1.0.0`
- Deployment checks if deployed version matches framework version
- Automatic re-deploy on version mismatch

**Skills Versioning:**

- SKILL.md files include metadata: `# nancy-version: 1.0.0`
- Skills updated on `nancy setup` or `nancy update`

**Rollback/Cleanup:**

- `nancy cleanup` removes all deployed hooks/settings
- `nancy stop` calls cleanup for task-specific deployments
- Preserves user's existing settings (only removes Nancy additions)

---

## 3. Migration Path

### Phase 1: Consolidate Existing Drivers

1. Move CLI-specific code from `src/notify/inject.sh` into respective drivers
2. Create `src/cli/interfaces/driver.sh` documenting required interface
3. Update existing `claude.sh` and `copilot.sh` to match full interface

### Phase 2: Implement Hook System (Claude Code)

1. Create `/src/cli/drivers/claude-code/hooks/pretool-inbox.sh`
2. Create `/src/cli/drivers/claude-code/deploy.sh`
3. Add `cli::claude::deploy_hooks()` function
4. Update `cmd::orchestrate` to call deployment

### Phase 3: Skills Deployment

1. Move skills from `/skills/` to driver-specific structure
2. Create `cli::claude::deploy_skills()` function
3. Update skills to reflect hook-based communication

### Phase 4: Remove tmux Injection (Optional)

1. Keep tmux injection as fallback for older CLI versions
2. Deprecate `notify::inject_*` functions
3. Log warning when falling back to injection

### Migration Checklist

- [ ] Create `/src/cli/interfaces/driver.sh`
- [ ] Create `/src/cli/drivers/base/` shared utilities
- [ ] Create `/src/cli/drivers/claude-code/` directory structure
- [ ] Implement `pretool-inbox.sh` hook
- [ ] Implement `deploy.sh` for Claude Code
- [ ] Update dispatch.sh to call deployment
- [ ] Update skills for hook-based messaging
- [ ] Add version checking for hook support
- [ ] Implement cleanup functions
- [ ] Update PROMPT.md.template for hook-based directives
- [ ] Test full orchestration flow with hooks
- [ ] Document migration for existing Nancy users

---

## 4. Sequence Diagrams

### Orchestrator to Worker Communication (Hook-Based)

```
┌────────────┐     ┌────────────┐     ┌─────────────┐     ┌────────┐
│Orchestrator│     │  Filesystem │     │PreToolUse   │     │ Claude │
│   (Human)  │     │(worker inbox)│    │    Hook     │     │ Worker │
└─────┬──────┘     └──────┬──────┘     └──────┬──────┘     └───┬────┘
      │                   │                   │                │
      │ nancy direct "msg"│                   │                │
      │──────────────────>│                   │                │
      │                   │ write directive.md│                │
      │                   │                   │                │
      │                   │                   │   [Any tool]   │
      │                   │                   │<───────────────│
      │                   │   read inbox      │                │
      │                   │<──────────────────│                │
      │                   │   directive found │                │
      │                   │──────────────────>│                │
      │                   │                   │ additionalContext
      │                   │                   │───────────────>│
      │                   │                   │                │ Process
      │                   │                   │                │ directive
      │                   │                   │                │
      │                   │                   │   [tool runs]  │
      │                   │                   │<───────────────│
      │                   │                   │                │
      │                   │  nancy archive    │                │
      │                   │<─────────────────────────────────────
      │                   │  delete directive │                │
```

### Deployment Flow

```
┌──────┐     ┌────────────┐     ┌─────────────┐     ┌──────────────┐
│ User │     │   nancy    │     │ CLI Driver  │     │ Claude Code  │
│      │     │            │     │ (claude.sh) │     │   Config     │
└──┬───┘     └──────┬─────┘     └──────┬──────┘     └──────┬───────┘
   │                │                  │                   │
   │ nancy setup    │                  │                   │
   │───────────────>│                  │                   │
   │                │ cli::detect()    │                   │
   │                │─────────────────>│                   │
   │                │     "claude"     │                   │
   │                │<─────────────────│                   │
   │                │ cli::deploy()    │                   │
   │                │─────────────────>│                   │
   │                │                  │ check version     │
   │                │                  │──────────────────>│
   │                │                  │    "2.1.10"       │
   │                │                  │<──────────────────│
   │                │                  │ deploy_hooks()    │
   │                │                  │──────────────────>│
   │                │                  │ write settings    │
   │                │                  │──────────────────>│
   │                │                  │ deploy_skills()   │
   │                │                  │──────────────────>│
   │                │                  │ copy to ~/.claude │
   │                │    deployed      │                   │
   │                │<─────────────────│                   │
   │    success     │                  │                   │
   │<───────────────│                  │                   │
```

---

## 5. Testing Strategy

### Unit Tests

1. **Driver detection** - Verify each driver correctly detects CLI availability
2. **Version parsing** - Ensure version comparison works correctly
3. **Hook output format** - Validate JSON output matches Claude Code schema
4. **Settings merging** - Verify hooks are added without clobbering existing settings

### Integration Tests

1. **Full deployment** - `nancy setup` deploys all artifacts
2. **Orchestration with hooks** - Directive delivery via hooks works end-to-end
3. **Cleanup** - `nancy cleanup` removes all Nancy artifacts
4. **Fallback** - Older CLI versions fall back to tmux injection

### Manual Testing Checklist

- [ ] `nancy setup` on fresh project deploys hooks
- [ ] `nancy orchestrate <task>` shows directives in worker context
- [ ] Worker processes directive and archives it
- [ ] `nancy cleanup` removes all hooks/settings
- [ ] Existing user settings preserved after cleanup

---

## 6. Future Considerations

### GitHub Copilot Integration

When Copilot supports hooks:

1. Create `/src/cli/drivers/copilot/hooks/`
2. Implement Copilot-specific hook format
3. Deploy to Copilot's configuration location

### Additional Hook Points

- **SessionStart** - Inject Nancy context at session start
- **PostToolUse** - Track tool execution for analytics
- **Stop** - Capture completion state

### Multi-Worker Support

The hook architecture naturally supports multiple workers:

- Each worker has its own inbox: `comms/worker-<n>/inbox`
- Each worker's hooks check their specific inbox
- Orchestrator addresses messages to specific workers

---

## 7. Research Findings

### Why tmux Injection Doesn't Work

Through experimentation, we discovered:

1. **ESC doesn't interrupt mid-execution** - Claude Code only processes ESC when at the prompt, not during tool execution
2. **ESC echoes as `^[`** - When sent via `tmux send-keys Escape`, Claude Code sees it as literal text
3. **Ctrl+C kills the process** - Too aggressive, terminates the entire session
4. **No true interrupt mechanism** - Claude Code has no interrupt handler during tool execution

### PreToolUse + additionalContext Solution

Claude Code v2.1.9 added `additionalContext` support for PreToolUse hooks:

- **Issue #15345** - Feature request implemented Jan 2026
- **How it works**: Hook returns JSON with `additionalContext` field
- **Claude sees it**: Unlike `permissionDecisionReason`, this is visible to the model
- **Non-blocking**: Tool still executes (with `permissionDecision: "allow"`)

This enables reliable orchestrator → worker communication without tmux tricks.

---

## Sources

- [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks)
- [Issue #15345 - additionalContext in PreToolUse](https://github.com/anthropics/claude-code/issues/15345)
- [Issue #12623 - Non-blocking PreToolUse hooks](https://github.com/anthropics/claude-code/issues/12623)
- [Issue #6965 - Additional context injection](https://github.com/anthropics/claude-code/issues/6965)
- [tmux send-keys documentation](https://github.com/tmux/tmux/wiki/FAQ)
