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
		jq -r '.cli // "copilot"' "$NANCY_CONFIG_FILE" 2>/dev/null
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
		task_cli=$(jq -r '.cli // empty' "$task_config" 2>/dev/null)
		task_model=$(jq -r '.model // empty' "$task_config" 2>/dev/null)
		task_threshold=$(jq -r '.token_threshold // empty' "$task_config" 2>/dev/null)

		[[ -n "$task_cli" ]] && NANCY_CLI="$task_cli"
		[[ -n "$task_model" ]] && NANCY_MODEL="$task_model"
		[[ -n "$task_threshold" ]] && NANCY_TOKEN_THRESHOLD="$task_threshold"
	fi
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
