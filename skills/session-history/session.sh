#!/bin/bash
# Session History Helper - works for adhoc and worker agents
# Source this or run commands directly

# Derive project path from cwd (Claude CLI convention)
_session_project_path() {
	local cwd="${1:-$(pwd)}"
	local encoded=$(echo "$cwd" | sed 's|^/||' | tr '/' '-')
	echo "$HOME/.claude/projects/-$encoded"
}

# List sessions for current project (most recent first)
session_list() {
	local project_path="${HW_SESSION_DIR:-$(_session_project_path)}"
	if [[ ! -d "$project_path" ]]; then
		echo "No sessions found for: $project_path" >&2
		return 1
	fi

	echo "Sessions in: $project_path"
	echo "---"
	# Get files with mtime, sort by mtime descending
	find "$project_path" -maxdepth 1 -name "*.jsonl" -type f 2>/dev/null | while read -r file; do
		# Get mtime for sorting (stat -f for BSD/macOS, stat -c for GNU)
		local mtime
		mtime=$(stat -f '%m' "$file" 2>/dev/null || stat -c '%Y' "$file" 2>/dev/null)
		echo "$mtime $file"
	done | sort -rn | cut -d' ' -f2- | while read -r file; do
		local id=$(basename "$file" .jsonl)
		local size
		size=$(stat -f '%z' "$file" 2>/dev/null || stat -c '%s' "$file" 2>/dev/null)
		local date
		date=$(stat -f '%Sm' -t '%b %d %H:%M' "$file" 2>/dev/null || stat -c '%y' "$file" 2>/dev/null | cut -c1-16)

		# Get first user message (intent)
		local first_prompt=$(grep '"type":"user"' "$file" 2>/dev/null | head -1 | jq -r '.message.content // .message' 2>/dev/null | head -c 80)

		# Get summaries if any
		local summaries=$(grep '"type":"summary"' "$file" 2>/dev/null | jq -r '.summary' 2>/dev/null | head -3 | tr '\n' '; ')

		echo "[$date] $id (${size}B)"
		[[ -n "$first_prompt" ]] && echo "  First: ${first_prompt}..."
		[[ -n "$summaries" ]] && echo "  Summaries: $summaries"
		echo ""
	done
}

# Get current session ID (most recent by mtime)
session_current_id() {
	local project_path="${HW_SESSION_DIR:-$(_session_project_path)}"
	# Find most recent jsonl by mtime
	find "$project_path" -maxdepth 1 -name "*.jsonl" -type f 2>/dev/null | while read -r file; do
		stat -f '%m %N' "$file" 2>/dev/null || stat -c '%Y %n' "$file" 2>/dev/null
	done | sort -rn | head -1 | awk '{print $2}' | xargs basename 2>/dev/null | sed 's/.jsonl$//'
}

# Get previous session ID (second most recent)
session_previous_id() {
	local project_path="${HW_SESSION_DIR:-$(_session_project_path)}"
	# Find second most recent jsonl by mtime
	find "$project_path" -maxdepth 1 -name "*.jsonl" -type f 2>/dev/null | while read -r file; do
		stat -f '%m %N' "$file" 2>/dev/null || stat -c '%Y %n' "$file" 2>/dev/null
	done | sort -rn | head -2 | tail -1 | awk '{print $2}' | xargs basename 2>/dev/null | sed 's/.jsonl$//'
}

# Get session file path
session_file() {
	local id="${1:-$(session_current_id)}"
	local project_path="${HW_SESSION_DIR:-$(_session_project_path)}"
	echo "$project_path/$id.jsonl"
}

# Show last N messages from a session
session_tail() {
	local n="${1:-10}"
	local id="${2:-$(session_current_id)}"
	local file=$(session_file "$id")

	if [[ ! -f "$file" ]]; then
		echo "Session not found: $id" >&2
		return 1
	fi

	echo "=== Last $n messages from $id ==="
	grep -E '"type":"(user|assistant)"' "$file" | tail -"$n" | while read -r line; do
		local type=$(echo "$line" | jq -r '.type')
		local uuid=$(echo "$line" | jq -r '.uuid' | cut -c1-8)

		if [[ "$type" == "user" ]]; then
			local content=$(echo "$line" | jq -r '.message.content // .message' | head -c 200)
			echo -e "\n[USER $uuid] $content"
		else
			# Assistant - get text content blocks
			local content=$(echo "$line" | jq -r '.message.content[]? | select(.type=="text") | .text' 2>/dev/null | head -c 300)
			[[ -n "$content" ]] && echo -e "\n[ASSISTANT $uuid] $content..."
		fi
	done
	echo ""
}

# Show all user messages from a session (intent trail)
session_prompts() {
	local id="${1:-$(session_current_id)}"
	local file=$(session_file "$id")

	echo "=== User prompts from $id ==="
	grep '"type":"user"' "$file" | jq -r '
    "[" + (.uuid | .[0:8]) + "] " + (.message.content // .message | .[0:150])
  ' 2>/dev/null
}

# Show summaries from a session
session_summaries() {
	local id="${1:-$(session_current_id)}"
	local file=$(session_file "$id")

	echo "=== Summaries from $id ==="
	grep '"type":"summary"' "$file" | jq -r '.summary' 2>/dev/null
}

# Search across all sessions in project
session_grep() {
	local term="$1"
	local project_path="${HW_SESSION_DIR:-$(_session_project_path)}"

	if [[ -z "$term" ]]; then
		echo "Usage: session_grep <term>" >&2
		return 1
	fi

	echo "=== Searching for '$term' ==="
	grep -l "$term" "$project_path"/*.jsonl 2>/dev/null | while read -r file; do
		local id=$(basename "$file" .jsonl)
		echo -e "\n--- Session: $id ---"
		grep "$term" "$file" | grep '"type":"user"' | jq -r '
      "[USER] " + (.message.content // .message | .[0:150])
    ' 2>/dev/null | head -5
	done
}

# Show files touched in a session (from tool calls)
session_files() {
	local id="${1:-$(session_current_id)}"
	local file=$(session_file "$id")

	echo "=== Files touched in $id ==="
	grep -o '"file_path":"[^"]*"' "$file" 2>/dev/null | cut -d'"' -f4 | sort -u
	grep -o '"path":"[^"]*"' "$file" 2>/dev/null | cut -d'"' -f4 | sort -u
}

# Quick status of current + previous session
session_status() {
	local current=$(session_current_id)
	local previous=$(session_previous_id)

	echo "=== Session Status ==="
	echo "Project: $(_session_project_path)"
	echo "Current: $current"
	echo "Previous: $previous"
	echo ""

	if [[ -n "$current" ]]; then
		echo "--- Current Session Summaries ---"
		session_summaries "$current"
	fi

	if [[ -n "$previous" && "$previous" != "$current" ]]; then
		echo ""
		echo "--- Previous Session Summaries ---"
		session_summaries "$previous"
	fi
}

# If sourced, functions are available. If run directly, execute command.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	cmd="$1"
	shift
	case "$cmd" in
	list) session_list "$@" ;;
	current) session_current_id "$@" ;;
	previous) session_previous_id "$@" ;;
	tail) session_tail "$@" ;;
	prompts) session_prompts "$@" ;;
	summaries) session_summaries "$@" ;;
	grep) session_grep "$@" ;;
	files) session_files "$@" ;;
	status) session_status "$@" ;;
	*)
		echo "Usage: session.sh <command> [args]"
		echo "Commands: list, current, previous, tail [n] [id], prompts [id], summaries [id], grep <term>, files [id], status"
		;;
	esac
fi
