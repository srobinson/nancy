#!/bin/bash

# Auto-detect role based on git structure:
# - Worker: in worktree (.git is a file)
# - Orchestrator: in main repo (.git is a directory)

if [ -f .git ]; then
    # WORKER: Check for orchestrator directives
    nancy inbox | { ! grep -qi "no pending"; } && {
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
    }
elif [ -d .git ]; then
    # ORCHESTRATOR: Check for worker messages
    nancy messages | { ! grep -qi "no pending"; } && {
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
    }
fi

# No messages/directives found - allow operation
exit 0
