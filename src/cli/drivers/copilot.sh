#!/bin/bash
# b_path:: src/cli/drivers/copilot.sh
# GitHub Copilot CLI driver for Nancy
# ------------------------------------------------------------------------------

COPILOT_CMD="copilot"

# Get session directory for task
# Copilot with XDG_STATE_HOME creates $XDG_STATE_HOME/.copilot/session-state/
_copilot_session_dir() {
	local NANCY_TASK_DIR="$1"
	echo "${NANCY_TASK_DIR}/.copilot/session-state"
}

# Check if Copilot CLI is available
cli::copilot::detect() {
	command -v "$COPILOT_CMD" &>/dev/null
}

# Get Copilot version
cli::copilot::version() {
	"$COPILOT_CMD" --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1
}

# Run Copilot in interactive mode
cli::copilot::run_interactive() {
	local prompt="${1:-}"
	local args=("--allow-all-tools" "--allow-all-paths")

	if [[ -n "$prompt" ]]; then
		args+=("-i" "$prompt")
	fi

	"$COPILOT_CMD" "${args[@]}"
}

# Run Copilot with a prompt file
cli::copilot::run_prompt() {
	local prompt_text="$1"
	local session_id="$2"
	local export_file="$3"
	local NANCY_TASK_DIR="$4"
	local model="${NANCY_MODEL:-}"

	local args=("--allow-all-tools" "--allow-all-paths" "--resume" "$session_id" "--share" "$export_file")

	if [[ -n "$model" ]]; then
		args+=("--model" "$model")
	fi

	# Set XDG_STATE_HOME for task-local session files
	XDG_STATE_HOME="$NANCY_TASK_DIR" "$COPILOT_CMD" "${args[@]}" <<<"$prompt_text"
}

# Get session state directory
cli::copilot::session_dir() {
	local NANCY_TASK_DIR="$1"
	if [[ -n "$NANCY_TASK_DIR" ]]; then
		# Task-local sessions
		_copilot_session_dir "$NANCY_TASK_DIR"
	else
		# Global sessions
		echo "$HOME/.copilot/session-state"
	fi
}

# Get path to session file
# cli::copilot::session_file() {
# 	local session_id="$1"
# 	local NANCY_TASK_DIR="$2"
# 	local session_dir
# 	session_dir=$(cli::copilot::session_dir "$NANCY_TASK_DIR")
# 	echo "${session_dir}/${session_id}.jsonl"
# }

# Initialize a session file for resume to work
cli::copilot::init_session() {
	local session_id="$1"
	local task="$2"
	local NANCY_TASK_DIR="$3"
	local session_dir session_file

	session_dir=$(_copilot_session_dir "$NANCY_TASK_DIR")
	session_file="${session_dir}/${session_id}.jsonl"

	mkdir -p "$session_dir"

	local session_uuid msg_uuid timestamp
	session_uuid=$(uuidgen | tr '[:upper:]' '[:lower:]')
	msg_uuid=$(uuidgen | tr '[:upper:]' '[:lower:]')
	timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

	cat >"$session_file" <<EOF
{"type":"session.start","data":{"sessionId":"${session_id}","version":1,"producer":"copilot-agent","copilotVersion":"0.0.377","startTime":"${timestamp}"},"id":"${session_uuid}","timestamp":"${timestamp}","parentId":null}
{"type":"user.message","data":{"content":"Nancy task: ${task}","transformedContent":"<current_datetime>${timestamp}</current_datetime>\n\nNancy autonomous loop for task: ${task}","attachments":[]},"id":"${msg_uuid}","timestamp":"${timestamp}","parentId":"${session_uuid}"}
EOF

	log::debug "Created Copilot session file: $session_file"
}

# Check if Copilot supports session resume
cli::copilot::supports_resume() {
	return 0
}

# Check if Copilot supports session export
cli::copilot::supports_export() {
	return 0
}

# Get auto-approve flags
cli::copilot::auto_approve_flag() {
	echo "--allow-all-tools --allow-all-paths"
}

# Get model flag
cli::copilot::get_model_flag() {
	local model="$1"
	echo "--model $model"
}

# Get name of this CLI
cli::copilot::name() {
	echo "copilot"
}
