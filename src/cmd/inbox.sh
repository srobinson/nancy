#!/usr/bin/env bash
# b_path:: src/cmd/inbox.sh
# Legacy inbox commands
# ------------------------------------------------------------------------------
#
# Commands:
#   nancy inbox     - Worker checks for directives (worker/inbox)
#   nancy messages  - Orchestrator checks for worker messages (orchestrator/inbox)
#   nancy read <f>  - Read a message from either inbox
#   nancy archive <f> - Archive a message from either inbox
#
# ------------------------------------------------------------------------------

# Helper: discover task directory
_discover_task_dir() {
	local task_dir="${NANCY_CURRENT_TASK_DIR:-}"

	if [[ -z "$task_dir" ]]; then
		if [[ -d ".nancy/tasks" ]]; then
			# Find most recently modified task directory (by any activity)
			# find with -exec stat for cross-platform mtime sorting
			task_dir=$(find .nancy/tasks -mindepth 1 -maxdepth 1 -type d 2>/dev/null | while read -r d; do
				stat -f '%m %N' "$d" 2>/dev/null || stat -c '%Y %n' "$d" 2>/dev/null
			done | sort -rn | head -1 | cut -d' ' -f2-)
		fi
	fi

	echo "$task_dir"
}

cmd::inbox() {
	echo "nancy inbox is deprecated."
	echo "Use helioy-bus get_messages from the active Claude session instead."
	return 1
}

cmd::messages() {
	echo "nancy messages is deprecated."
	echo "Use helioy-bus get_messages from the active Claude session instead."
	return 1
}

cmd::read_msg() {
	echo "nancy read is deprecated with helioy-bus."
	echo "Use helioy-bus get_messages to read and archive unread messages."
	return 1
}

cmd::archive() {
	echo "nancy archive is deprecated with helioy-bus."
	echo "Use helioy-bus get_messages to drain the unread mailbox."
	return 1
}
