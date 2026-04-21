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
	local worker_cli worker_model reviewer_cli reviewer_model
	worker_cli=$(config::get_agent "" "worker" "cli" "unknown")
	worker_model=$(config::get_agent "" "worker" "model" "default")
	reviewer_cli=$(config::get_agent "" "reviewer" "cli" "$worker_cli")
	reviewer_model=$(config::get_agent "" "reviewer" "model" "$worker_model")

	echo "Worker CLI: $worker_cli"
	echo "Worker model: $worker_model"
	echo "Reviewer CLI: $reviewer_cli"
	echo "Reviewer model: $reviewer_model"
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
