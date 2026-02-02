#!/usr/bin/env bash
# b_path:: src/notify/inject.sh
# Prompt injection for CLI agents
# ------------------------------------------------------------------------------
#
# IMPORTANT: This module contains CLI-specific injection strategies.
# Currently only Claude Code is supported. Other CLIs may require different
# approaches or may not support injection at all.
#
# Functions:
#   notify::inject_prompt <pane> <message>  - Inject prompt into CLI session
#   notify::can_inject                      - Check if injection is available
#
# ------------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

# Supported CLI types for injection
# Add new CLIs here as they're tested
NOTIFY_SUPPORTED_CLIS=("claude-code")

# Default CLI type (can be overridden in config)
NOTIFY_CLI_TYPE="${NANCY_CLI_TYPE:-claude-code}"

# -----------------------------------------------------------------------------
# notify::can_inject - Check if prompt injection is available
# Returns 0 if injection is supported, 1 otherwise
# -----------------------------------------------------------------------------
notify::can_inject() {
	# Must be in tmux
	[[ -z "${TMUX:-}" ]] && return 1

	# Must have a supported CLI type configured
	local cli
	for cli in "${NOTIFY_SUPPORTED_CLIS[@]}"; do
		[[ "$NOTIFY_CLI_TYPE" == "$cli" ]] && return 0
	done

	return 1
}

# -----------------------------------------------------------------------------
# notify::inject_prompt - Inject a prompt into a CLI session
# Args: pane_target, message
#
# CLAUDE CODE SPECIFIC:
# - Sends Escape first to cancel any partial input
# - Sends the message followed by Enter
# - Fire-and-forget: buffers until CLI is ready for input
#
# Other CLIs may need different strategies (PRs welcome)
# -----------------------------------------------------------------------------
notify::inject_prompt() {
	local pane="$1"
	local message="$2"

	[[ -z "$pane" || -z "$message" ]] && return 1
	notify::can_inject || return 1

	case "$NOTIFY_CLI_TYPE" in
	claude-code)
		tmux send-keys -t "$pane" -l "$message" 2>/dev/null
		tmux send-keys -t "$pane" Enter 2>/dev/null
		;;
	*)
		# Unknown CLI - don't attempt injection
		return 1
		;;
	esac
}

# -----------------------------------------------------------------------------
# notify::inject_worker_check - Inject command to check worker messages
# Args: pane_target
# For orchestrator pane - checks messages FROM worker
# -----------------------------------------------------------------------------
notify::inject_worker_check() {
	local pane="$1"
	notify::inject_prompt "$pane" "nancy messages"
}

# -----------------------------------------------------------------------------
# notify::inject_directive_check - Inject command to check directives
# Args: pane_target
# For worker pane - checks directives FROM orchestrator
# -----------------------------------------------------------------------------
notify::inject_directive_check() {
	local pane="$1"
	notify::inject_prompt "$pane" "nancy inbox"
}
