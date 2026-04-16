#!/usr/bin/env bash
# b_path:: src/cmd/direct.sh
# Send a control message to the current worker over helioy-bus
# ------------------------------------------------------------------------------

cmd::direct() {
	local task=""
	local message=""
	local priority="normal"
	local msg_type="guidance"

	# Parse arguments - support both positional and flags
	task="$1"
	message="$2"
	shift 2 || true

	# Parse remaining args as either flags or positional
	while [[ $# -gt 0 ]]; do
		case "$1" in
			--type)
				msg_type="$2"
				shift 2
				;;
			--priority)
				priority="$2"
				shift 2
				;;
			*)
				# Positional: first is priority, second is type
				if [[ "$priority" == "normal" ]]; then
					priority="$1"
				elif [[ "$msg_type" == "guidance" ]]; then
					msg_type="$1"
				fi
				shift
				;;
		esac
	done

	if [[ -z "$task" || -z "$message" ]]; then
		log::error "Usage: nancy direct <task> \"message\" [--type TYPE] [--priority PRIORITY]"
		echo ""
		ui::muted "Priority: normal (default), urgent, low"
		ui::muted "Type: guidance (default), directive, stop"
		return 1
	fi

	if ! task::exists "$task"; then
		log::error "Task '$task' does not exist"
		return 1
	fi

	# Map legacy types to new schema (clean break, but helpful for muscle memory)
	case "$msg_type" in
		redirect)
			msg_type="guidance"
			log::warn "Type 'redirect' mapped to 'guidance'"
			;;
		pause)
			msg_type="stop"
			log::warn "Type 'pause' mapped to 'stop'"
			;;
	esac

	# Validate type
	if [[ ! "$msg_type" =~ ^(directive|guidance|stop)$ ]]; then
		log::error "Invalid type '$msg_type'. Valid types: directive, guidance, stop"
		return 1
	fi

	local content
	content=$(cat <<EOF
Nancy control message
Task: ${task}
Type: ${msg_type}
Priority: ${priority}

${message}
EOF
)

	local to_agent
	to_agent=""
	if bus::available; then
		to_agent=$(bus::resolve_task_worker_agent "$task")
	fi
	if [[ -n "$to_agent" ]]; then
		if ! bus::send_message "$to_agent" "$content" "nancy:operator:${task}" "*" "nancy-${task}" "1" >/dev/null; then
			log::error "Failed to send directive over helioy-bus"
			return 1
		fi
		ui::success "Sent ${msg_type} message to ${to_agent}"
		return 0
	fi

	local pane
	pane=$(bus::inject_task_worker "$task" "$message")
	if [[ -n "$pane" ]]; then
		log::warn "Worker not registered on helioy-bus; injected message directly into pane ${pane}"
		ui::success "Sent ${msg_type} message to live worker pane"
		return 0
	fi

	log::error "No live worker agent or pane found for task '$task'"
	return 1
}
