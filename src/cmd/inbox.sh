#!/usr/bin/env bash
# b_path:: src/cmd/inbox.sh
# Bidirectional inbox commands for worker and orchestrator
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

# cmd::inbox - Worker checks for directives from orchestrator
cmd::inbox() {
	local task_dir
	task_dir=$(_discover_task_dir)

	if [[ -z "$task_dir" ]]; then
		echo "No task found"
		return 1
	fi

	local inbox_dir="$task_dir/comms/worker/inbox"

	if [[ ! -d "$inbox_dir" ]]; then
		echo "No pending directives"
		return 1
	fi

	local files
	files=$(find "$inbox_dir" -name "*.md" -type f 2>/dev/null | sort)

	if [[ -z "$files" ]]; then
		echo "No pending directives"
		return 1
	fi

	echo "📬 Pending directives:"
	echo "$files" | while read -r f; do
		local filename type priority
		filename=$(basename "$f")
		type=$(grep -m1 '^\*\*Type:\*\*' "$f" 2>/dev/null | sed 's/.*\*\*Type:\*\*[[:space:]]*//')
		priority=$(grep -m1 '^\*\*Priority:\*\*' "$f" 2>/dev/null | sed 's/.*\*\*Priority:\*\*[[:space:]]*//')
		echo "  - $filename [$type]${priority:+ ($priority)}"
		echo "    → $f"
		echo "    Read: nancy read $filename"
	done

	return 0
}

# cmd::messages - Orchestrator checks for messages from worker
cmd::messages() {
	local task_dir
	task_dir=$(_discover_task_dir)

	if [[ -z "$task_dir" ]]; then
		echo "No task found"
		return 1
	fi

	local inbox_dir="$task_dir/comms/orchestrator/inbox"

	if [[ ! -d "$inbox_dir" ]]; then
		echo "No pending messages from worker"
		return 0
	fi

	local files
	files=$(find "$inbox_dir" -name "*.md" -type f 2>/dev/null | sort)

	if [[ -z "$files" ]]; then
		echo "No pending messages from worker"
		return 0
	fi

	echo "📬 Pending messages from worker:"
	echo "$files" | while read -r f; do
		local filename type priority
		filename=$(basename "$f")
		type=$(grep -m1 '^\*\*Type:\*\*' "$f" 2>/dev/null | sed 's/.*\*\*Type:\*\*[[:space:]]*//')
		priority=$(grep -m1 '^\*\*Priority:\*\*' "$f" 2>/dev/null | sed 's/.*\*\*Priority:\*\*[[:space:]]*//')
		echo "  - $filename [$type]${priority:+ ($priority)}"
		echo "    → $f"
		echo "    Read: nancy read $filename"
	done
}

# cmd::read - Read a specific message file
cmd::read_msg() {
	local filename="$1"

	if [[ -z "$filename" ]]; then
		echo "Usage: nancy read <filename>"
		return 1
	fi

	local task_dir
	task_dir=$(_discover_task_dir)

	if [[ -z "$task_dir" ]]; then
		echo "No task found"
		return 1
	fi

	# Check both inboxes
	local filepath=""
	if [[ -f "$task_dir/comms/worker/inbox/$filename" ]]; then
		filepath="$task_dir/comms/worker/inbox/$filename"
	elif [[ -f "$task_dir/comms/orchestrator/inbox/$filename" ]]; then
		filepath="$task_dir/comms/orchestrator/inbox/$filename"
	fi

	if [[ -z "$filepath" ]]; then
		echo "Message not found: $filename"
		return 1
	fi

	cat "$filepath"
}

# cmd::archive - Archive a message from either inbox
cmd::archive() {
	local filename="$1"

	if [[ -z "$filename" ]]; then
		echo "Usage: nancy archive <filename>"
		return 1
	fi

	local task_dir
	task_dir=$(_discover_task_dir)

	if [[ -z "$task_dir" ]]; then
		echo "No task found"
		return 1
	fi

	# Check both inboxes
	local filepath="" source=""
	if [[ -f "$task_dir/comms/worker/inbox/$filename" ]]; then
		filepath="$task_dir/comms/worker/inbox/$filename"
		source="worker"
	elif [[ -f "$task_dir/comms/orchestrator/inbox/$filename" ]]; then
		filepath="$task_dir/comms/orchestrator/inbox/$filename"
		source="orchestrator"
	fi

	if [[ -z "$filepath" ]]; then
		echo "Message not found: $filename"
		return 1
	fi

	local archive_dir="$task_dir/comms/archive"
	mkdir -p "$archive_dir"
	mv "$filepath" "$archive_dir/"
	echo "Archived: $filename"

	# Clear [NEW] indicator if orchestrator inbox is now empty
	if [[ "$source" == "orchestrator" ]]; then
		local remaining
		remaining=$(find "$task_dir/comms/orchestrator/inbox" -name "*.md" -type f 2>/dev/null | wc -l)
		if [[ "$remaining" -eq 0 ]]; then
			# Get task name from task_dir path
			local task_name
			task_name=$(basename "$task_dir")
			local inbox_pane="nancy-${task_name}.2"
			tmux select-pane -t "$inbox_pane" -T "📬 Inbox" 2>/dev/null || true
		fi
	fi
}
