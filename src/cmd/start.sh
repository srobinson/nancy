#!/usr/bin/env bash
# b_path:: src/cmd/start.sh
# Start the Nancy loop for a task
# ------------------------------------------------------------------------------

# Global for cleanup handler access
_NANCY_CURRENT_TASK=""
_NANCY_CURRENT_SIDECAR_SESSION=""

_start_cleanup() {
	echo ""
	log::warn "Interrupted. Stopping Nancy..."
	if [[ -n "$_NANCY_CURRENT_TASK" ]]; then
		sidecar::stop "$_NANCY_CURRENT_TASK" "$_NANCY_CURRENT_SIDECAR_SESSION" 2>/dev/null || true
		_NANCY_CURRENT_SIDECAR_SESSION=""
		# Kill Claude subprocess first
		local pid_file="$NANCY_TASK_DIR/$_NANCY_CURRENT_TASK/.worker_pid"
			if [[ -f "$pid_file" ]]; then
				local worker_pid
				worker_pid=$(cat "$pid_file")
			if [[ -n "$worker_pid" ]] && kill -0 "$worker_pid" 2>/dev/null; then
				# SIGTERM first for graceful shutdown
				kill "$worker_pid" 2>/dev/null || true
				sleep 1
				# SIGKILL if still alive
				kill -0 "$worker_pid" 2>/dev/null && kill -9 "$worker_pid" 2>/dev/null || true
			fi
			rm -f "$pid_file"
			fi
			# Clean up sentinel
			rm -f "${NANCY_TASK_DIR}/${_NANCY_CURRENT_TASK}/STOP" 2>/dev/null || true
			sidecar::clear_completion "$_NANCY_CURRENT_TASK" 2>/dev/null || true
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
		echo -e " \tISSUE_ID\tTitle\tPriority\tState\tTags"
		echo "$sub_issues" | jq -r '.data.issues.nodes | sort_by(.subIssueSortOrder) | .[] |
			(. as $p |
				[
					(if $p.state.name == "Backlog" or $p.state.name == "Todo" or $p.state.name == "In Progress" then "[ ]" else "[X]" end),
					$p.identifier,
					$p.title,
					($p.priorityLabel // "-"),
					$p.state.name,
					([$p.labels.nodes[] | select(.parent.name == "Agent Role") | .name] | if length > 0 then join(", ") else "-" end)
				],
				(
					$p.children.nodes | sort_by(.subIssueSortOrder) | .[]? |
					[
						(if .state.name == "Backlog" or .state.name == "Todo" or .state.name == "In Progress" then "[ ]" else "[X]" end),
						("  ↳ " + .identifier),
						.title,
						(.priorityLabel // "-"),
						.state.name,
						([.labels.nodes[] | select(.parent.name == "Agent Role") | .name] | if length > 0 then join(", ") else "-" end)
					]
				)
			) | @tsv'
	} | column -t -s $'\t' >>"${NANCY_CURRENT_TASK_DIR}/ISSUES.md"

	# Extract agent role from first uncompleted issue (parent or child)
	# Walks sorted issues in order, finds first with incomplete state, returns its Agent Role label
	_NEXT_AGENT_ROLE=$(echo "$sub_issues" | jq -r '
		[.data.issues.nodes | sort_by(.subIssueSortOrder) | .[] |
			(. as $p |
				if ($p.state.name == "Backlog" or $p.state.name == "Todo" or $p.state.name == "In Progress") then
					([$p.labels.nodes[]? | select(.parent.name == "Agent Role") | .name] | .[0] // empty)
				else
					empty
				end
			),
			(
				.children.nodes | sort_by(.subIssueSortOrder) | .[]? |
				if (.state.name == "Backlog" or .state.name == "Todo" or .state.name == "In Progress") then
					([.labels.nodes[]? | select(.parent.name == "Agent Role") | .name] | .[0] // empty)
				else
					empty
				end
			)
		] | .[0] // ""
	')
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

		# copy .env && .env.* to worktree for environment variable access (e.g. API keys)
		shopt -s nullglob
		for env_file in "$main_repo_dir"/.env*; do
			cp -f "$env_file" "$worktree_dir/"
		done
		shopt -u nullglob

		# safe copy .fmm.db to worktree for database access
		if [ -f "$main_repo_dir/.fmm.db" ]; then
			cp -f "$main_repo_dir/.fmm.db" "$worktree_dir/"
		fi

	else
		log::info "Worktree already exists: $worktree_dir"
	fi

	_worktree_info[dir]="$worktree_dir"
	_worktree_info[main_repo]="$main_repo_dir"

	cd "$worktree_dir" || {
		log::error "Failed to cd into worktree"
		return 1
	}

	# Install dependencies if missing. Worktrees share git objects but not
	# node_modules, so the worker cannot typecheck without an install step.
	if [[ ! -d "$worktree_dir/node_modules" ]]; then
		if just --list 2>/dev/null | grep -q '^\s*install\b'; then
			log::info "Installing dependencies in worktree..."
			just install || log::warn "Dependency install failed (non-fatal)"
		fi
	fi

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
	local review_prompt_file_local="${NANCY_PROJECT_ROOT}/PROMPT.review.md"

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

	# Append project-local review prompt if present
	if [[ -f "$review_prompt_file_local" ]]; then
		log::info "Appending local review prompt: $review_prompt_file_local"
		review_prompt+=$'\n\n'
		review_prompt+=$(cat "$review_prompt_file_local")
	fi

	# Save rendered prompt
	echo "$review_prompt" >"$NANCY_CURRENT_TASK_DIR/PROMPT.review.md"

	# Run review agent
	local exit_code=0
	local review_agent_role=""
	local sidecar_log="$NANCY_CURRENT_TASK_DIR/logs/sidecar.log"
	local review_pane=""
	local review_sidecar_active=0
	local review_sidecar_session=""
	local review_uuid
	if cli::supports_agent_role; then
		review_agent_role="clinical-reviewer"
	fi

	sidecar::clear_completion "$task" 2>/dev/null || true
	review_uuid=$(uuid::generate)
	if [[ -n "${TMUX:-}" ]] && sidecar::enabled && cli::supports_sidecar; then
		review_pane="${TMUX_PANE:-}"
		if [[ -z "$review_pane" ]]; then
			review_pane=$(tmux display-message -p -t "${TMUX_PANE:-}" '#{session_name}:#{window_index}.#{pane_index}' 2>/dev/null || true)
		fi
		echo "[$(date -Iseconds)] preparing review sidecar spawn: TMUX=${TMUX:-<empty>} TMUX_PANE=${TMUX_PANE:-<empty>} uuid=$review_uuid" >>"$sidecar_log"
		echo "[$(date -Iseconds)] review sidecar candidate pane: ${review_pane:-<empty>}" >>"$sidecar_log"
		if sidecar::spawn_bg "$task" "$review_uuid" "$review_pane" "$worktree_dir" >>"$sidecar_log" 2>&1; then
			review_sidecar_active=1
			review_sidecar_session="${SIDECAR_LAST_SESSION_NAME:-}"
			echo "[$(date -Iseconds)] review sidecar spawn invoked: ${review_sidecar_session:-<unknown>}" >>"$sidecar_log"
		else
			echo "[$(date -Iseconds)] review sidecar spawn failed" >>"$sidecar_log"
		fi
	fi

	cli::run_review_prompt "$review_prompt" "$review_session_id" "$review_session_file" "$NANCY_CURRENT_TASK_DIR" "$review_agent_role" || exit_code=$?
	((review_sidecar_active == 1)) && sidecar::stop "$task" "$review_sidecar_session"
	if [[ $exit_code -ne 0 ]] && sidecar::completion_marked "$task"; then
		log::info "Review exit normalized to success after completion-driven rotation"
		exit_code=0
	fi
	sidecar::clear_completion "$task" 2>/dev/null || true

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

	# Store task globally for cleanup
	_NANCY_CURRENT_TASK="$task"
	export NANCY_CURRENT_TASK_DIR="${NANCY_TASK_DIR}/${task}"
	local stop_file="${NANCY_CURRENT_TASK_DIR}/STOP"

	# A previous run may have left behind a STOP sentinel. Clear it before
	# starting a fresh loop so stale manual stop requests do not terminate the
	# new worker immediately after its first successful rotation.
	rm -f "$stop_file" 2>/dev/null || true

	# Fetch Linear context
	declare -A project
	_start_fetch_linear_context "$task" project || return 1

	# Setup worktree
	declare -A worktree
	_start_setup_worktree "$task" worktree || return 1

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

		# Create ISSUES.md and detect agent role from first uncompleted issue
		_start_create_issues_file "$task" "${project[id]}" "${project[identifier]}" "${project[title]}"
		local agent_role="${_NEXT_AGENT_ROLE:-}"

		if [[ -n "$agent_role" ]]; then
			log::info "Agent role: ${agent_role}"
		fi

			# Archive stale directives from previous iterations so the
			# incoming worker session starts with an empty inbox.
			comms::archive_all "$task" "worker"
			comms::archive_all "$task" "orchestrator"
			sidecar::clear_completion "$task" 2>/dev/null || true
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

		# Build agent role section (empty if no role specified)
		local agent_role_section=""
		if [[ -n "$agent_role" ]]; then
			agent_role_section="## Agent Role Constraint

You have been assigned this task because you are a **\`${agent_role}\`** specialist. Other specialists are working in parallel on their own issues. The Tags column in ISSUES.md identifies which specialist owns each issue.

### Rules

1. **Sequence is critical.** Work on issues in the order they appear in ISSUES.md. Never skip ahead.
2. **Only work on issues tagged \`${agent_role}\`.** When the next issue in sequence is not tagged \`${agent_role}\`, you have reached the end of your current work. Write a handover commit and end your turn.
3. **The quality gate will discard unauthorized work.** Any changes to issues owned by another specialist will be automatically reverted. Do not attempt them.

When you reach an issue that belongs to another specialist:
1. Commit your progress with a detailed handover message
2. Send a progress message: \`nancy msg progress \"Completed [issues]. Next issue [ID] is owned by [role]. Handing off.\"\`
3. **End your session immediately.** Do NOT write to the COMPLETE file. Do NOT perform memory updates, cleanup, or any other work. Your final message must be your handoff summary.

The orchestrator will reassign you when your next issue is unblocked."
		fi

		# Render main prompt (direct substitution matching orchestrator pattern)
		local prompt=$(cat "${NANCY_FRAMEWORK_ROOT}/templates/PROMPT.md.template")
		prompt="${prompt//\{\{NANCY_PROJECT_ROOT\}\}/$NANCY_PROJECT_ROOT}"
		prompt="${prompt//\{\{NANCY_CURRENT_TASK_DIR\}\}/$NANCY_CURRENT_TASK_DIR}"
		prompt="${prompt//\{\{SESSION_ID\}\}/$session_id}"
		prompt="${prompt//\{\{TASK_NAME\}\}/$task}"
		prompt="${prompt//\{\{PROJECT_IDENTIFIER\}\}/${project[identifier]}}"
		prompt="${prompt//\{\{PROJECT_TITLE\}\}/${project[title]}}"
		local safe_description="${project[description]//&/\\&}"
		prompt="${prompt//\{\{PROJECT_DESCRIPTION\}\}/$safe_description}"
		prompt="${prompt//\{\{WORKTREE_DIR\}\}/${worktree[dir]}}"
		prompt="${prompt//\{\{AGENT_ROLE_SECTION\}\}/$agent_role_section}"

		# Append project-local prompt if present (e.g. project-specific rules)
		local prompt_file_local="${NANCY_PROJECT_ROOT}/PROMPT.md"
		if [[ -f "$prompt_file_local" ]]; then
			log::info "Appending local prompt: $prompt_file_local"
			prompt+=$'\n\n'
			prompt+=$(cat "$prompt_file_local")
		fi

		# Save rendered prompt
		echo "$prompt" >"$NANCY_CURRENT_TASK_DIR/PROMPT.${task}.md"

		local uuid
		uuid=$(uuid::generate)
		local sidecar_log="$NANCY_CURRENT_TASK_DIR/logs/sidecar.log"
		mkdir -p "$(dirname "$sidecar_log")"
		echo "[$(date -Iseconds)] preparing sidecar spawn: TMUX=${TMUX:-<empty>} TMUX_PANE=${TMUX_PANE:-<empty>} uuid=$uuid" >>"$sidecar_log"

		local worker_pane=""
		local sidecar_active=0
		local sidecar_session=""
		if [[ -n "${TMUX:-}" ]] && sidecar::enabled && cli::supports_sidecar; then
			worker_pane="${TMUX_PANE:-}"
			if [[ -z "$worker_pane" ]]; then
				worker_pane=$(tmux display-message -p -t "${TMUX_PANE:-}" '#{session_name}:#{window_index}.#{pane_index}' 2>/dev/null || true)
			fi
			echo "[$(date -Iseconds)] sidecar candidate pane: ${worker_pane:-<empty>}" >>"$sidecar_log"
			if sidecar::spawn_bg "$task" "$uuid" "$worker_pane" "${worktree[dir]}" >>"$sidecar_log" 2>&1; then
				sidecar_active=1
				sidecar_session="${SIDECAR_LAST_SESSION_NAME:-}"
				_NANCY_CURRENT_SIDECAR_SESSION="$sidecar_session"
				echo "[$(date -Iseconds)] sidecar spawn invoked: ${sidecar_session:-<unknown>}" >>"$sidecar_log"
			else
				echo "[$(date -Iseconds)] sidecar spawn failed" >>"$sidecar_log"
			fi
		else
			echo "[$(date -Iseconds)] sidecar skipped" >>"$sidecar_log"
		fi

		local exit_code=0
		local worker_agent_role=""
		if cli::supports_agent_role; then
			worker_agent_role="$agent_role"
		fi

			cli::run_prompt "$prompt" "$session_id" "$session_file" "$NANCY_CURRENT_TASK_DIR" "$worker_agent_role" "$uuid" || exit_code=$?

			((sidecar_active == 1)) && sidecar::stop "$task" "$sidecar_session"
			if [[ "$_NANCY_CURRENT_SIDECAR_SESSION" == "$sidecar_session" ]]; then
				_NANCY_CURRENT_SIDECAR_SESSION=""
			fi
			if [[ $exit_code -ne 0 ]] && sidecar::completion_marked "$task"; then
				log::info "Worker exit normalized to success after completion-driven rotation"
				exit_code=0
			fi
			sidecar::clear_completion "$task" 2>/dev/null || true

			# Check for stop sentinel (written by `nancy stop`)
			if [[ -f "$stop_file" ]]; then
				log::info "Stop requested. Exiting worker loop."
				rm -f "$stop_file"
			notify::stop_all_watchers "$task" 2>/dev/null || true
			return 0
		fi

		if [[ $exit_code -eq 0 ]]; then
			ui::success "Iteration #$iteration completed"

			# Run code review agent if enabled
			# Archive worker directives before review so the review agent
			# does not inherit stale guidance meant for the build agent.
			comms::archive_all "$task" "worker"
			if [ "${NANCY_CODE_REVIEW_AGENT_ENABLED:-false}" == "true" ] && cli::supports_review_agent; then
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
		# Archive any remaining worker messages before next iteration
		comms::archive_all "$task" "worker"
		comms::archive_all "$task" "orchestrator"
		sleep 2
	done
}
