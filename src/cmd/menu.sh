#!/usr/bin/env bash
# b_path:: src/cmd/menu.sh
# Default command - task menu
# ------------------------------------------------------------------------------

cmd::menu() {
	# Not initialized?
	if [[ ! -d "$NANCY_DIR" ]]; then
		ui::banner "🤖 Nancy" "Autonomous task execution"
		echo ""
		ui::muted "Nancy is not initialized in this directory."
		echo ""

		if ui::confirm "Run setup?"; then
			cmd::setup
			echo ""
			# After setup, prompt to create first task
			if ui::confirm "Create your first task?"; then
				local name
				name=$(ui::input "Task name")
				if [[ -n "$name" ]]; then
					cmd::init "$name"
				else
					# ESC pressed, go back to menu
					cmd::menu
				fi
			fi
		fi
		return 0
	fi

	config::load

	# Get tasks
	local tasks=()
	mapfile -t tasks < <(task::list)

	# No tasks?
	if [[ ${#tasks[@]} -eq 0 ]]; then
		ui::header "🤖 Nancy"
		ui::muted "No tasks found."
		echo ""

		if ui::confirm "Create a new task?"; then
			local name
			name=$(ui::input "Task name")
			if [[ -n "$name" ]]; then
				cmd::init "$name"
			else
				# ESC pressed, go back to menu
				cmd::menu
			fi
		fi
		return 0
	fi

	# Show task menu
	ui::header "🤖 Nancy"

	# Build menu options with status indicators
	local options=()
	for task in "${tasks[@]}"; do
		local status_icon=""
		local session_count
		session_count=$(task::count_sessions "$task")

		if task::is_complete "$task"; then
			status_icon="✓ "
		elif [[ "$session_count" -gt 0 ]]; then
			status_icon="▶ "
		fi

		options+=("${status_icon}${task} (${session_count} sessions)")
	done
	options+=("+ Create new task")
	options+=("✕ Quit")

	local choice
	choice=$(ui::choose_with_header "Select a task:" "${options[@]}")

	case "$choice" in
	"+ Create new task")
		local name
		name=$(ui::input "Task name")
		if [[ -n "$name" ]]; then
			cmd::init "$name"
		else
			# ESC pressed, go back to menu
			cmd::menu
		fi
		;;
	"✕ Quit")
		return 0
		;;
	*)
		# Extract task name (remove status icon and session count)
		local selected_task="${choice#✓ }"    # Remove complete icon
		selected_task="${selected_task#▶ }"   # Remove in-progress icon
		selected_task="${selected_task%% (*}" # Remove session count

		_menu_handle_task "$selected_task"
		;;
	esac
}

# Handle task selection based on state
_menu_handle_task() {
	local task="$1"
	local action
	local session_count
	session_count=$(task::count_sessions "$task")

	# Load task-specific config
	config::load_task "$task"

	if task::is_complete "$task"; then
		# Task is complete
		ui::muted "Task '$task' is complete."
		echo ""
		action=$(ui::choose_with_header "What would you like to do?" \
			"Review (interactive mode)" \
			"Reopen (remove COMPLETE marker)" \
			"Back")

		case "$action" in
		"Review (interactive mode)")
			_menu_start_interactive "$task"
			;;
		"Reopen (remove COMPLETE marker)")
			rm -f "$NANCY_TASK_DIR/$task/COMPLETE" || {
				log::error "Failed to remove COMPLETE marker."
				return 1
			}
			ui::success "Reopened task '$task'"
			_menu_handle_task "$task"
			;;
		"Back")
			cmd::menu
			;;
		esac

	elif [[ "$session_count" -gt 0 ]]; then
		# Task has sessions (in progress)
		ui::muted "Task '$task' is in progress ($session_count sessions)."
		echo ""
		action=$(ui::choose_with_header "What would you like to do?" \
			"Resume (autonomous mode)" \
			"Interactive mode" \
			"Back")

		case "$action" in
		"Resume (autonomous mode)")
			cmd::start "$task"
			;;
		"Interactive mode")
			_menu_start_interactive "$task"
			;;
		"Back")
			cmd::menu
			;;
		esac

	else
		# New task (no sessions)
		ui::muted "Task '$task' is new."
		echo ""
		_menu_start_interactive "$task"
	fi
}

# Start interactive mode for a task
_menu_start_interactive() {
	local task="$1"
	local NANCY_TASK_DIR="$NANCY_TASK_DIR/$task"
	local template_file="$NANCY_FRAMEWORK_ROOT/templates/task-init.md"
	local prompt

	prompt=$(sed -e "s|{{TASK_NAME}}|$task|g" \
		-e "s|{{NANCY_TASK_DIR}}|$NANCY_TASK_DIR|g" \
		"$template_file")

	echo "$prompt" >"$NANCY_TASK_DIR/START_PROMPT.md"

	log::info "Starting interactive session to define task..."
	echo ""
	cli::run_interactive "$prompt"
}
