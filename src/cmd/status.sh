#!/usr/bin/env bash
# b_path:: src/cmd/status.sh
# Show Nancy status
# ------------------------------------------------------------------------------

cmd::status() {
	if [[ ! -d "$NANCY_DIR" ]]; then
		ui::muted "Nancy not initialized in this directory."
		return 0
	fi

	ui::header "📊 Nancy Status"

	# Config info
	local cli
	cli=$(config::get '.cli.name' 'unknown')
	local model
	model=$(config::get '.cli.settings.model // .model' 'default')

	echo "CLI: $cli"
	echo "Model: $model"
	echo ""

	# Tasks
	local tasks=()
	mapfile -t tasks < <(task::list)

	if [[ ${#tasks[@]} -eq 0 ]]; then
		ui::muted "No tasks"
	else
		echo "Tasks:"
		for task in "${tasks[@]}"; do
			local count
			count=$(task::count_sessions "$task")
			local status="○"
			if task::is_complete "$task"; then
				status="●"
			fi
			echo "  $status $task ($count sessions)"
		done
	fi
}
