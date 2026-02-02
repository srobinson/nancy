#!/usr/bin/env bash
# b_path:: src/cmd/init.sh
# Create a new task
# ------------------------------------------------------------------------------

cmd::init() {
	local task="${1:-}"

	config::load

	# Ensure nancy is initialized
	if [[ ! -d "$NANCY_DIR" ]]; then
		log::error "Nancy not initialized. Run 'nancy setup' first."
		return 1
	fi

	# Get task name if not provided
	if [[ -z "$task" ]]; then
		task=$(ui::input "Task name")
		[[ -z "$task" ]] && return 1
	fi

	# Validate
	if ! task::validate_name "$task"; then
		return 1
	fi

	# Check if exists
	if task::exists "$task"; then
		log::error "Task '$task' already exists."
		return 1
	fi

	ui::header "Creating task: $task"

	# Create task structure
	task::create "$task"

	local NEW_NANCY_TASK_DIR="$NANCY_TASK_DIR/$task"

	# Set the current task directory
	export NANCY_CURRENT_TASK_DIR="$NEW_NANCY_TASK_DIR"

	ui::success "Created ${NEW_NANCY_TASK_DIR}"
	echo ""

	# Load and render the task-init template
	local template_file="$NANCY_FRAMEWORK_ROOT/templates/task-init.md"
	local prompt
	prompt=$(sed -e "s|{{TASK_NAME}}|$task|g" \
		-e "s|{{NANCY_TASK_DIR}}|$NEW_NANCY_TASK_DIR|g" \
		"$template_file")

	log::info "Starting interactive session to define task..."
	echo "$prompt" >"$NEW_NANCY_TASK_DIR/INIT_PROMPT.md"
	echo ""

	# Start interactive CLI with the init prompt
	cli::run_interactive "$prompt"
}
