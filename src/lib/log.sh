#!/usr/bin/env bash
# b_path:: src/lib/log.sh
# Logging utilities - gum powered
# ------------------------------------------------------------------------------

log::debug() {
	# [[ -z "${NANCY_DEBUG:-}" ]] && return 0
	gum log --level debug "$*"
}

log::info() {
	gum log --level info "$*"
}

log::warn() {
	gum log --level warn "$*"
}

log::error() {
	gum log --level error "$*"
}

log::fatal() {
	gum log --level error "$*"
	exit 1
}

log::success() {
	gum style --foreground 212 "✓ $*"
}

log::header() {
	echo ""
	gum style --bold --foreground 212 "$*"
	echo ""
}
