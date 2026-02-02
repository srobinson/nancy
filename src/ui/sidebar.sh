#!/usr/bin/env bash
# b_path:: src/ui/sidebar.sh
# Sidebar navigation for orchestration layout
# Blocks on gum choose - no busy polling
# ------------------------------------------------------------------------------

set -euo pipefail

# Get window name from argument or env
WIN="${1:-${NANCY_WIN:-}}"
if [[ -z "$WIN" ]]; then
	WIN=$(tmux display-message -p '#{window_name}')
fi

# Pane IDs (set by orchestrate.sh via env)
PANE_WORKER="${NANCY_PANE_WORKER:-1}"
PANE_ORCHESTRATOR="${NANCY_PANE_ORCHESTRATOR:-2}"
PANE_MESSAGES="${NANCY_PANE_MESSAGES:-3}"

# State file for unread indicator
TASK_DIR="${NANCY_TASK_DIR:-/tmp}"
UNREAD_FILE="$TASK_DIR/.unread"

# Track current selection
CURRENT="Worker"

# ------------------------------------------------------------------------------
# Get unread indicator
# ------------------------------------------------------------------------------
get_unread() {
	if [[ -f "$UNREAD_FILE" ]] && [[ "$(cat "$UNREAD_FILE" 2>/dev/null)" == "1" ]]; then
		echo " ●"
	else
		echo ""
	fi
}

# ------------------------------------------------------------------------------
# Clear unread state
# ------------------------------------------------------------------------------
clear_unread() {
	rm -f "$UNREAD_FILE" 2>/dev/null || true
}

# ------------------------------------------------------------------------------
# Switch to pane - expand target, collapse others (vertical)
# ------------------------------------------------------------------------------
switch_to_pane() {
	local target="$1"

	# Collapse all to 2 rows first
	tmux resize-pane -t "$WIN.$PANE_WORKER" -y 2 2>/dev/null || true
	tmux resize-pane -t "$WIN.$PANE_ORCHESTRATOR" -y 2 2>/dev/null || true
	tmux resize-pane -t "$WIN.$PANE_MESSAGES" -y 2 2>/dev/null || true

	# Expand the selected pane
	case "$target" in
	Worker)
		tmux resize-pane -t "$WIN.$PANE_WORKER" -y 90% 2>/dev/null || true
		tmux select-pane -t "$WIN.$PANE_WORKER"
		;;
	Orchestrator)
		tmux resize-pane -t "$WIN.$PANE_ORCHESTRATOR" -y 90% 2>/dev/null || true
		tmux select-pane -t "$WIN.$PANE_ORCHESTRATOR"
		;;
	Messages*)
		tmux resize-pane -t "$WIN.$PANE_MESSAGES" -y 90% 2>/dev/null || true
		tmux select-pane -t "$WIN.$PANE_MESSAGES"
		clear_unread
		;;
	esac

	CURRENT="${target%% *}" # Strip any suffix like " ●"
}

# ------------------------------------------------------------------------------
# Main loop
# ------------------------------------------------------------------------------
main() {
	# Initial display
	echo "━━━━━━━━━━━━━━"
	echo "  Navigation"
	echo "━━━━━━━━━━━━━━"
	echo ""

	while true; do
		local unread
		unread=$(get_unread)

		# Build menu with selection indicator
		local w_mark=" " o_mark=" " m_mark=" "
		[[ "$CURRENT" == "Worker" ]] && w_mark="▶"
		[[ "$CURRENT" == "Orchestrator" ]] && o_mark="▶"
		[[ "$CURRENT" == "Messages" ]] && m_mark="▶"

		# gum choose blocks here (no CPU usage while waiting)
		choice=$(printf '%s\n' \
			"${w_mark} Worker" \
			"${o_mark} Orchestrator" \
			"${m_mark} Messages${unread}" |
			gum choose --height 5 --cursor "" --selected="${CURRENT}")

		# Strip markers
		choice="${choice#▶ }"
		choice="${choice#  }"
		choice="${choice%% ●}" # Remove unread indicator if present

		# Switch pane
		if [[ -n "$choice" ]]; then
			switch_to_pane "$choice"
		fi

		# Redraw
		clear
		echo "━━━━━━━━━━━━━━"
		echo "  Navigation"
		echo "━━━━━━━━━━━━━━"
		echo ""
	done
}

main "$@"
