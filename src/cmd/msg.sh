#!/usr/bin/env bash
# b_path:: src/cmd/msg.sh
# Worker message command - simple interface for sending messages to orchestrator
# ------------------------------------------------------------------------------

cmd::msg() {
	local msg_type="$1"
	local message="$2"
	local priority="${3:-normal}"

	# Get task from environment or discover
	local task_dir="${NANCY_CURRENT_TASK_DIR:-}"

	if [[ -z "$task_dir" ]]; then
		# Try to discover from .nancy/tasks/
		if [[ -d ".nancy/tasks" ]]; then
			task_dir=$(find .nancy/tasks -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1)
		fi
	fi

	if [[ -z "$task_dir" ]]; then
		echo "ERROR: Cannot determine task directory" >&2
		return 1
	fi

	if [[ -z "$msg_type" || -z "$message" ]]; then
		echo "Usage: nancy msg <type> <message> [priority]"
		echo ""
		echo "Types: blocker, progress, review-request"
		echo "Priority: urgent, normal, low (default: normal)"
		return 1
	fi

	# Validate type
	case "$msg_type" in
	blocker | progress | review-request) ;;
	*)
		echo "ERROR: Invalid type '$msg_type'. Use: blocker, progress, review-request" >&2
		return 1
		;;
	esac

	local inbox_dir="$task_dir/comms/orchestrator/inbox"
	mkdir -p "$inbox_dir"

	# Generate filename
	local timestamp
	timestamp=$(date -u +"%Y%m%dT%H%M%SZ")
	local filename="${timestamp}-001.md"

	# Avoid collisions
	local seq=1
	while [[ -f "$inbox_dir/$filename" ]]; do
		seq=$((seq + 1))
		filename="${timestamp}-$(printf '%03d' $seq).md"
	done

	# Write message
	cat >"$inbox_dir/$filename" <<EOF
**Type:** ${msg_type}
**From:** worker
**Priority:** ${priority}

${message}
EOF

	echo "sent: $filename"
}
