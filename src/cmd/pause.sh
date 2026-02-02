#!/usr/bin/env bash
# b_path:: src/cmd/pause.sh
# Pause a running worker by creating a lock file and sending directive
# ------------------------------------------------------------------------------

cmd::pause() {
	local task="$1"

	if [[ -z "$task" ]]; then
		log::error "Usage: nancy pause <task>"
		return 1
	fi

	if ! task::exists "$task"; then
		log::error "Task '$task' does not exist"
		return 1
	fi

	local task_dir="${NANCY_TASK_DIR}/${task}"
	local lock_file="${task_dir}/PAUSE"

	# Check if already paused
	if [[ -f "$lock_file" ]]; then
		log::warn "Task '$task' is already paused"
		return 0
	fi

	# Create lock file
	echo "Paused at $(date -u +"%Y-%m-%dT%H:%M:%SZ")" > "$lock_file"

	# Send directive to worker to end turn cleanly
	local filename
	filename=$(comms::orchestrator_send "$task" "guidance" "End turn cleanly. Loop paused by orchestrator." "normal")

	if [[ -n "$filename" ]]; then
		ui::success "⏸️  Task '$task' paused"
		ui::muted "Lock file: $lock_file"
		ui::muted "Directive sent: $filename"
		echo ""
		ui::muted "Worker will complete current turn and pause."
		ui::muted "Use 'nancy unpause $task' to resume."
	else
		# Remove lock file if directive failed
		rm -f "$lock_file"
		log::error "Failed to send pause directive"
		return 1
	fi
}
