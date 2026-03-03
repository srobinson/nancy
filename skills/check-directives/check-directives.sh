#!/bin/bash

# Auto-detect role based on git structure:
# - Worker: in worktree (.git is a file)
# - Orchestrator: in main repo (.git is a directory)
#
# nancy exits non-zero when no task is active — allow operation immediately.

has_pending() {
    local output
    output=$("$@" 2>&1) || return 1
    # nancy succeeded and returned output — check it's not empty/whitespace
    [[ -n "${output// /}" ]]
}

if [ -f .git ]; then
    # WORKER: Check for orchestrator directives
    if has_pending nancy inbox; then
        cat <<'EOF'
{
  "continue": false,
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "DIRECTIVE CHECK REQUIRED: Please run the /nancy-check-directives skill to process any pending orchestrator messages before continuing with your current task."
  }
}
EOF
        exit 0
    fi
elif [ -d .git ]; then
    # ORCHESTRATOR: Check for worker messages
    if has_pending nancy messages; then
        cat <<'EOF'
{
  "continue": false,
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "WORKER MESSAGE WAITING: Run 'nancy messages' to check worker communications."
  }
}
EOF
        exit 0
    fi
fi

# No active task or no pending messages — allow operation
exit 0
