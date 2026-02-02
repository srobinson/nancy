#!/usr/bin/env bash
# b_path:: src/task/token.sh
# Token usage tracking for context window monitoring
# ------------------------------------------------------------------------------
#
# Functions:
#   token::parse_usage <line>       - Extract usage from JSONL line
#   token::update <task> <line>     - Update token-usage.json from JSONL line
#   token::read <task>              - Read current token usage
#   token::percent <task>           - Get context usage percentage
#   token::reset <task>             - Reset token tracking for new iteration
#
# Token calculation:
#   total_input = input_tokens + cache_creation_input_tokens + cache_read_input_tokens
#
# Context window: 200k tokens (Claude)
# ------------------------------------------------------------------------------

TOKEN_CONTEXT_LIMIT="${TOKEN_CONTEXT_LIMIT:-200000}"

# -----------------------------------------------------------------------------
# token::_usage_file - Get path to token-usage.json for a task
# Args: task
# -----------------------------------------------------------------------------
token::_usage_file() {
	local task="$1"
	echo "$NANCY_TASK_DIR/$task/token-usage.json"
}

# -----------------------------------------------------------------------------
# token::parse_usage - Extract usage object from a JSONL line
# Args: line (JSON string)
# Returns: JSON usage object or empty if not an assistant message
# -----------------------------------------------------------------------------
token::parse_usage() {
	local line="$1"

	# Only process assistant messages with usage data
	echo "$line" | jq -c '
		select(.type == "assistant") |
		.message.usage // empty
	' 2>/dev/null
}

# -----------------------------------------------------------------------------
# token::update - Update token-usage.json from a JSONL line
# Args: task, line (JSON string)
# Returns: 0 if updated, 1 if skipped (not an assistant message)
# -----------------------------------------------------------------------------
token::update() {
	local task="$1"
	local line="$2"
	local usage_file
	usage_file=$(token::_usage_file "$task")

	# Parse usage from line
	local usage
	usage=$(token::parse_usage "$line")

	# Skip if no usage data
	[[ -z "$usage" ]] && return 1

	# Extract token counts
	local input cache_creation cache_read output
	input=$(echo "$usage" | jq -r '.input_tokens // 0')
	cache_creation=$(echo "$usage" | jq -r '.cache_creation_input_tokens // 0')
	cache_read=$(echo "$usage" | jq -r '.cache_read_input_tokens // 0')
	output=$(echo "$usage" | jq -r '.output_tokens // 0')

	# Calculate this turn's input total
	local turn_input=$((input + cache_creation + cache_read))

	# Read existing output total (input is not cumulative - each turn has full context)
	local prev_output=0
	if [[ -f "$usage_file" ]]; then
		prev_output=$(jq -r '.total_output // 0' "$usage_file")
	fi

	# For context tracking, we care about the LATEST input total (not cumulative)
	# because each turn's input includes the full conversation history
	# Output tokens accumulate as they become part of future input
	local total_input=$turn_input
	local total_output=$((prev_output + output))
	# claude does not count input + output together for context limit
	# TODO: This is what I am seeing in practice, but verify with more testing
	# local total=$((total_input + total_output))
	local percent
	percent=$(awk "BEGIN {printf \"%.1f\", ($total_input / $TOKEN_CONTEXT_LIMIT) * 100}")

	# Ensure directory exists
	mkdir -p "$(dirname "$usage_file")"

	# Write updated usage atomically (temp file + mv)
	local tmp_file="${usage_file}.tmp.$$"
	jq -n \
		--argjson total_input "$total_input" \
		--argjson total_output "$total_output" \
		--argjson turn_input "$turn_input" \
		--argjson turn_output "$output" \
		--argjson limit "$TOKEN_CONTEXT_LIMIT" \
		--arg percent "$percent" \
		--arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
		'{
			total_input: $total_input,
			total_output: $total_output,
			turn_input: $turn_input,
			turn_output: $turn_output,
			limit: $limit,
			percent: ($percent | tonumber),
			updated: $updated
		}' >"$tmp_file" && mv "$tmp_file" "$usage_file"

	return 0
}

# -----------------------------------------------------------------------------
# token::read - Read current token usage for a task
# Args: task
# Returns: JSON object with usage data, or default if not exists
# -----------------------------------------------------------------------------
token::read() {
	local task="$1"
	local usage_file
	usage_file=$(token::_usage_file "$task")

	if [ -s "$usage_file" ]; then
		cat "$usage_file"
	else
		jq -n \
			--argjson limit "$TOKEN_CONTEXT_LIMIT" \
			'{
				total_input: 0,
				total_output: 0,
				turn_input: 0,
				turn_output: 0,
				limit: $limit,
				percent: 0,
				updated: null
			}'
	fi
}

# -----------------------------------------------------------------------------
# token::percent - Get current context usage percentage
# Args: task
# Returns: percentage as float (e.g., "32.5")
# -----------------------------------------------------------------------------
token::percent() {
	local task="$1"
	token::read "$task" | jq -r '.percent'
}

# -----------------------------------------------------------------------------
# token::reset - Reset token tracking for a new iteration
# Args: task
# -----------------------------------------------------------------------------
token::reset() {
	local task="$1"
	local usage_file
	usage_file=$(token::_usage_file "$task")

	# If the file exists, back it up with incrementing number
	if [[ -f "$usage_file" ]]; then

		local backup_num=0
		local backup_file

		# Find next available backup number
		while true; do
			backup_file="${usage_file%.json}.$(printf '%02d' $backup_num).json"
			if [[ ! -f "$backup_file" ]]; then
				break
			fi
			backup_num=$((backup_num + 1))
		done

		echo "Resetting token usage for task $task. Backing up existing file to $backup_file"

		# Move existing file to backup
		mv "$usage_file" "$backup_file"
	fi

	token::read "$task" >"$usage_file"

}

# -----------------------------------------------------------------------------
# token::check_threshold - Check orchestration-specific thresholds
# Args: task
# Returns: threshold level as string
# Outputs: "ok" | "warning" (50-59%) | "critical" (60-69%) | "danger" (70%+)
# Used by the token watcher to send progressive alerts via nancy direct
# -----------------------------------------------------------------------------
token::check_threshold() {
	local task="$1"

	local percent
	percent=$(token::percent "$task")

	if ((${percent%.*} >= 85)); then
		echo "danger"
	elif ((${percent%.*} >= 75)); then
		echo "critical"
	elif ((${percent%.*} >= 65)); then
		echo "warning"
	else
		echo "ok"
	fi
}
