#!/usr/bin/env bash
# b_path:: src/cmd/go.sh
# Init + supervised worker session in one command
# ------------------------------------------------------------------------------

cmd::go() {
	local task="${1:-}"

	config::load

	if [[ ! -d "$NANCY_DIR" ]]; then
		log::warn "Nancy not initialized. Starting setup."
		cmd::setup || return 1
		config::load
	fi

	if ! config::has_agent_shape; then
		log::warn "Nancy config uses the legacy agent shape. Run setup to configure worker and reviewer agents."
		cmd::setup || return 1

		if ! config::has_agent_shape; then
			log::error "Nancy config still needs agents.worker and agents.reviewer. Run 'nancy setup' and reconfigure."
			return 1
		fi

		config::load
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

	# Start supervised worker session
	cmd::orchestrate "$task"
}
