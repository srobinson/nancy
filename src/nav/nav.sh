#!/usr/bin/env bash
# b_path:: src/nav/nav.sh
# Navigation module - tmux pane navigation with mouse support
# ------------------------------------------------------------------------------
#
# Provides navigation primitives for switching between panes in Nancy orchestration.
# Uses native tmux features (display-menu, resize-pane -Z) for reliability and
# mouse support.
#
# Key design decisions (from 4.1-RESEARCH.md):
#   - Use tmux display-menu for navigation (native mouse support, zero deps)
#   - Use resize-pane -Z for zoom toggle (proven pattern)
#   - Do NOT use gum choose (no mouse support)
#   - Do NOT use resize-pane to "collapse" panes (tmux enforces minimum sizes)
#
# IMPORTANT: display-menu is BLOCKING - it waits for user input.
# These functions require an interactive tmux session.
#
# ------------------------------------------------------------------------------

# nav::_require_tmux - Check if running inside tmux session
# Returns 0 if in tmux, exits with error if not
nav::_require_tmux() {
	if [[ -z "${TMUX:-}" ]]; then
		log::error "nav: not running inside tmux session"
		return 1
	fi
}

# nav::_require_interactive - Check if running interactively
# display-menu blocks forever waiting for input if not interactive
# Returns 0 if interactive, exits with error if not
nav::_require_interactive() {
	# Check if we have a controlling terminal
	# display-menu needs user input - will hang forever without TTY
	if [[ ! -t 0 ]]; then
		log::error "nav: display-menu requires interactive terminal (stdin is not a TTY)"
		return 1
	fi
}

# nav::show_menu - Show navigation menu with pane options
# Uses tmux display-menu for native mouse support
# Keyboard shortcuts: 1,2,3 for panes, z for zoom, q for cancel
#
# BLOCKING: This function waits for user to select an option.
# Requires interactive terminal - will error if stdin is not a TTY.
nav::show_menu() {
	nav::_require_tmux || return 1
	nav::_require_interactive || return 1

	# Position at center for visibility
	tmux display-menu -T "#[align=centre]Nancy Navigation" -x C -y C \
		"Worker"       1 "select-pane -t 0" \
		"Orchestrator" 2 "select-pane -t 1" \
		"Inbox/Logs"   3 "select-pane -t 2" \
		"" \
		"Zoom Current" z "resize-pane -Z" \
		"" \
		"Cancel"       q ""
}

# nav::zoom_pane - Toggle zoom on specified pane
# Args:
#   $1 - Optional pane target (defaults to current pane)
#
# NON-BLOCKING: Returns immediately after toggling zoom.
nav::zoom_pane() {
	nav::_require_tmux || return 1

	local target="${1:-}"

	if [[ -n "$target" ]]; then
		tmux resize-pane -t "$target" -Z
	else
		tmux resize-pane -Z
	fi

	# Show brief confirmation message
	if nav::is_zoomed; then
		tmux display-message -d 1500 "Zoomed"
	else
		tmux display-message -d 1500 "Restored layout"
	fi
}

# nav::is_zoomed - Check if window is currently zoomed
# Returns:
#   0 if zoomed
#   1 if not zoomed
#
# NON-BLOCKING: Returns immediately with zoom state.
nav::is_zoomed() {
	nav::_require_tmux || return 1

	local zoomed
	zoomed=$(tmux display-message -p '#{window_zoomed_flag}')
	[[ "$zoomed" == "1" ]]
}
