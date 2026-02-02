#!/usr/bin/env bash
# b_path:: src/core/deps.sh
# Dependency checking
# ------------------------------------------------------------------------------

# Required dependencies
DEPS_REQUIRED=(git jq gum tmux)

# CLI tools - at least one required
DEPS_CLI=(copilot claude opencode gemini)

# ------------------------------------------------------------------------------

# Check if a command exists
deps::exists() {
	command -v "$1" &>/dev/null
}

# Validate required dependencies
deps::check_required() {
	local missing=()

	for dep in "${DEPS_REQUIRED[@]}"; do
		if ! deps::exists "$dep"; then
			missing+=("$dep")
		fi
	done

	if [[ ${#missing[@]} -gt 0 ]]; then
		echo "Missing required dependencies: ${missing[*]}" >&2
		echo "" >&2
		echo "Install with:" >&2
		for dep in "${missing[@]}"; do
			case "$dep" in
			gum) echo "  brew install gum" >&2 ;;
			tmux) echo "  brew install tmux" >&2 ;;
			jq) echo "  brew install jq" >&2 ;;
			git) echo "  brew install git" >&2 ;;
			esac
		done
		return 1
	fi
	return 0
}

# Check if any CLI is available
deps::check_cli() {
	for cli in "${DEPS_CLI[@]}"; do
		if deps::exists "$cli"; then
			return 0
		fi
	done

	echo "No AI CLI found. Install one of: ${DEPS_CLI[*]}" >&2
	return 1
}

# Get first available CLI
deps::detect_cli() {
	for cli in "${DEPS_CLI[@]}"; do
		if deps::exists "$cli"; then
			echo "$cli"
			return 0
		fi
	done
	return 1
}

# Full validation
deps::validate() {
	deps::check_required || return 1
	deps::check_cli || return 1
	return 0
}
