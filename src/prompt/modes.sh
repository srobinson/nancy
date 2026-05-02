#!/usr/bin/env bash
# b_path:: src/prompt/modes.sh
# Gate aware prompt mode fragments
# ------------------------------------------------------------------------------

prompt::mode_instructions() {
	local mode="${1:-execution}"
	local mode_file="${NANCY_FRAMEWORK_ROOT}/templates/modes/${mode}.md.template"

	if [[ ! -f "$mode_file" ]]; then
		log::error "Prompt mode template not found: $mode_file"
		return 1
	fi

	cat "$mode_file"
}
