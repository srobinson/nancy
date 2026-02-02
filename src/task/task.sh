#!/usr/bin/env bash
# b_path:: src/task/task.sh
# Task CRUD operations
# ------------------------------------------------------------------------------

# List all tasks
task::list() {
	if [[ -d "$NANCY_TASK_DIR" ]]; then
		find "$NANCY_TASK_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | sort
	fi
}

# Count tasks
task::count() {
	task::list | wc -l | tr -d ' '
}

# Check if a task exists
task::exists() {
	local task="$1"
	[[ -d "${NANCY_TASK_DIR}/${task}" ]]
}

# Validate task name
task::validate_name() {
	local name="$1"

	if [[ -z "$name" ]]; then
		log::error "Task name required"
		return 1
	fi

	if [[ ! "$name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]]; then
		log::error "Invalid task name. Use letters, numbers, hyphens, underscores."
		return 1
	fi

	if [[ ${#name} -gt 64 ]]; then
		log::error "Task name too long (max 64 chars)"
		return 1
	fi

	return 0
}

# Create task directory structure
task::create() {
	local task="$1"
	local task_dir="${NANCY_TASK_DIR}/${task}"

	mkdir -p "${task_dir}/sessions"
	mkdir -p "${task_dir}/outputs"
	mkdir -p "${task_dir}/comms/directives"
	mkdir -p "${task_dir}/comms/acks"
	mkdir -p "${task_dir}/comms/archive"

	# Render PROMPT.md from template
	local template="$NANCY_FRAMEWORK_ROOT/templates/PROMPT.md.template"
	if [[ -f "$template" ]]; then
		sed -e "s|{{TASK_NAME}}|$task|g" "$template" >"${task_dir}/PROMPT.md"
	else
		touch "${task_dir}/PROMPT.md"
	fi

	log::debug "Created task directory: $task_dir"
}

# Check if task is complete
task::is_complete() {
	local task="$1"
	[[ -f "${NANCY_TASK_DIR}/${task}/COMPLETE" ]]
}

# Mark task complete
task::mark_complete() {
	local task="$1"
	echo "Completed: $(date -u +"%Y-%m-%dT%H:%M:%SZ")" >"${NANCY_TASK_DIR}/${task}/COMPLETE"
}

# Count sessions for a task
task::count_sessions() {
	local task="$1"
	local sessions_dir="${NANCY_TASK_DIR}/${task}/sessions"

	if [[ -d "$sessions_dir" ]]; then
		find "$sessions_dir" -type f -name "*.md" 2>/dev/null | wc -l | tr -d ' '
	else
		echo "0"
	fi
}

# Get latest session file
task::latest_session() {
	local task="$1"
	local sessions_dir="${NANCY_TASK_DIR}/${task}/sessions"

	if [[ -d "$sessions_dir" ]]; then
		# shellcheck disable=SC2012
		ls -t "$sessions_dir"/*.md 2>/dev/null | head -1
	fi
}
