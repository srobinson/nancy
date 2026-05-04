#!/usr/bin/env bash
# b_path:: src/cmd/stop.sh
# Stop a running worker by killing Claude and writing a STOP sentinel
# ------------------------------------------------------------------------------

cmd::stop() {
	local task="$1"

	if [[ -z "$task" ]]; then
		log::error "Usage: nancy stop <task>"
		return 1
	fi

	if ! task::exists "$task"; then
		log::error "Task '$task' does not exist"
		return 1
	fi

	local task_dir="${NANCY_TASK_DIR}/${task}"
	local pid_file="${task_dir}/.worker_pid"
	local pause_file="${task_dir}/PAUSE"
	local stop_file="${task_dir}/STOP"

	sidecar::stop "$task" 2>/dev/null || true

	# Kill Claude subprocess if running
	if [[ -f "$pid_file" ]]; then
		local worker_pid
		worker_pid=$(cat "$pid_file")
		if [[ -n "$worker_pid" ]] && kill -0 "$worker_pid" 2>/dev/null; then
			kill "$worker_pid" 2>/dev/null || true
			sleep 1
			kill -0 "$worker_pid" 2>/dev/null && kill -9 "$worker_pid" 2>/dev/null || true
			ui::success "Killed worker process ($worker_pid)"
		else
			ui::muted "Worker process ($worker_pid) already exited"
		fi
		rm -f "$pid_file"
	else
		ui::muted "No worker PID file found — worker may not be running"
	fi

	# Write STOP sentinel so the loop exits after pipeline returns
	echo "Stopped at $(date -u +"%Y-%m-%dT%H:%M:%SZ")" > "$stop_file"
	rm -f "$pause_file"

	# Stop watchers
	notify::stop_all_watchers "$task" 2>/dev/null || true

	ui::success "⏹  Task '$task' stopped"
	ui::muted "Sentinel: $stop_file"
}
