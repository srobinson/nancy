#!/usr/bin/env bash
# b_path:: src/cmd/unpause.sh
# Unpause a paused worker by removing the lock file
# ------------------------------------------------------------------------------

cmd::unpause() {
	local task="$1"

	if [[ -z "$task" ]]; then
		log::error "Usage: nancy unpause <task>"
		return 1
	fi

	if ! task::exists "$task"; then
		log::error "Task '$task' does not exist"
		return 1
	fi

	local task_dir="${NANCY_TASK_DIR}/${task}"
	local lock_file="${task_dir}/PAUSE"

	# Check if paused
	if [[ ! -f "$lock_file" ]]; then
		log::warn "Task '$task' is not currently paused"
		return 0
	fi

	# Remove lock file
	rm -f "$lock_file"

	ui::success "▶️  Task '$task' unpaused"
	ui::muted "Worker will resume on next iteration"
}
