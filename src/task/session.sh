#!/usr/bin/env bash
# b_path:: src/task/session.sh
# Session management
# ------------------------------------------------------------------------------

# Generate session ID for a task iteration
session::id() {
	local task="$1"
	local iteration="${2:-1}"
	echo "nancy-${task}-iter${iteration}"
}

# Initialize session for a task
session::init() {
	local task="$1"
	local iteration="${2:-1}"
	local NANCY_TASK_DIR="${NANCY_TASK_DIR}/${task}"

	local session_id
	session_id=$(session::id "$task" "$iteration")

	cli::init_session "$session_id" "$task" "$NANCY_TASK_DIR"
}

# Get session file path
# session::file() {
# 	local task="$1"
# 	local iteration="${2:-1}"
# 	local NANCY_TASK_DIR="${NANCY_TASK_DIR}/${task}"

# 	local session_id
# 	session_id=$(session::id "$task" "$iteration")

# 	cli::session_file "$session_id" "$NANCY_TASK_DIR"
# }
