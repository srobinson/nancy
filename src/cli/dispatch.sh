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

# Get current CLI name
cli::current() {
	echo "${NANCY_CLI:-copilot}"
}

# Get CLI version
cli::version() {
	local cli
	cli=$(cli::current)
	"cli::${cli}::version"
}

# Run CLI with prompt
cli::run_prompt() {
	local cli
	cli=$(cli::current)
	"cli::${cli}::run_prompt" "$@"
}

# Run CLI interactively
cli::run_interactive() {
	local cli
	cli=$(cli::current)
	"cli::${cli}::run_interactive" "$@"
}

# Get session directory
cli::session_dir() {
	local cli
	cli=$(cli::current)
	"cli::${cli}::session_dir" "$@"
}

# Get session file path
# cli::session_file() {
# 	local cli
# 	cli=$(cli::current)
# 	"cli::${cli}::session_file" "$@"
# }

# Initialize session
cli::init_session() {
	local cli
	cli=$(cli::current)
	"cli::${cli}::init_session" "$@"
}
