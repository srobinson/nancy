#!/usr/bin/env bash
# b_path:: src/comms/comms.sh
# Bidirectional file-based IPC for orchestrator-worker communication
# Supports inbox/outbox pattern for two-way messaging
# ------------------------------------------------------------------------------

# Valid message types per role
declare -a COMMS_WORKER_TYPES=("blocker" "progress" "review-request")
declare -a COMMS_ORCHESTRATOR_TYPES=("directive" "guidance" "stop")

# Get comms directory path
# Usage: comms::get_dir <task> <role> <box>
# role: orchestrator|worker
# box: inbox|outbox
comms::get_dir() {
	local task="$1"
	local role="$2"
	local box="$3"

	echo "$NANCY_TASK_DIR/$task/comms/$role/$box"
}

# Initialize comms directories for a task
# Usage: comms::init <task>
comms::init() {
	local task="$1"
	local base_dir="$NANCY_TASK_DIR/$task"

	mkdir -p "$base_dir/sessions"

	# Create inbox/outbox structure for both roles
	mkdir -p "$base_dir/comms/orchestrator/inbox"
	mkdir -p "$base_dir/comms/orchestrator/outbox"
	mkdir -p "$base_dir/comms/worker/inbox"
	mkdir -p "$base_dir/comms/worker/outbox"
	mkdir -p "$base_dir/comms/archive"

	log::debug "Initialized comms directories for task: $task"
}

# Check if a message type is valid for a role
# Usage: comms::_validate_type <role> <type>
comms::_validate_type() {
	local role="$1"
	local msg_type="$2"
	local valid_types

	if [[ "$role" == "worker" ]]; then
		valid_types=("${COMMS_WORKER_TYPES[@]}")
	elif [[ "$role" == "orchestrator" ]]; then
		valid_types=("${COMMS_ORCHESTRATOR_TYPES[@]}")
	else
		log::error "Invalid role: $role (must be 'worker' or 'orchestrator')"
		return 1
	fi

	for valid in "${valid_types[@]}"; do
		if [[ "$msg_type" == "$valid" ]]; then
			return 0
		fi
	done

	log::error "Invalid message type '$msg_type' for role '$role'. Valid types: ${valid_types[*]}"
	return 1
}

# Send a message from one role to another
# Usage: comms::send <task> <from> <to> <type> <message> [priority]
# from/to: orchestrator|worker
# type: depends on sender role (see COMMS_*_TYPES)
# priority: urgent|normal|low (default: normal)
comms::send() {
	local task="$1"
	local from="$2"
	local to="$3"
	local msg_type="$4"
	local message="$5"
	local priority="${6:-normal}"

	# Validate type for sender role
	if ! comms::_validate_type "$from" "$msg_type"; then
		return 1
	fi

	# Ensure comms directories exist
	comms::init "$task"

	# Get recipient's inbox directory
	local inbox_dir
	inbox_dir=$(comms::get_dir "$task" "$to" "inbox")

	# Generate timestamped filename
	local timestamp
	timestamp=$(date -u +"%Y%m%dT%H%M%SZ")

	# Get next sequence number to handle multiple messages in same second
	local seq=1
	while [[ -f "${inbox_dir}/${timestamp}-$(printf '%03d' $seq).md" ]]; do
		seq=$((seq + 1))
	done

	local filename="${timestamp}-$(printf '%03d' $seq).md"
	local filepath="${inbox_dir}/${filename}"

	# Write message in standard format
	cat >"$filepath" <<EOF
# Message

**Type:** ${msg_type}
**From:** ${from}
**Priority:** ${priority}
**Time:** $(date -u +"%Y-%m-%dT%H:%M:%SZ")

## Content

${message}
EOF

	log::debug "Message sent: $from -> $to ($msg_type): $filename"

	linear::issue:comment:add "$task" "Message sent: $from -> $to ($msg_type): $message" >/dev/null

	echo "$filename"
}

# Read pending messages from a role's inbox
# Usage: comms::read_inbox <task> <role>
# Returns list of message filenames (one per line)
comms::read_inbox() {
	local task="$1"
	local role="$2"

	local inbox_dir
	inbox_dir=$(comms::get_dir "$task" "$role" "inbox")

	[[ ! -d "$inbox_dir" ]] && return 0

	# List message files sorted by timestamp (filename order)
	find "$inbox_dir" -maxdepth 1 -name "*.md" -type f 2>/dev/null | sort
}

# Archive a processed message
# Usage: comms::archive <task> <role> <filename>
comms::archive() {
	local task="$1"
	local role="$2"
	local filename="$3"

	local inbox_dir
	inbox_dir=$(comms::get_dir "$task" "$role" "inbox")
	local archive_dir="$NANCY_TASK_DIR/$task/comms/archive"

	mkdir -p "$archive_dir"

	if [[ -f "${inbox_dir}/${filename}" ]]; then
		# Add archive timestamp prefix
		local archive_timestamp
		archive_timestamp=$(date -u +"%Y%m%dT%H%M%SZ")
		mv "${inbox_dir}/${filename}" "${archive_dir}/${archive_timestamp}-${filename}"
		log::debug "Archived message: $filename"
		return 0
	else
		log::warn "Message not found for archiving: ${inbox_dir}/${filename}"
		return 1
	fi
}

# Check if a role has pending messages
# Usage: comms::has_messages <task> <role>
# Returns: 0 if messages exist, 1 if empty
comms::has_messages() {
	local task="$1"
	local role="$2"

	local inbox_dir
	inbox_dir=$(comms::get_dir "$task" "$role" "inbox")

	[[ ! -d "$inbox_dir" ]] && return 1

	local count
	count=$(find "$inbox_dir" -maxdepth 1 -name "*.md" -type f 2>/dev/null | wc -l)

	[[ "$count" -gt 0 ]] && return 0 || return 1
}

# Convenience: Worker sends message to orchestrator
# Usage: comms::worker_send <task> <type> <message> [priority]
comms::worker_send() {
	local task="$1"
	local msg_type="$2"
	local message="$3"
	local priority="${4:-normal}"

	comms::send "$task" "worker" "orchestrator" "$msg_type" "$message" "$priority"
}

# Convenience: Orchestrator sends message to worker
# Usage: comms::orchestrator_send <task> <type> <message> [priority]
comms::orchestrator_send() {
	local task="$1"
	local msg_type="$2"
	local message="$3"
	local priority="${4:-normal}"

	comms::send "$task" "orchestrator" "worker" "$msg_type" "$message" "$priority"
}
