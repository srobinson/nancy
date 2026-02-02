#!/usr/bin/env bash
# b_path:: src/cmd/go.sh
# Init + orchestrate in one command
# ------------------------------------------------------------------------------

cmd::go() {
	local task="${1:-}"

	config::load

	if [[ ! -d "$NANCY_DIR" ]]; then
		log::error "Nancy not initialized. Run 'nancy setup' first."
		return 1
	fi

	if [[ -z "$task" ]]; then
		task=$(ui::input "Task name")
		[[ -z "$task" ]] && return 1
	fi

	if ! task::validate_name "$task"; then
		return 1
	fi

	# Init if task doesn't exist yet
	if ! task::exists "$task"; then
		ui::header "Creating task: $task"
		task::create "$task"
		ui::success "Created ${NANCY_TASK_DIR}/${task}"
		echo ""
	fi

	export NANCY_CURRENT_TASK_DIR="${NANCY_TASK_DIR}/${task}"

	# Orchestrate
	cmd::orchestrate "$task"
}
