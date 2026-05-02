#!/usr/bin/env bash
# b_path:: src/live/bridge.sh
# Opt-in compatibility bridge for the Rust live path.
# ------------------------------------------------------------------------------

live::bridge_enabled() {
	case "${NANCY_RUST_LIVE_ENABLED:-0}" in
	1 | true | TRUE | yes | YES) return 0 ;;
	*) return 1 ;;
	esac
}

live::bridge_command_supported() {
	case "${1:-}" in
	setup | go) return 0 ;;
	*) return 1 ;;
	esac
}

live::bridge_bin() {
	printf '%s\n' "${NANCY_RUST_LIVE_BIN:-$NANCY_FRAMEWORK_ROOT/target/release/nancy-live}"
}

live::bridge_should_dispatch() {
	local command="${1:-}"
	local bin

	live::bridge_enabled || return 1
	live::bridge_command_supported "$command" || return 1

	bin=$(live::bridge_bin)
	if [[ ! -x "$bin" ]]; then
		printf 'Rust live path requested but executable not found: %s\n' "$bin" >&2
		exit 1
	fi

	return 0
}

live::bridge_dispatch() {
	local bin
	bin=$(live::bridge_bin)

	export NANCY_LIVE_BRIDGE="rust"
	"$bin" "$@"
}
