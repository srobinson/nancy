#!/usr/bin/env bash
# b_path:: src/cmd/start.sh
# Start the Nancy loop for a task
# ------------------------------------------------------------------------------

# Global for cleanup handler access
_NANCY_CURRENT_TASK=""
_NANCY_CURRENT_SIDECAR_SESSION=""
_NEXT_SELECTOR_PROMPT_CONTEXT=""
_NEXT_PROMPT_MODE="execution"
_NEXT_SELECTION=""

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
		read -r -d '' _project_data["id"]
		read -r -d '' _project_data["identifier"]
		read -r -d '' _project_data["title"]
		read -r -d '' _project_data["description"]
	} < <(jq -j '.data.issue |
		.id, "\u0000",
		.identifier, "\u0000",
		.title, "\u0000",
		.description, "\u0000"
	' <<<"$parent_issue")

	# Update Linear status
	linear::issue:update:status "${_project_data["id"]}" "In Progress"
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
	local sub_issue_statuses=$(
		linear::issue:sub:statuses "$project_id"
	)
	local selection
	selection=$(linear::selector:evaluate "$sub_issues" "$sub_issue_statuses")
	_start_validate_selector_output "$selection" || return 1

	cat <<EOF >"${NANCY_CURRENT_TASK_DIR}/ISSUES.md"
# [$project_identifier] $project_title

EOF
	linear::selector:render_summary "$selection" >>"${NANCY_CURRENT_TASK_DIR}/ISSUES.md"
	local row_jq
	row_jq='
		.data.issues.nodes | sort_by(.subIssueSortOrder) | .[] |
		(. as $p |
			[
				(if $p.state.name == "Backlog" or $p.state.name == "Todo" or $p.state.name == "In Progress" then "[ ]" else "[X]" end),
				$p.identifier,
				$p.title,
				($p.priorityLabel // "-"),
				$p.state.name
			],
			(
				$p.children.nodes | sort_by(.subIssueSortOrder) | .[]? |
				[
					(if .state.name == "Backlog" or .state.name == "Todo" or .state.name == "In Progress" then "[ ]" else "[X]" end),
					("  ↳ " + .identifier),
					.title,
					(.priorityLabel // "-"),
					.state.name
				]
			)
		) | @tsv'

	{
		echo '```text'
		echo -e " \tISSUE_ID\tTitle\tPriority\tState"
		echo "$sub_issues" | jq -r "$row_jq"
	} | column -t -s $'\t' >>"${NANCY_CURRENT_TASK_DIR}/ISSUES.md"
	echo '```' >>"${NANCY_CURRENT_TASK_DIR}/ISSUES.md"

	_NEXT_AGENT_ROLE=$(jq -r '.selected_issue.agent_role // ""' <<<"$selection")
	_NEXT_PROMPT_MODE=$(jq -r '.selected_mode // "execution"' <<<"$selection")
	_NEXT_SELECTOR_PROMPT_CONTEXT=$(linear::selector:render_prompt_context "$selection")
	_NEXT_SELECTION="$selection"
}

_start_validate_selector_output() {
	local selection="$1"

	if jq -e -s '
		length == 1
		and (.[0] | type == "object")
		and (.[0].selected_mode | type == "string")
		and (.[0] | has("selected_issue"))
	' >/dev/null 2>&1 <<<"$selection"; then
		return 0
	fi

	log::error "Linear selector returned invalid JSON. Refusing to launch an agent."
	return 1
}

_start_selection_has_no_issue() {
	local selection="$1"
	local has_no_issue

	if ! has_no_issue=$(jq -er 'if .selected_issue == null then "true" else "false" end' 2>/dev/null <<<"$selection"); then
		log::error "Linear selector JSON became invalid before null selection check. Refusing to launch an agent."
		return 2
	fi

	[[ "$has_no_issue" == "true" ]]
}

_start_handle_null_selection() {
	local task="$1"
	local project_id="$2"
	local prompt_mode="$3"
	local selection="$4"

	case "$prompt_mode" in
	final_completion)
		log::info "No eligible Linear issue remains. Closing task from selector final completion."
		linear::issue:update:status "$project_id" "Worker Done"
		task::mark_complete "$task"
		echo ""
		ui::banner "🎉 Task Complete!" "$task"
		return 0
		;;
	needs_human_direction)
		linear::selector:render_blocker "$selection"
		mkdir -p "${NANCY_TASK_DIR}/${task}"
		cat >"${NANCY_TASK_DIR}/${task}/PAUSE" <<EOF
Paused at $(date -u +"%Y-%m-%dT%H:%M:%SZ")
Reason: Needs human direction
EOF
		return 2
		;;
	*)
		log::error "No eligible Linear issue selected. Refusing to launch an agent without selected work."
		linear::selector:render_summary "$selection" >&2
		return 1
		;;
	esac
}

_start_wait_while_paused() {
	local task="$1"
	local pause_lock="${NANCY_TASK_DIR}/${task}/PAUSE"

	if [ ! -f "$pause_lock" ]; then
		return 0
	fi

	echo ""
	log::info "Paused for human direction."
	ui::muted "Waiting for unpause... (Ctrl+C to stop)"

	while [ -f "$pause_lock" ]; do
		sleep 2
	done

	echo ""
	log::info "Resuming after human direction."
}

_start_clear_stale_sentinels() {
	local task="$1"
	local task_dir="${NANCY_TASK_DIR}/${task}"

	rm -f "${task_dir}/STOP" "${task_dir}/COMPLETE" 2>/dev/null || true
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

_start_is_gate_aware_prompt_mode() {
	case "${1:-}" in
	planning | agent_issue_review | execution | corrective_resolution | post_execution_review | needs_human_direction)
		return 0
		;;
	*)
		return 1
		;;
	esac
}

_start_should_run_review_agent_for_mode() {
	local mode="${1:-}"

	[[ "${NANCY_CODE_REVIEW_AGENT_ENABLED:-false}" == "true" ]] || return 1
	[[ "${NANCY_LEGACY_LOCAL_REVIEW_ENABLED:-false}" == "true" ]] || return 1
	[[ "$mode" == "legacy_local_hygiene" ]] || return 1
	! _start_is_gate_aware_prompt_mode "$mode"
}

_start_has_reviewer_agent() {
	local task="$1"
	local task_config=""
	local reviewer_cli=""

	if [[ -n "$task" ]]; then
		task_config="$NANCY_TASK_DIR/$task/config.json"
	fi

	reviewer_cli=$(config::_agent_key_from_file "$NANCY_CONFIG_FILE" "reviewer" "cli")
	if [[ -z "$reviewer_cli" && -n "$task_config" && -f "$task_config" ]]; then
		reviewer_cli=$(config::_agent_key_from_file "$task_config" "reviewer" "cli")
	fi

	[[ -n "$reviewer_cli" ]]
}

_start_mode_uses_reviewer_agent() {
	case "${1:-}" in
	agent_issue_review)
		return 0
		;;
	*)
		return 1
		;;
	esac
}

_start_should_run_reviewer_after_worker() {
	local mode="${1:-}"
	local task="$2"

	_start_has_reviewer_agent "$task" || return 1

	case "$mode" in
	planning)
		return 0
		;;
	*)
		return 1
		;;
	esac
}

_start_reviewer_followup_mode() {
	case "${1:-}" in
	post_execution_review)
		echo "post_execution_review"
		;;
	*)
		echo "agent_issue_review"
		;;
	esac
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
		if sidecar::spawn_bg "$task" "$review_uuid" "$review_pane" "$worktree_dir" "review" >>"$sidecar_log" 2>&1; then
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

_start_maybe_run_review_agent() {
	local mode="$1"
	local task="$2"
	local session_id="$3"
	local iteration="$4"
	local project_identifier="$5"
	local project_title="$6"
	local worktree_dir="$7"
	local reviewer_cli="$8"

	if ! _start_should_run_review_agent_for_mode "$mode"; then
		if [[ "${NANCY_CODE_REVIEW_AGENT_ENABLED:-false}" == "true" ]] && _start_is_gate_aware_prompt_mode "$mode"; then
			log::info "Legacy code review hook skipped for gate aware mode: $mode"
		fi
		return 0
	fi

	if ! deps::exists "$reviewer_cli"; then
		log::warn "Code review skipped because reviewer CLI was not found: $reviewer_cli"
	elif config::with_agent_env "$task" "reviewer" cli::supports_review_agent; then
		config::with_agent_env "$task" "reviewer" _start_run_review_agent "$task" "$session_id" "$iteration" \
			"$project_identifier" "$project_title" "$worktree_dir"
	else
		log::info "Code review skipped because reviewer CLI does not support review agent mode: $reviewer_cli"
	fi
}

_start_agent_role_section() {
	local agent_role="$1"

	if [[ -z "$agent_role" ]]; then
		return 0
	fi

	cat <<'EOF'
## Agent Recycling Rules

1. Only work on one issue at a time. Once complete, end your turn

The orchestrator will assign the next issue.
EOF
}

_start_turn_exit_instruction() {
	local worker_cli="${1:-}"

	case "$worker_cli" in
	claude | claude-code)
		cat <<'EOF'

## Turn Exit

When your mode action is complete, print one line with no surrounding text.

That line must contain a backtick, then an opening angle bracket, then `END_TURN`, then a closing angle bracket, then a backtick.

This instruction also applies after any skill runs. If a skill confirmation step says to report only a file path or final status, do that first, then print the required turn exit line.
EOF
		;;
	*)
		cat <<'EOF'

## Turn Exit

When your mode action is complete, print one line with no surrounding text.

That line must contain an opening angle bracket, then `END_TURN`, then a closing angle bracket.

This instruction also applies after any skill runs. If a skill confirmation step says to report only a file path or final status, do that first, then print the required turn exit line.
EOF
		;;
	esac
}

_start_prompt_replacement() {
	local value="$1"
	value="${value//&/\\&}"
	printf '%s' "$value"
}

_start_render_worker_prompt() {
	local task="$1"
	local session_id="$2"
	local project_identifier="$3"
	local project_title="$4"
	local project_description="$5"
	local worktree_dir="$6"
	local agent_role="$7"
	local worker_cli="${8:-$(cli::current)}"

	local agent_role_section
	agent_role_section=$(_start_agent_role_section "$agent_role")

	local prompt
	prompt=$(cat "${NANCY_FRAMEWORK_ROOT}/templates/PROMPT.md.template")
	local mode_instructions
	mode_instructions=$(prompt::mode_instructions "${_NEXT_PROMPT_MODE:-execution}") || return 1
	prompt="${prompt//\{\{MODE_INSTRUCTIONS_SECTION\}\}/$(_start_prompt_replacement "$mode_instructions")}"
	prompt="${prompt//\{\{NANCY_PROJECT_ROOT\}\}/$(_start_prompt_replacement "$NANCY_PROJECT_ROOT")}"
	prompt="${prompt//\{\{NANCY_CURRENT_TASK_DIR\}\}/$(_start_prompt_replacement "$NANCY_CURRENT_TASK_DIR")}"
	prompt="${prompt//\{\{SESSION_ID\}\}/$(_start_prompt_replacement "$session_id")}"
	prompt="${prompt//\{\{TASK_NAME\}\}/$(_start_prompt_replacement "$task")}"
	prompt="${prompt//\{\{PROJECT_IDENTIFIER\}\}/$(_start_prompt_replacement "$project_identifier")}"
	prompt="${prompt//\{\{PROJECT_TITLE\}\}/$(_start_prompt_replacement "$project_title")}"
	prompt="${prompt//\{\{PROJECT_DESCRIPTION\}\}/$(_start_prompt_replacement "$project_description")}"
	prompt="${prompt//\{\{WORKTREE_DIR\}\}/$(_start_prompt_replacement "$worktree_dir")}"
	prompt="${prompt//\{\{AGENT_ROLE_SECTION\}\}/$(_start_prompt_replacement "$agent_role_section")}"
	prompt="${prompt//\{\{SELECTED_WORK_SECTION\}\}/$(_start_prompt_replacement "$_NEXT_SELECTOR_PROMPT_CONTEXT")}"

	local prompt_file_local="${NANCY_PROJECT_ROOT}/PROMPT.md"
	if [[ -f "$prompt_file_local" ]]; then
		log::info "Appending local prompt: $prompt_file_local" >&2
		prompt+=$'\n\n'
		prompt+=$(cat "$prompt_file_local")
	fi
	prompt+=$(_start_turn_exit_instruction "$worker_cli")

	printf '%s\n' "$prompt"
}

_start_print_start_info() {
	local task="$1"
	local worker_cli="$2"
	local worker_model="$3"
	local reviewer_cli="$4"
	local reviewer_model="$5"

	ui::header "🔄 Starting Nancy: $task"
	log::info "Worker CLI: ${worker_cli}${worker_model:+ ($worker_model)}"
	if [[ "${NANCY_CODE_REVIEW_AGENT_ENABLED:-false}" == "true" ]]; then
		log::info "Reviewer CLI: ${reviewer_cli}${reviewer_model:+ ($reviewer_model)}"
	fi
	log::info "Press Ctrl+C to stop"
	echo ""
}

_start_run_worker_agent() {
	local task="$1"
	local session_id="$2"
	local session_file="$3"
	local prompt="$4"
	local agent_role="$5"
	local worktree_dir="$6"
	local agent_config_role="${7:-worker}"
	local sidecar_mode="${8:-worker}"

	local uuid
	uuid=$(uuid::generate)
	local sidecar_log="$NANCY_CURRENT_TASK_DIR/logs/sidecar.log"
	mkdir -p "$(dirname "$sidecar_log")"
	echo "[$(date -Iseconds)] preparing sidecar spawn: TMUX=${TMUX:-<empty>} TMUX_PANE=${TMUX_PANE:-<empty>} uuid=$uuid" >>"$sidecar_log"

	local worker_pane=""
	local sidecar_active=0
	local sidecar_session=""
	if [[ -n "${TMUX:-}" ]] && sidecar::enabled && config::with_agent_env "$task" "$agent_config_role" cli::supports_sidecar; then
		worker_pane="${TMUX_PANE:-}"
		if [[ -z "$worker_pane" ]]; then
			worker_pane=$(tmux display-message -p -t "${TMUX_PANE:-}" '#{session_name}:#{window_index}.#{pane_index}' 2>/dev/null || true)
		fi
		echo "[$(date -Iseconds)] sidecar candidate pane: ${worker_pane:-<empty>}" >>"$sidecar_log"
		if sidecar::spawn_bg "$task" "$uuid" "$worker_pane" "$worktree_dir" "$sidecar_mode" >>"$sidecar_log" 2>&1; then
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
	if config::with_agent_env "$task" "$agent_config_role" cli::supports_agent_role; then
		worker_agent_role="$agent_role"
	fi

	config::with_agent_env "$task" "$agent_config_role" cli::run_prompt "$prompt" "$session_id" "$session_file" "$NANCY_CURRENT_TASK_DIR" "$worker_agent_role" "$uuid" || exit_code=$?

	((sidecar_active == 1)) && sidecar::stop "$task" "$sidecar_session"
	if [[ "$_NANCY_CURRENT_SIDECAR_SESSION" == "$sidecar_session" ]]; then
		_NANCY_CURRENT_SIDECAR_SESSION=""
	fi
	if [[ $exit_code -ne 0 ]] && sidecar::completion_marked "$task"; then
		log::info "Worker exit normalized to success after completion-driven rotation"
		exit_code=0
	fi
	sidecar::clear_completion "$task" 2>/dev/null || true

	return $exit_code
}

_start_reviewer_agent() {
	local task="$1"
	local session_id="$2"
	local iteration="$3"
	local project_identifier="$4"
	local project_title="$5"
	local project_description="$6"
	local worktree_dir="$7"
	local reviewer_cli="$8"
	local prompt_mode="${9:-agent_issue_review}"

	if ! _start_has_reviewer_agent "$task"; then
		log::error "Workflow reviewer required, but agents.reviewer.cli is not configured in .nancy/config.json"
		return 1
	fi

	if ! deps::exists "$reviewer_cli"; then
		log::error "Workflow reviewer CLI not found: $reviewer_cli"
		return 1
	fi

	local old_prompt_mode="${_NEXT_PROMPT_MODE:-execution}"
	local reviewer_session_id="${session_id}-reviewer"
	local timestamp
	timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
	local reviewer_session_file="${NANCY_CURRENT_TASK_DIR}/sessions/session_${timestamp}_iter${iteration}-reviewer.md"
	local prompt

	_NEXT_PROMPT_MODE="$prompt_mode"
	prompt=$(_start_render_worker_prompt "$task" "$reviewer_session_id" "$project_identifier" "$project_title" \
		"$project_description" "$worktree_dir" "" "$reviewer_cli")
	local render_status=$?
	_NEXT_PROMPT_MODE="$old_prompt_mode"
	[[ $render_status -eq 0 ]] || return "$render_status"

	echo "$prompt" >"$NANCY_CURRENT_TASK_DIR/PROMPT.${task}.reviewer.md"

	log::info "Running workflow reviewer: ${reviewer_cli} (${prompt_mode})"
	_start_run_worker_agent "$task" "$reviewer_session_id" "$reviewer_session_file" "$prompt" "" "$worktree_dir" "reviewer" "review"
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

	# A previous run may have left behind local sentinels. Clear them before
	# starting a fresh loop; selector final_completion recreates COMPLETE when
	# the current Linear state is truly terminal.
	_start_clear_stale_sentinels "$task"

	# Fetch Linear context
	declare -A project
	_start_fetch_linear_context "$task" project || return 1

	# Setup worktree
	declare -A worktree
	_start_setup_worktree "$task" worktree || return 1

	# Setup signal handler
	trap _start_cleanup SIGINT SIGTERM

	local worker_cli
	local worker_model
	local reviewer_cli
	local reviewer_model
	worker_cli=$(config::get_agent "$task" "worker" "cli" "$(cli::current)")
	worker_model=$(config::get_agent "$task" "worker" "model" "${NANCY_MODEL:-}")
	reviewer_cli=$(config::get_agent "$task" "reviewer" "cli" "$worker_cli")
	reviewer_model=$(config::get_agent "$task" "reviewer" "model" "$worker_model")

	if ! deps::exists "$worker_cli"; then
		log::error "Worker CLI not found: $worker_cli"
		return 1
	fi

	_start_print_start_info "$task" "$worker_cli" "$worker_model" "$reviewer_cli" "$reviewer_model"

	# Main iteration loop
	local iteration=$(task::count_sessions "$task")

	while :; do

		# Create ISSUES.md and detect agent role from first uncompleted issue
		_start_create_issues_file "$task" "${project[id]}" "${project[identifier]}" "${project[title]}"
		local agent_role="${_NEXT_AGENT_ROLE:-}"
		local prompt_mode="${_NEXT_PROMPT_MODE:-execution}"
		local selection="${_NEXT_SELECTION:-{}}"
		local active_agent_config_role="worker"
		local active_cli="$worker_cli"
		local active_sidecar_mode="worker"

		if [[ "$prompt_mode" == "final_completion" ]]; then
			_start_handle_null_selection "$task" "${project[id]}" "$prompt_mode" "$selection"
			return $?
		fi

		local no_issue_status=0
		_start_selection_has_no_issue "$selection" || no_issue_status=$?
		case "$no_issue_status" in
		0)
			local null_selection_status=0
			_start_handle_null_selection "$task" "${project[id]}" "$prompt_mode" "$selection" || null_selection_status=$?
			case "$null_selection_status" in
			0)
				return 0
				;;
			2)
				_start_wait_while_paused "$task"
				continue
				;;
			*)
				return "$null_selection_status"
				;;
			esac
			;;
		1)
			;;
		*)
			return "$no_issue_status"
			;;
		esac

		if [[ -n "$agent_role" ]]; then
			log::info "Agent role: ${agent_role}"
		fi
		if _start_mode_uses_reviewer_agent "$prompt_mode"; then
			if ! _start_has_reviewer_agent "$task"; then
				log::error "Mode $prompt_mode requires agents.reviewer.cli in .nancy/config.json"
				return 1
			fi
			active_agent_config_role="reviewer"
			active_cli="$reviewer_cli"
			active_sidecar_mode="review"
		fi
		if ! deps::exists "$active_cli"; then
			log::error "Active CLI not found for $active_agent_config_role: $active_cli"
			return 1
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

		local prompt
		prompt=$(_start_render_worker_prompt "$task" "$session_id" "${project[identifier]}" "${project[title]}" \
			"${project[description]}" "${worktree[dir]}" "$agent_role" "$active_cli") || return 1

		# Save rendered prompt
		echo "$prompt" >"$NANCY_CURRENT_TASK_DIR/PROMPT.${task}.md"

		local exit_code=0
		_start_run_worker_agent "$task" "$session_id" "$session_file" "$prompt" "$agent_role" "${worktree[dir]}" \
			"$active_agent_config_role" "$active_sidecar_mode" || exit_code=$?

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
			if _start_should_run_reviewer_after_worker "$prompt_mode" "$task"; then
				local reviewer_prompt_mode
				reviewer_prompt_mode=$(_start_reviewer_followup_mode "$prompt_mode")
				_start_reviewer_agent "$task" "$session_id" "$iteration" "${project[identifier]}" "${project[title]}" \
					"${project[description]}" "${worktree[dir]}" "$reviewer_cli" "$reviewer_prompt_mode" || return $?
			elif [[ "$prompt_mode" == "planning" ]]; then
				log::error "Planning mode requires agents.reviewer.cli in .nancy/config.json"
				return 1
			else
				_start_maybe_run_review_agent "$prompt_mode" "$task" "$session_id" "$iteration" \
					"${project[identifier]}" "${project[title]}" "${worktree[dir]}" "$reviewer_cli"
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
		_start_wait_while_paused "$task"

		echo ""
		log::info "Starting next iteration in 2s..."
		# Archive any remaining worker messages before next iteration
		comms::archive_all "$task" "worker"
		comms::archive_all "$task" "orchestrator"
		sleep 2
	done
}
