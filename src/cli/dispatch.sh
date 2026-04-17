#!/usr/bin/env bash
# b_path:: src/cli/dispatch.sh
# CLI dispatcher - routes to appropriate driver
# ------------------------------------------------------------------------------

# Detect and set CLI
cli::detect() {
	local preferred="${NANCY_CLI:-}"

	# Use preferred if available
	if [[ -n "$preferred" ]] && deps::exists "$preferred"; then
		NANCY_CLI="$preferred"
		return 0
	fi

	# Auto-detect
	NANCY_CLI=$(deps::detect_cli) || return 1
	return 0
}

cli::_driver_name() {
	cli::current
}

cli::_driver_fn() {
	local cli
	cli=$(cli::_driver_name)
	printf 'cli::%s::%s\n' "$cli" "$1"
}

cli::_has_driver_fn() {
	declare -F "$(cli::_driver_fn "$1")" >/dev/null
}

cli::_call_driver() {
	"$(cli::_driver_fn "$1")" "${@:2}"
}

cli::_call_optional_driver() {
	local fn_name="$1"
	shift

	cli::_has_driver_fn "$fn_name" || return 1
	cli::_call_driver "$fn_name" "$@"
}

# Get current CLI name
cli::current() {
	echo "${NANCY_CLI:-copilot}"
}

# Get CLI version
cli::version() {
	cli::_call_driver version
}

# Run CLI with prompt
cli::run_prompt() {
	cli::_call_driver run_prompt "$@"
}

# Run CLI review prompt
cli::run_review_prompt() {
	if cli::_has_driver_fn run_review_prompt; then
		cli::_call_driver run_review_prompt "$@"
		return $?
	fi

	cli::run_prompt "$@"
}

# Run CLI interactively
cli::run_interactive() {
	cli::_call_driver run_interactive "$@"
}

# Get session directory
cli::session_dir() {
	cli::_call_driver session_dir "$@"
}

# Get session file path
# cli::session_file() {
# 	local cli
# 	cli=$(cli::current)
# 	"cli::${cli}::session_file" "$@"
# }

# Initialize session
cli::init_session() {
	cli::_call_driver init_session "$@"
}

cli::supports_sidecar() {
	cli::_call_optional_driver supports_sidecar
}

cli::supports_review_agent() {
	cli::_call_optional_driver supports_review_agent
}

cli::supports_agent_role() {
	cli::_call_optional_driver supports_agent_role
}

cli::supports_resume() {
	cli::_call_optional_driver supports_resume
}

cli::supports_export() {
	cli::_call_optional_driver supports_export
}
