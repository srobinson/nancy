#!/usr/bin/env bash
# b_path:: src/cmd/direct.sh
# Send a directive to a worker agent
# Uses new bidirectional comms API (Phase 1)
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

	# Send directive using new comms API
	# comms::orchestrator_send <task> <type> <message> [priority]
	local filename
	filename=$(comms::orchestrator_send "$task" "$msg_type" "$message" "$priority")

	if [[ -n "$filename" ]]; then
		ui::success "Directive sent: $filename"
	else
		log::error "Failed to send directive"
		return 1
	fi
}
