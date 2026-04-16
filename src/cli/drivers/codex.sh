#!/usr/bin/env bash
# b_path:: src/cli/drivers/codex.sh
# OpenAI Codex CLI driver for Nancy
# ------------------------------------------------------------------------------

CODEX_CMD="codex"

cli::codex::detect() {
	command -v "$CODEX_CMD" &>/dev/null
}

cli::codex::version() {
	"$CODEX_CMD" --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1
}

cli::codex::name() {
	echo "codex"
}

cli::codex::session_dir() {
	local NANCY_TASK_DIR="$1"
	echo "${NANCY_TASK_DIR}/session-state/codex"
}

cli::codex::init_session() {
	local _nancy_session_id="$1"
	local _task="$2"
	local NANCY_TASK_DIR="$3"

	mkdir -p "$(cli::codex::session_dir "$NANCY_TASK_DIR")"
}

cli::codex::run_interactive() {
	local prompt="${1:-}"
	local model="${NANCY_MODEL:-}"
	local args=("--dangerously-bypass-approvals-and-sandbox")

	if [[ -n "$model" ]]; then
		args+=("--model" "$model")
	fi

	"$CODEX_CMD" "${args[@]}" "$prompt"
}

cli::codex::run_prompt() {
	local prompt_text="$1"
	local nancy_session_id="$2"
	local export_file="$3"
	local NANCY_TASK_DIR="$4"
	local _agent_role="${5:-}"
	local model="${NANCY_MODEL:-}"

	local args=("exec" "--json" "--color" "never" "--dangerously-bypass-approvals-and-sandbox")
	local log_file="${NANCY_TASK_DIR}/logs/${nancy_session_id}.log"
	local formatted_log="${NANCY_TASK_DIR}/logs/${nancy_session_id}.formatted.log"
	local pid_file="${NANCY_TASK_DIR}/.worker_pid"

	if [[ -n "$model" ]]; then
		args+=("--model" "$model")
	fi

	if [[ -n "$export_file" ]]; then
		args+=("--output-last-message" "$export_file")
	fi

	log::debug "Running Codex for session: $nancy_session_id"

	mkdir -p "${NANCY_TASK_DIR}/logs"

	set -o pipefail
	(
		echo $BASHPID >"$pid_file"
		printf '%s\n' "$prompt_text" | exec "$CODEX_CMD" "${args[@]}" -
	) |
		tee -a "$log_file" |
		_codex_format_stream |
		fmt::strip_ansi |
		tee -a "$formatted_log" &
	local pipeline_pid=$!

	wait $pipeline_pid 2>/dev/null
	local exit_code=$?
	set +o pipefail

	rm -f "$pid_file"

	return "$exit_code"
}

_codex_format_stream() {
	jq --unbuffered -r '
		def usage_summary:
			.usage as $u |
			"■ Turn completed (input=\($u.input_tokens // 0), cached=\($u.cached_input_tokens // 0), output=\($u.output_tokens // 0))";

		if .type == "thread.started" then
			"▶ Session started (\(.thread_id // "unknown"))"
		elif .type == "turn.started" then
			empty
		elif .type == "item.completed" and .item.type == "agent_message" then
			.item.text // empty
		elif .type == "turn.completed" then
			usage_summary
		else
			empty
		end
	'
}

cli::codex::supports_resume() {
	return 0
}

cli::codex::supports_export() {
	return 0
}

cli::codex::auto_approve_flag() {
	echo "--dangerously-bypass-approvals-and-sandbox"
}

cli::codex::get_model_flag() {
	local model="$1"
	echo "--model $model"
}
