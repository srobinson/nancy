#!/usr/bin/env bash
# b_path:: src/cmd/start.sh
# Start the Nancy loop for a task
# ------------------------------------------------------------------------------

# Global for cleanup handler access
_NANCY_CURRENT_TASK=""

_start_cleanup() {
	echo ""
	log::warn "Interrupted. Stopping Nancy..."
	# Stop any running watchers for the current task
	if [[ -n "$_NANCY_CURRENT_TASK" ]]; then
		notify::stop_all_watchers "$_NANCY_CURRENT_TASK" 2>/dev/null || true
	fi
	exit 0
}

# Helper: Fetch Linear issue context
_start_fetch_linear_context() {
	local task="$1"
	local -n _project_data=$2 # nameref to associative array

	local parent_issue=$(
		linear::issue "$task"
	)

	if ! echo "$parent_issue" | jq -e '.data.issue | length > 0' >/dev/null; then
		log::error "No issues found for Task: $task"
		return 1
	fi

	{
		read -r -d '' _project_data[id]
		read -r -d '' _project_data[identifier]
		read -r -d '' _project_data[title]
		read -r -d '' _project_data[description]
	} < <(jq -j '.data.issue |
		.id, "\u0000",
		.identifier, "\u0000",
		.title, "\u0000",
		.description, "\u0000"
	' <<<"$parent_issue")

	# Update Linear status
	linear::issue:update:status "${_project_data[id]}" "In Progress"
}

# Helper: Create ISSUES.md file
_start_create_issues_file() {
	local task="$1"
	local project_id="$2"
	local project_identifier="$3"
	local project_title="$4"

	local sub_issues=$(
		linear::issue:sub "$project_id"
	)

	cat <<EOF >"${NANCY_CURRENT_TASK_DIR}/ISSUES.md"
# [$project_identifier] $project_title

EOF

	{
		echo -e " \tISSUE_ID\tTitle\tPriority\tState"
		echo "$sub_issues" | jq -r '.data.issues.nodes | reverse |
			.[] |
			[
				(if .state.name == "Backlog" or .state.name == "Todo" or .state.name == "In Progress" then "[ ]" else "[X]" end),
				.identifier,
				.title,
				.priorityLabel // "-",
				.state.name
			] | @tsv'
	} | column -t -s $'\t' >>"${NANCY_CURRENT_TASK_DIR}/ISSUES.md"
}

# Helper: Setup git worktree
_start_setup_worktree() {
	local task="$1"
	local -n _worktree_info=$2 # nameref to associative array

	local main_repo_dir=$(git rev-parse --show-toplevel)
	local main_repo_name=$(basename "$main_repo_dir")
	local parent_dir=$(dirname "$main_repo_dir")
	local worktree_dir="${parent_dir}/${main_repo_name}-worktrees/nancy-${task}"

	if [ ! -d "$worktree_dir" ]; then
		log::info "Creating worktree: $worktree_dir"
		git fetch
		# git rebase origin/main || log::fatal "Failed to rebase main repository"
		git worktree add "$worktree_dir" -b "nancy/$task" 2>/dev/null ||
			git worktree add "$worktree_dir" "nancy/$task"
	fi

	cd "$worktree_dir" || {
		log::error "Failed to cd into worktree"
		return 1
	}

	_worktree_info[dir]="$worktree_dir"
	_worktree_info[main_repo]="$main_repo_dir"

	log::info "Working in worktree: $(pwd)"
}

# Helper: Run code review agent
_start_run_review_agent() {
	local task="$1"
	local session_id="$2"
	local iteration="$3"
	local project_identifier="$4"
	local project_title="$5"
	local worktree_dir="$6"

	local timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
	local review_session_id="${session_id}-review"
	local review_session_file="${NANCY_CURRENT_TASK_DIR}/sessions/session_${timestamp}_iter${iteration}-review.md"
	local review_prompt_file="${NANCY_FRAMEWORK_ROOT}/templates/REVIEW.md.template"

	log::info "🔍 Running Code Review Agent..."

	# reset token tracking for review agent
	token::reset "$task"

	# Get recent git log for context
	local git_log=$(git log --format=full -5 2>/dev/null || echo "No commits yet")

	# Load template and substitute variables (matching orchestrator pattern)
	local review_prompt=$(cat "$review_prompt_file")
	review_prompt="${review_prompt//\{\{SESSION_ID\}\}/$session_id}"
	review_prompt="${review_prompt//\{\{ITERATION\}\}/$iteration}"
	review_prompt="${review_prompt//\{\{TASK_NAME\}\}/$task}"
	review_prompt="${review_prompt//\{\{PROJECT_IDENTIFIER\}\}/$project_identifier}"
	review_prompt="${review_prompt//\{\{PROJECT_TITLE\}\}/$project_title}"
	review_prompt="${review_prompt//\{\{NANCY_CURRENT_TASK_DIR\}\}/$NANCY_CURRENT_TASK_DIR}"
	review_prompt="${review_prompt//\{\{WORKTREE_DIR\}\}/$worktree_dir}"
	review_prompt="${review_prompt//\{\{GIT_LOG\}\}/$git_log}"

	# Save rendered prompt
	echo "$review_prompt" >"$NANCY_CURRENT_TASK_DIR/PROMPT.review.md"

	# Run review agent
	local exit_code=0
	cli::run_prompt "$review_prompt" "$review_session_id" "$review_session_file" "$NANCY_CURRENT_TASK_DIR" || exit_code=$?

	if [[ $exit_code -eq 0 ]]; then
		ui::success "Code review completed"
	else
		log::warn "Code review exited with code $exit_code"
	fi

	return $exit_code
}

cmd::start() {
	local task="${1:-}"

	# Validate nancy is initialized
	if [[ ! -d "$NANCY_DIR" ]]; then
		log::error "Nancy not initialized. Run 'nancy setup' first."
		return 1
	fi

	# Fetch Linear context
	declare -A project
	_start_fetch_linear_context "$task" project || return 1

	# Create ISSUES.md
	_start_create_issues_file "$task" "${project[id]}" "${project[identifier]}" "${project[title]}"

	# Setup worktree
	declare -A worktree
	_start_setup_worktree "$task" worktree || return 1

	# Store task globally for cleanup
	_NANCY_CURRENT_TASK="$task"
	export NANCY_CURRENT_TASK_DIR="${NANCY_TASK_DIR}/${task}"

	# Setup signal handler
	trap _start_cleanup SIGINT SIGTERM

	# Show start info
	ui::header "🔄 Starting Nancy: $task"
	log::info "CLI: $(cli::current) $(cli::version)"
	log::info "Press Ctrl+C to stop"
	echo ""

	# Main iteration loop
	local iteration=$(task::count_sessions "$task")

	while :; do
		iteration=$((iteration + 1))
		local timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
		local session_id=$(session::id "$task" "$iteration")
		local session_file="${NANCY_CURRENT_TASK_DIR}/sessions/session_${timestamp}_iter${iteration}.md"

		session::init "$task" "$iteration"
		export NANCY_SESSION_ID="$session_id"

		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
		log::info "Iteration #$iteration - $(date)"
		log::info "Session: $session_id"
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
		echo ""

		# Render main prompt (direct substitution matching orchestrator pattern)
		local prompt=$(cat "${NANCY_FRAMEWORK_ROOT}/templates/PROMPT.md.template")
		prompt="${prompt//\{\{NANCY_PROJECT_ROOT\}\}/$NANCY_PROJECT_ROOT}"
		prompt="${prompt//\{\{NANCY_CURRENT_TASK_DIR\}\}/$NANCY_CURRENT_TASK_DIR}"
		prompt="${prompt//\{\{SESSION_ID\}\}/$session_id}"
		prompt="${prompt//\{\{TASK_NAME\}\}/$task}"
		prompt="${prompt//\{\{PROJECT_IDENTIFIER\}\}/${project[identifier]}}"
		prompt="${prompt//\{\{PROJECT_TITLE\}\}/${project[title]}}"
		prompt="${prompt//\{\{PROJECT_DESCRIPTION\}\}/${project[description]}}"
		prompt="${prompt//\{\{WORKTREE_DIR\}\}/${worktree[dir]}}"

		# Save rendered prompt
		echo "$prompt" >"$NANCY_CURRENT_TASK_DIR/PROMPT.${task}.md"

		notify::watch_tokens_bg "$task" "$iteration"

		local exit_code=0
		cli::run_prompt "$prompt" "$session_id" "$session_file" "$NANCY_CURRENT_TASK_DIR" || exit_code=$?

		notify::stop_token_watcher "$task"

		if [[ $exit_code -eq 0 ]]; then
			ui::success "Iteration #$iteration completed"

			# Run code review agent if enabled
			if [ "${NANCY_CODE_REVIEW_AGENT_ENABLED:-false}" == "true" ]; then
				_start_run_review_agent "$task" "$session_id" "$iteration" \
					"${project[identifier]}" "${project[title]}" "${worktree[dir]}"
			fi

			# Check for completion
			if task::is_complete "$task"; then
				echo ""
				ui::banner "🎉 Task Complete!" "$task"
				return 0
			fi
		else
			log::warn "Iteration #$iteration exited with code $exit_code"
		fi

		# Single-run mode check
		if [ "${NANCY_EXECUTION_MODE:-loop}" == "single-run" ]; then
			log::info "Single-run mode enabled. Exiting."
			return 0
		fi

		# Pause check
		local pause_lock="${NANCY_CURRENT_TASK_DIR}/PAUSE"
		if [ -f "$pause_lock" ]; then
			echo ""
			log::info "⏸️  Paused (lock file detected)"
			ui::muted "Waiting for unpause... (Ctrl+C to stop)"

			while [ -f "$pause_lock" ]; do
				sleep 2
			done

			echo ""
			log::info "▶️  Resuming..."
		fi

		echo ""
		log::info "Starting next iteration in 2s..."
		sleep 2
	done
}
