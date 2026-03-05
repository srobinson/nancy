#!/usr/bin/env bash
# b_path:: src/cmd/pause.sh
# Pause a running worker by creating a lock file and sending a bus message
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

	local content
	content=$(cat <<EOF
Nancy control message
Task: ${task}
Type: guidance
Priority: normal

End turn cleanly. The task is paused. Finish your current checkpoint and stop after this session.
EOF
)

	local to_agent
	to_agent=""
	if bus::available; then
		to_agent=$(bus::resolve_task_worker_agent "$task")
	fi
	if [[ -n "$to_agent" ]]; then
		if ! bus::send_message "$to_agent" "$content" "nancy:operator:${task}" "*" "nancy-${task}" "1" >/dev/null; then
			rm -f "$lock_file"
			log::error "Failed to send pause message over helioy-bus"
			return 1
		fi

		ui::success "⏸️  Task '$task' paused"
		ui::muted "Lock file: $lock_file"
		ui::muted "Message sent to: $to_agent"
		echo ""
		ui::muted "Worker will complete current turn and pause."
		ui::muted "Use 'nancy unpause $task' to resume."
		return 0
	fi

	local pane
	pane=$(bus::inject_task_worker "$task" "End turn cleanly. The task is paused. Finish your current checkpoint and stop after this session.")
	if [[ -n "$pane" ]]; then
		log::warn "Worker not registered on helioy-bus; injected pause message directly into pane ${pane}"
		ui::success "⏸️  Task '$task' paused"
		ui::muted "Lock file: $lock_file"
		ui::muted "Message injected into: $pane"
		echo ""
		ui::muted "Worker will complete current turn and pause."
		ui::muted "Use 'nancy unpause $task' to resume."
		return 0
	fi

	rm -f "$lock_file"
	log::error "No live worker agent or pane found for task '$task'"
	return 1
}
