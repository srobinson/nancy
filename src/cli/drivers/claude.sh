#!/usr/bin/env bash
# b_path:: src/cli/drivers/claude.sh
# Claude Code CLI driver for Nancy
# ------------------------------------------------------------------------------
#
# Key differences from Copilot:
# - Session IDs must be UUIDs (not friendly names)
# - Sessions stored in ~/.claude/projects/<encoded-project>/<uuid>.jsonl
# - Uses --session-id <uuid> instead of --resume <name>
# - Sessions are not continuable
# - Token usage in assistant message .usage field (not truncation events)
# ------------------------------------------------------------------------------

CLAUDE_CMD="claude"
CLAUDE_CONFIG_DIR="${CLAUDE_CONFIG_DIR:-${HOME}/.claude}"
CLAUDE_PROJECTS_DIR="${CLAUDE_CONFIG_DIR}/projects"

# ------------------------------------------------------------------------------
# CLI Detection
# ------------------------------------------------------------------------------

# Check if Claude CLI is available
cli::claude::detect() {
	command -v "$CLAUDE_CMD" &>/dev/null
}

# Get Claude version
cli::claude::version() {
	"$CLAUDE_CMD" --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1
}

# Get name of this CLI
cli::claude::name() {
	echo "claude"
}

# ------------------------------------------------------------------------------
# Session Management
# ------------------------------------------------------------------------------

# Get encoded project path (how Claude stores projects)
# Claude replaces / with - and . with - (keeps leading dash)
cli::claude::encoded_project_path() {
	local project_dir="${1:-$(pwd)}"
	echo "$project_dir" | tr '/.' '--'
}

# Get Claude's project directory for current working directory
cli::claude::project_dir() {
	local project_path="${1:-$(pwd)}"
	local encoded
	encoded=$(cli::claude::encoded_project_path "$project_path")
	echo "${CLAUDE_PROJECTS_DIR}/${encoded}"
}

# Get session directory (Claude stores in ~/.claude/projects/<project>/)
cli::claude::session_dir() {
	local NANCY_TASK_DIR="$1"
	# Claude always stores sessions in its project directory, not task-local
	# We pass NANCY_TASK_DIR for interface consistency but use project path
	cli::claude::project_dir
}

# Get path to session file (the actual JSONL file Claude writes)
# cli::claude::session_file() {
# 	local nancy_session_id="$1"
# 	local NANCY_TASK_DIR="$2"

# 	# Get the UUID for this Nancy session
# 	local uuid
# 	uuid=$(cli::claude::get_uuid "$nancy_session_id" "$NANCY_TASK_DIR")

# 	if [[ -z "$uuid" ]]; then
# 		# No mapping yet - return expected path for new session
# 		uuid=$(cli::claude::get_or_create_uuid "$nancy_session_id" "$NANCY_TASK_DIR")
# 	fi

# 	local project_dir
# 	project_dir=$(cli::claude::project_dir)

# 	echo "${project_dir}/${uuid}.jsonl"
# }

# Initialize a session for Claude
cli::claude::init_session() {
	local nancy_session_id="$1"
	local _task="$2" # Unused - kept for interface consistency with other CLI drivers

	# NO-OP for Claude

	# local NANCY_TASK_DIR="$3"

	# # Get or create UUID mapping
	# local uuid
	# uuid=$(cli::claude::get_or_create_uuid "$nancy_session_id" "$NANCY_TASK_DIR")

	# log::debug "Mapped Nancy session '$nancy_session_id' to Claude UUID: $uuid"

	# Claude creates its own session file - we just need the mapping
	# No need to pre-create the JSONL file
}

# ------------------------------------------------------------------------------
# Execution
# ------------------------------------------------------------------------------

# Run Claude in interactive mode
cli::claude::run_interactive() {
	local prompt="${1:-}"
	local args=("--dangerously-skip-permissions")

	local uuid
	uuid=$(uuid::generate)

	# save to task directory
	echo "$uuid" >"$NANCY_TASK_DIR/interactive_session_id.txt"

	# Use --session-id with UUID
	args+=("--session-id" "$uuid")

	"$CLAUDE_CMD" "${args[@]}" "$prompt"
}

# Run Claude with a prompt (non-interactive)
cli::claude::run_prompt() {
	local prompt_text="$1"
	local nancy_session_id="$2"
	local export_file="$3"
	local NANCY_TASK_DIR="$4"
	local model="${NANCY_MODEL:-}"

	local uuid
	uuid=$(uuid::generate)

	local args=("--dangerously-skip-permissions")

	args+=("--session-id" "$uuid")

	if [[ -n "$model" ]]; then
		args+=("--model" "$model")
	fi

	# Use streaming JSON output for real-time visibility
	# Claude writes to session file regardless of output format
	args+=("--include-partial-messages" "--output-format" "stream-json" "--verbose" "--debug")

	# Claude uses -p for prompt input
	args+=("-p" "$prompt_text")

	log::debug "Running Claude with session UUID: $uuid"

	mkdir -p "${NANCY_TASK_DIR}/logs"

	echo "NANCY_FRAMEWORK_ROOT: $NANCY_FRAMEWORK_ROOT"
	echo "NANCY_CURRENT_TASK_DIR: $NANCY_CURRENT_TASK_DIR"
	echo "NANCY_TASK_DIR: $NANCY_TASK_DIR"

	# Run Claude and pipe through formatter for terminal display
	"$CLAUDE_CMD" "${args[@]}" | tee -a "$NANCY_TASK_DIR/logs/$nancy_session_id.log" | _claude_format_stream | fmt::strip_ansi | tee -a "$NANCY_TASK_DIR/logs/$nancy_session_id.formatted.log"
	local exit_code=${PIPESTATUS[0]}

	_copy_project_session "$nancy_session_id" "$uuid"

	# Export session summary if requested
	if [[ -n "$export_file" ]]; then
		cli::claude::export_session "$uuid" "$export_file" "$nancy_session_id"
	fi

	return "$exit_code"
}

_copy_project_session() {
	local nancy_session_id="$1"
	local uuid="$2"
	# Copy session JSONL to task directory for local storage
	# Claude stores in ~/.claude/projects/<encoded-project>/<uuid>.jsonl
	# We copy to NANCY_TASK_DIR/session-state/<nancy-session-id>.jsonl for consistency with Copilot
	local claude_session_file task_session_dir task_session_file
	claude_session_file="$(cli::claude::project_dir)/${uuid}.jsonl"
	task_session_dir="${NANCY_TASK_DIR}/session-state"
	task_session_file="${task_session_dir}/${nancy_session_id}.jsonl"

	if [[ -f "$claude_session_file" ]]; then
		mkdir -p "$task_session_dir"
		cp "$claude_session_file" "$task_session_file"
		log::debug "Copied Claude session to: $task_session_file"
	fi

}

# Format streaming JSON output for terminal display
# Single jq pass handles all event types with ANSI colors
# Usage: _claude_format_stream [use_colors]
#   use_colors: "true" (default) or "false"
_claude_format_stream() {
	local use_colors="${1:-true}"

	jq --unbuffered -r --argjson colors "$([[ "$use_colors" == "true" ]] && echo true || echo false)" '
		# ANSI color codes (conditional on $colors)
		def green: if $colors then "\u001b[0;32m" else "" end;
		def blue: if $colors then "\u001b[0;34m" else "" end;
		def cyan: if $colors then "\u001b[0;36m" else "" end;
		def yellow: if $colors then "\u001b[0;33m" else "" end;
		def red: if $colors then "\u001b[0;31m" else "" end;
		def dim: if $colors then "\u001b[0;90m" else "" end;
		def reset: if $colors then "\u001b[0m" else "" end;

		# Extract tool detail based on tool name
		def tool_detail:
			.name as $name |
			if $name == "Bash" then
				.input.command // ""
			elif $name == "Read" or $name == "Write" or $name == "Edit" then
				(.input.file_path // "") | split("/") | last
			elif $name == "Glob" or $name == "Grep" then
				.input.pattern // ""
			elif $name == "Skill" then
				.input.skill // ""
			else
				""
			end |
			if . != "" then ": \(.)" else "" end;

		# Format tool result content (truncate long output)
		def format_result:
			if type == "string" then
				# Check for special JSON results first
				(try fromjson catch null) as $parsed |
				if $parsed then
					if $parsed.recommendation then
						# Token check result
						($parsed.recommendation) as $rec |
						($parsed.percentRemaining // 100) as $pct |
						(if $rec == "END_TURN" then red elif $rec == "WRAP_UP" then yellow else green end) as $color |
						"\($color)📊 Tokens: \($pct)% remaining → \($rec)\(reset)"
					elif $parsed.directives then
						# Directives check result
						if ($parsed.count // 0) > 0 then
							"\(yellow)📨 Directives: \($parsed.count) pending\(reset)"
						else
							empty
						end
					else
						# Other JSON - show compact
						"\(dim)   ← \($parsed | tostring | .[:200])\(reset)"
					end
				else
					# Plain text result - show it (truncate if needed)
					if . == "" then
						empty
					elif (. | length) > 500 then
						"\(dim)   ← \(.[:500])...\(reset)"
					else
						"\(dim)   ← \(.)\(reset)"
					end
				end
			elif type == "array" then
				"\(dim)   ← [\(length) items]\(reset)"
			elif . == null or . == "" then
				empty
			else
				"\(dim)   ← \(. | tostring | .[:200])\(reset)"
			end;

		# Main dispatch
		if .type == "system" and .subtype == "init" then
			"\(green)▶ Session started (\(.model // "unknown"))\(reset)"

		elif .type == "assistant" then
			# Text content
			((.message.content[]? | select(.type == "text") | .text // empty) |
				if . and . != "" then "\(blue)💬\(reset) \(.)" else empty end),
			# Tool use
			((.message.content[]? | select(.type == "tool_use")) |
				"\(cyan)🔧 \(.name)\(tool_detail)\(reset)")

		elif .type == "user" then
			# Output ALL tool results
			(.message.content[]? | select(.type == "tool_result") | .content | format_result)

		elif .type == "result" then
			"\(yellow)■ Session ended (\(.subtype // "unknown"), $\(.total_cost_usd // 0), \(.duration_ms // 0)ms)\(reset)"

		else
			empty
		end
	'
}

# Export session to file - metadata and statistics only (single jq pass)
cli::claude::export_session() {
	local uuid="$1"
	local export_file="$2"
	local nancy_session_id="${3:-}"

	local timestamp
	timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

	local session_file
	session_file=$(cli::claude::project_dir)/"${uuid}.jsonl"

	if [[ ! -f "$session_file" ]]; then
		cat >"$export_file" <<EOF
# Claude Session Export
Nancy Session: ${nancy_session_id}
UUID: ${uuid}
Exported: ${timestamp}

Session file not found.
EOF
		return
	fi

	# Single jq pass: slurp all lines, compute stats, output markdown
	jq -rs --arg session_id "$nancy_session_id" --arg uuid "$uuid" --arg exported "$timestamp" '
		# Collect stats
		(map(select(.type == "assistant")) | length) as $assistant_count |
		(map(select(.type == "user")) | length) as $user_count |
		([.[] | select(.type == "assistant") | .message.content[]? | select(.type == "tool_use")] | length) as $tool_count |

		# First/last events for timestamps (skip queue-operation for start)
		([.[] | select(.type != "queue-operation")][0].timestamp // "unknown") as $start_time |
		(.[-1].timestamp // "unknown") as $end_time |
		([.[] | .gitBranch // empty][0] // "unknown") as $git_branch |

		# Model from first assistant message
		([.[] | select(.type == "assistant") | .message.model // empty][0] // "unknown") as $model |

		# Final usage from last assistant message
		([.[] | select(.type == "assistant")][-1].message.usage // {}) as $final_usage |
		(($final_usage.input_tokens // 0) + ($final_usage.cache_read_input_tokens // 0) + ($final_usage.cache_creation_input_tokens // 0)) as $total_input |
		($final_usage.output_tokens // 0) as $total_output |

		# Output markdown
		"# 🤖 Claude CLI Session\n\n" +
		"> **Session ID:** `\($session_id)`\n" +
		"> **UUID:** `\($uuid)`\n" +
		"> **Model:** \($model)\n" +
		"> **Started:** \($start_time)\n" +
		"> **Ended:** \($end_time)\n" +
		"> **Git Branch:** \($git_branch)\n" +
		"> **Exported:** \($exported)\n\n" +
		"## Session Statistics\n\n" +
		"| Metric | Value |\n" +
		"|--------|-------|\n" +
		"| Assistant Messages | \($assistant_count) |\n" +
		"| User Messages | \($user_count) |\n" +
		"| Tool Calls | \($tool_count) |\n" +
		"| Total Input Tokens | \(if $total_input > 0 then $total_input else "N/A" end) |\n" +
		"| Total Output Tokens | \(if $total_output > 0 then $total_output else "N/A" end) |\n\n" +
		"## Token Usage (Final)\n\n```json\n" +
		($final_usage | tojson) +
		"\n```"
	' "$session_file" >"$export_file" 2>/dev/null

	log::debug "Created Claude session export: $export_file"
}

# ------------------------------------------------------------------------------
# Capability Flags
# ------------------------------------------------------------------------------

# Check if Claude supports session resume
cli::claude::supports_resume() {
	return 0
}

# Check if Claude supports session export
cli::claude::supports_export() {
	# Claude doesn't have --share flag like Copilot
	return 1
}

# Get auto-approve flag
cli::claude::auto_approve_flag() {
	echo "--dangerously-skip-permissions"
}

# Get model flag
cli::claude::get_model_flag() {
	local model="$1"
	echo "--model $model"
}
