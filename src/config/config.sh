#!/usr/bin/env bash
# b_path:: src/config/config.sh
# shellcheck disable=SC2155
# Configuration loading and management
# Config inheritance: Nancy defaults → global config → task config
# ------------------------------------------------------------------------------

# Load global config from .nancy/config.json
config::load() {
	[[ ! -f "$NANCY_CONFIG_FILE" ]] && return 0

	# Parse config with jq (simplified flat schema)
	# Config is authoritative for this project (avoids ambient exported env vars
	# accidentally selecting the wrong CLI).
	export NANCY_CLI=$(
		jq -r '.cli // .provider // "claude"' "$NANCY_CONFIG_FILE" 2>/dev/null
	)
	export NANCY_MODEL=$(
		jq -r '.model // ""' "$NANCY_CONFIG_FILE" 2>/dev/null
	)
	export NANCY_TOKEN_THRESHOLD=$(
		jq -r '.token_threshold // 0.20' "$NANCY_CONFIG_FILE" 2>/dev/null
	)
}

# Load task-specific config (inherits from global, overrides where set)
config::load_task() {
	local task="$1"
	local task_config="$NANCY_TASK_DIR/$task/config.json"

	# First load global
	config::load

	# Then override with task-specific if exists
	if [[ -f "$task_config" ]]; then
		local task_cli task_model task_threshold
		task_cli=$(jq -r '.cli // .provider // empty' "$task_config" 2>/dev/null)
		task_model=$(jq -r '.model // empty' "$task_config" 2>/dev/null)
		task_threshold=$(jq -r '.token_threshold // empty' "$task_config" 2>/dev/null)

		[[ -n "$task_cli" ]] && NANCY_CLI="$task_cli"
		[[ -n "$task_model" ]] && NANCY_MODEL="$task_model"
		[[ -n "$task_threshold" ]] && NANCY_TOKEN_THRESHOLD="$task_threshold"
	fi
}

config::_top_key_from_file() {
	local file="$1"
	local key="$2"

	[[ ! -f "$file" ]] && return 0

	if [[ "$key" == "cli" ]]; then
		jq -r '.cli // .provider // empty' "$file" 2>/dev/null
	else
		jq -r --arg key "$key" '.[$key] // empty' "$file" 2>/dev/null
	fi
}

config::_agent_key_from_file() {
	local file="$1"
	local role="$2"
	local key="$3"

	[[ ! -f "$file" ]] && return 0

	if [[ "$key" == "cli" ]]; then
		jq -r --arg role "$role" '.agents[$role].cli // .agents[$role].provider // empty' "$file" 2>/dev/null
	else
		jq -r --arg role "$role" --arg key "$key" '.agents[$role][$key] // empty' "$file" 2>/dev/null
	fi
}

# Resolve an agent scoped value with compatibility fallback:
# global top level, global agent, task top level, task agent.
config::get_agent() {
	local task="$1"
	local role="$2"
	local key="$3"
	local value="${4:-}"
	local task_config=""
	local candidate

	if [[ -n "$task" ]]; then
		task_config="$NANCY_TASK_DIR/$task/config.json"
	fi

	candidate=$(config::_top_key_from_file "$NANCY_CONFIG_FILE" "$key")
	[[ -n "$candidate" ]] && value="$candidate"
	candidate=$(config::_agent_key_from_file "$NANCY_CONFIG_FILE" "$role" "$key")
	[[ -n "$candidate" ]] && value="$candidate"

	if [[ -n "$task_config" && -f "$task_config" ]]; then
		candidate=$(config::_top_key_from_file "$task_config" "$key")
		[[ -n "$candidate" ]] && value="$candidate"
		candidate=$(config::_agent_key_from_file "$task_config" "$role" "$key")
		[[ -n "$candidate" ]] && value="$candidate"
	fi

	printf '%s\n' "$value"
}

config::apply_agent() {
	local task="$1"
	local role="$2"

	NANCY_CLI=$(config::get_agent "$task" "$role" "cli" "${NANCY_CLI:-claude}")
	NANCY_MODEL=$(config::get_agent "$task" "$role" "model" "${NANCY_MODEL:-}")
	NANCY_TOKEN_THRESHOLD=$(config::get_agent "$task" "$role" "token_threshold" "${NANCY_TOKEN_THRESHOLD:-0.20}")
	export NANCY_CLI NANCY_MODEL NANCY_TOKEN_THRESHOLD
}

config::with_agent_env() {
	local task="$1"
	local role="$2"
	shift 2

	local had_cli=0 had_model=0 had_threshold=0
	local old_cli="" old_model="" old_threshold=""
	local restore_errexit=0
	[[ $- == *e* ]] && restore_errexit=1

	if [[ ${NANCY_CLI+x} ]]; then
		had_cli=1
		old_cli="$NANCY_CLI"
	fi
	if [[ ${NANCY_MODEL+x} ]]; then
		had_model=1
		old_model="$NANCY_MODEL"
	fi
	if [[ ${NANCY_TOKEN_THRESHOLD+x} ]]; then
		had_threshold=1
		old_threshold="$NANCY_TOKEN_THRESHOLD"
	fi

	config::apply_agent "$task" "$role"

	set +e
	"$@"
	local status=$?

	if ((had_cli == 1)); then
		export NANCY_CLI="$old_cli"
	else
		unset NANCY_CLI
	fi
	if ((had_model == 1)); then
		export NANCY_MODEL="$old_model"
	else
		unset NANCY_MODEL
	fi
	if ((had_threshold == 1)); then
		export NANCY_TOKEN_THRESHOLD="$old_threshold"
	else
		unset NANCY_TOKEN_THRESHOLD
	fi

	((restore_errexit == 1)) && set -e
	return "$status"
}

config::has_agent_shape() {
	local config_file="${1:-$NANCY_CONFIG_FILE}"

	[[ -f "$config_file" ]] || return 1

	jq -e '
		(.agents.worker | type == "object") and
		(.agents.reviewer | type == "object") and
		((.agents.worker.cli // .agents.worker.provider // "") != "") and
		((.agents.reviewer.cli // .agents.reviewer.provider // "") != "") and
		((.agents.worker.model // "") != "") and
		((.agents.reviewer.model // "") != "")
	' "$config_file" >/dev/null 2>&1
}

# Get a config value (from global config)
config::get() {
	local key="$1"
	local default="${2:-}"

	if [[ -f "$NANCY_CONFIG_FILE" ]]; then
		local value
		value=$(jq -r "$key // empty" "$NANCY_CONFIG_FILE" 2>/dev/null)
		echo "${value:-$default}"
	else
		echo "$default"
	fi
}

# Get a task-specific config value (with inheritance)
config::get_task() {
	local task="$1"
	local key="$2"
	local default="${3:-}"
	local task_config="$NANCY_TASK_DIR/$task/config.json"

	# Try task config first
	if [[ -f "$task_config" ]]; then
		local value
		value=$(jq -r "$key // empty" "$task_config" 2>/dev/null)
		[[ -n "$value" ]] && {
			echo "$value"
			return
		}
	fi

	# Fall back to global
	config::get "$key" "$default"
}

# Initialize config on load if nancy exists
if [[ -d "$NANCY_DIR" ]]; then
	config::load
fi
