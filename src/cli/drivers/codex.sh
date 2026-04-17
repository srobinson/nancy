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

# Run Codex from a rendered worker prompt
cli::codex::run_prompt() {
	local prompt_text="$1"
	local nancy_session_id="$2"
	local _export_file="$3"
	local NANCY_TASK_DIR="$4"
	local _agent_role="${5:-}"
	local model="${NANCY_MODEL:-}"

	local args=("--dangerously-bypass-approvals-and-sandbox")
	local pid_file="${NANCY_TASK_DIR}/.worker_pid"

	if [[ -n "$model" ]]; then
		args+=("--model" "$model")
	fi

	log::debug "Running Codex for session: $nancy_session_id"

	(
		echo $BASHPID >"$pid_file"
		exec "$CODEX_CMD" "${args[@]}" "$prompt_text"
	)
	local exit_code=$?

	rm -f "$pid_file"

	return "$exit_code"
}

cli::codex::run_review_prompt() {
	cli::codex::run_prompt "$@"
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
	return 1
}

cli::codex::supports_export() {
	return 0
}

cli::codex::supports_sidecar() {
	return 0
}

cli::codex::supports_review_agent() {
	return 0
}

cli::codex::supports_agent_role() {
	return 1
}

cli::codex::extract_context_percent() {
	local pane_text="$1"
	local match=""

	match=$(
		printf '%s\n' "$pane_text" |
			grep -oE 'Context[[:space:]]+[0-9]{1,3}%[[:space:]]+used' |
			tail -1 || true
	)

	if [[ -n "$match" ]]; then
		printf '%s\n' "$match" | sed -E 's/.*Context[[:space:]]+([0-9]{1,3})%.*/\1/'
	fi
}

cli::codex::handover_command() {
	printf '%s\n' '$session-handover'
}

cli::codex::auto_approve_flag() {
	echo "--dangerously-bypass-approvals-and-sandbox"
}

cli::codex::get_model_flag() {
	local model="$1"
	echo "--model $model"
}
