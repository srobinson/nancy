#!/usr/bin/env bash
# b_path:: src/cmd/orchestrate.sh
# Enter orchestration mode - 3-pane tmux layout
# ------------------------------------------------------------------------------
#
# Layout:
# ┌─────────────────────┬─────────────────────┐
# │ Pane 0              │ Pane 1              │
# │ ORCHESTRATOR        │ WORKER              │
# │ (50% width)         │ (50% height)        │
# │                     ├─────────────────────┤
# │                     │ Pane 2              │
# │                     │ INBOX               │
# │                     │ (50% height)        │
# └─────────────────────┴─────────────────────┘
# ------------------------------------------------------------------------------

cmd::orchestrate() {
	local task="$1"

	# Must be inside tmux
	if [[ -z "${TMUX:-}" ]]; then
		log::error "Orchestration requires tmux. Run inside a tmux session."
		return 1
	fi

	# Task required
	if [[ -z "$task" ]]; then
		log::error "Usage: nancy orchestrate <task>"
		echo ""
		ui::muted "Available tasks:"
		task::list | sed 's/^/  - /'
		return 1
	fi

	# Validate task exists
	if ! task::exists "$task"; then
		log::error "Task '$task' not found"
		return 1
	fi

	# Load task config
	config::load_task "$task"

	local cwd="$NANCY_PROJECT_ROOT"
	local win="nancy-${task}"

	log::info "Starting orchestration for: $task"

	# Get pane base index (default is 0, but user may have set to 1)
	local pane_base
	pane_base=$(tmux show-window-option -gv pane-base-index 2>/dev/null || echo "0")
	local pane0=$((pane_base + 0))
	local pane1=$((pane_base + 1))
	local pane2=$((pane_base + 2))

	# Create new window
	tmux new-window -n "$win" -c "$cwd"

	# Enable pane titles for this window
	tmux set-window-option -t "$win" pane-border-status top
	tmux set-window-option -t "$win" pane-border-format " #{pane_title} "

	# Split horizontally - right pane (50% width)
	tmux split-window -h -t "$win" -c "$cwd" -p 50

	# Split right pane vertically - bottom right (50% of right side)
	tmux split-window -v -t "$win.$pane1" -c "$cwd" -p 50

	sleep 0.3

	# Set pane titles
	tmux select-pane -t "$win.$pane0" -T "🎛️ Orchestrator" 2>/dev/null || true
	tmux select-pane -t "$win.$pane1" -T "⚙️ Worker: ${task}" 2>/dev/null || true
	tmux select-pane -t "$win.$pane2" -T "📬 Inbox" 2>/dev/null || true

	sleep 0.2

	# Set task dir for all panes
	local task_dir="${NANCY_TASK_DIR}/${task}"

	# Start processes in each pane
	# Pane 0: Orchestrator (interactive CLI with orchestrator skill)
	tmux send-keys -t "$win.$pane0" "cd '$cwd' && NANCY_CURRENT_TASK_DIR='$task_dir' '$NANCY_FRAMEWORK_ROOT/nancy' _orchestrator '$task'; echo '[Press Enter to exit]'; read" C-m

	# Pane 1: Worker (autonomous loop)
	tmux send-keys -t "$win.$pane1" "cd '$cwd' && NANCY_CURRENT_TASK_DIR='$task_dir' '$NANCY_FRAMEWORK_ROOT/nancy' _worker '$task'; echo '[Press Enter to exit]'; read" C-m

	# Pane 2: Message relay (Inbox)
	tmux send-keys -t "$win.$pane2" "cd '$cwd' && NANCY_CURRENT_TASK_DIR='$task_dir' '$NANCY_FRAMEWORK_ROOT/nancy' _logs '$task'; echo '[Press Enter to exit]'; read" C-m

	# Focus orchestrator pane
	tmux select-pane -t "$win.$pane0"

	ui::success "Orchestration started"
}
