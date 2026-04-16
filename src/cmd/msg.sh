#!/usr/bin/env bash
# b_path:: src/cmd/msg.sh
# Worker message command - send status updates over helioy-bus
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

	if ! bus::available; then
		echo "ERROR: helioy-bus is not available. Set NANCY_HELIOY_BUS_ROOT or use helioy-bus MCP send_message directly." >&2
		return 1
	fi

	local task
	task=$(basename "$task_dir")

	local from_agent
	from_agent=$(bus::resolve_current_agent_id 2>/dev/null || true)
	from_agent="${from_agent:-nancy:worker:${task}}"

	local to_agent="${NANCY_BUS_TO:-*}"
	local content
	content=$(cat <<EOF
Nancy worker update
Task: ${task}
Type: ${msg_type}
Priority: ${priority}

${message}
EOF
)

	if ! bus::send_message "$to_agent" "$content" "$from_agent" "*" "nancy-${task}" "1" >/dev/null; then
		echo "ERROR: Failed to send bus message" >&2
		return 1
	fi

	echo "sent to bus: $to_agent"
}
