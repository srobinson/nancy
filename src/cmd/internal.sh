#!/usr/bin/env bash
# b_path:: src/cmd/internal.sh
# Internal commands for orchestration panes
# These are called by orchestrate.sh in tmux panes
# ------------------------------------------------------------------------------

# Worker pane - runs autonomous task loop
cmd::_worker() {
	local task="$1"

	if [[ -z "$task" ]]; then
		log::error "Usage: nancy _worker <task>"
		return 1
	fi

	# Just delegate to start
	cmd::start "$task"
}

# Orchestrator pane - interactive CLI with orchestrator context
cmd::_orchestrator() {
	local task="$1"

	if [[ -z "$task" ]]; then
		log::error "Usage: nancy _orchestrator <task>"
		return 1
	fi

	if ! task::exists "$task"; then
		log::error "Task '$task' not found"
		return 1
	fi

	# Set task dir for subprocesses (e.g., nancy messages called by Claude)
	export NANCY_CURRENT_TASK_DIR="${NANCY_CURRENT_TASK_DIR:-${NANCY_TASK_DIR}/${task}}"

	# Load task config
	config::load_task "$task"

	# Header
	ui::header "🎛️ Orchestrator - $task"
	echo ""
	ui::muted "Commands:"
	ui::muted "  nancy direct $task \"message\"  - Send directive to worker"
	echo ""

	# Load orchestrator skill as prompt
	local orchestrator_prompt="$NANCY_FRAMEWORK_ROOT/templates/orchestrator.md"
	local main_repo_dir=$(git rev-parse --show-toplevel)
	local main_repo_name=$(basename "$main_repo_dir")
	local parent_dir=$(dirname "$main_repo_dir")
	local worktree_dir="${parent_dir}/${main_repo_name}-worktrees/nancy-${task}"

	local prompt
	if [[ -f "$orchestrator_prompt" ]]; then
		# Load template and substitute variables
		prompt=$(cat "$orchestrator_prompt")
		prompt="${prompt//\{\{NANCY_CURRENT_TASK_DIR\}\}/$NANCY_CURRENT_TASK_DIR}"
		prompt="${prompt//\{\{TASK_NAME\}\}/$task}"
		prompt="${prompt//\{\{PROJECT_ROOT\}\}/$NANCY_PROJECT_ROOT}"
		prompt="${prompt//\{\{WORKTREE_DIR\}\}/$worktree_dir}"
		prompt="${prompt//\{\{MAIN_REPO_DIR\}\}/$main_repo_dir}"
	else
		prompt="You are orchestrating Nancy task: $task. Use 'nancy direct $task \"message\"' to send directives to the worker."
	fi

	# Start interactive CLI
	cli::run_interactive "$prompt"
}

# Sidebar navigation - persistent menu with mouse support
cmd::_sidebar() {
	local task="$1"
	local win="nancy-${task}"

	# Get pane base index (user may have set to 1)
	local pane_base
	pane_base=$(tmux show-window-option -gv pane-base-index 2>/dev/null || echo "0")
	local main_pane="$win.$((pane_base + 1))"

	if [[ -z "$task" ]]; then
		log::error "Usage: nancy _sidebar <task>"
		return 1
	fi

	# Menu options
	local options="Worker
Orchestrator
Inbox"

	ui::header "Navigation"
	echo ""

	# Loop forever - sidebar is persistent
	while true; do
		# Show menu with fzf (mouse enabled)
		local selected
		selected=$(echo "$options" | fzf --no-info --reverse --pointer="▶" \
			--header="Click to switch view" \
			--color="pointer:green,current-bg:-1")

		# If fzf exits without selection (Ctrl-C), wait and retry
		if [[ -z "$selected" ]]; then
			sleep 0.5
			continue
		fi

		# Kill current process in main pane and start selected view
		tmux send-keys -t "$main_pane" C-c 2>/dev/null || true
		sleep 0.3

		case "$selected" in
		"Worker")
			tmux select-pane -t "$main_pane" -T "⚙️ Worker: ${task}"
			tmux send-keys -t "$main_pane" "cd '$NANCY_PROJECT_ROOT' && '$NANCY_FRAMEWORK_ROOT/nancy' _worker '$task'; echo '[Press Enter to exit]'; read" C-m
			;;
		"Orchestrator")
			tmux select-pane -t "$main_pane" -T "🎛️ Orchestrator"
			tmux send-keys -t "$main_pane" "cd '$NANCY_PROJECT_ROOT' && '$NANCY_FRAMEWORK_ROOT/nancy' _orchestrator '$task'; echo '[Press Enter to exit]'; read" C-m
			;;
		"Inbox")
			tmux select-pane -t "$main_pane" -T "📬 Inbox"
			tmux send-keys -t "$main_pane" "cd '$NANCY_PROJECT_ROOT' && '$NANCY_FRAMEWORK_ROOT/nancy' _logs '$task'; echo '[Press Enter to exit]'; read" C-m
			;;
		esac

		# Focus main pane after selection
		tmux select-pane -t "$main_pane"
	done
}

# Inbox pane - watch for bidirectional messages
cmd::_logs() {
	local task="$1"

	if [[ -z "$task" ]]; then
		log::error "Usage: nancy _logs <task>"
		return 1
	fi

	if ! task::exists "$task"; then
		log::error "Task '$task' not found"
		return 1
	fi

	# Set task dir for subprocesses
	export NANCY_CURRENT_TASK_DIR="${NANCY_CURRENT_TASK_DIR:-${NANCY_TASK_DIR}/${task}}"

	ui::header "📬 Inbox - $task"
	echo ""

	# Check fswatch availability
	if ! notify::check_fswatch; then
		ui::error "Cannot start message relay without fswatch"
		ui::muted "Install with: brew install fswatch"
		return 1
	fi

	config::load_task "$task"
	local inbox_dir="$NANCY_TASK_DIR/$task/comms/orchestrator/inbox"

	# Ensure inbox exists
	mkdir -p "$inbox_dir"

	ui::success "Watching for messages..."
	ui::muted "Inbox: $inbox_dir"
	echo "---"

	# Start watching (blocking)
	notify::watch_inbox "$task"
}
