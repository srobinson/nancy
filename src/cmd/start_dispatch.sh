#!/usr/bin/env bash
# b_path:: src/cmd/start_dispatch.sh
# Mode dispatch and start loop lifecycle phases

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

_start_mode_uses_reviewer_agent() {
	case "${1:-}" in
	agent_issue_review | post_execution_review)
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
	planning)
		echo "agent_issue_review"
		;;
	*)
		echo "agent_issue_review"
		;;
	esac
}

_start_run_iteration() {
	local task="$1"
	local -n _project=$2
	local -n _worktree=$3
	local -n _runtime=$4
	local -n _iteration=$5
	local -n _turn=$6

	local create_status=0
	_start_create_issues_file "$task" "${_project[id]}" "${_project[identifier]}" "${_project[title]}" || create_status=$?
	if [[ $create_status -ne 0 ]]; then
		_turn["action"]="return"
		_turn["status"]=$create_status
		return 0
	fi

	local agent_role="${_NEXT_AGENT_ROLE:-}"
	local prompt_mode="${_NEXT_PROMPT_MODE:-execution}"
	local selection="${_NEXT_SELECTION:-{}}"
	local selection_has_issue="${_NEXT_SELECTION_HAS_ISSUE:-false}"

	if [[ "$prompt_mode" == "final_completion" ]]; then
		_start_handle_null_selection "$task" "${_project[id]}" "$prompt_mode" "$selection"
		_turn["action"]="return"
		_turn["status"]=$?
		return 0
	fi

	if [[ "$selection_has_issue" != "true" ]]; then
		local null_selection_status=0
		_start_handle_null_selection "$task" "${_project[id]}" "$prompt_mode" "$selection" || null_selection_status=$?
		case "$null_selection_status" in
		0)
			_turn["action"]="return"
			_turn["status"]=0
			;;
		2)
			_turn["action"]="pause"
			;;
		*)
			_turn["action"]="return"
			_turn["status"]=$null_selection_status
			;;
		esac
		return 0
	fi

	local active_agent_config_role="worker"
	local active_cli="${_runtime["worker_cli"]}"
	local active_sidecar_mode="worker"
	if [[ -n "$agent_role" ]]; then
		log::info "Agent role: ${agent_role}"
	fi
	if _start_mode_uses_reviewer_agent "$prompt_mode"; then
		if ! _start_has_reviewer_agent "$task"; then
			log::error "Mode $prompt_mode requires agents.reviewer.cli in .nancy/config.json"
			_turn["action"]="return"
			_turn["status"]=1
			return 0
		fi
		active_agent_config_role="reviewer"
		active_cli="${_runtime["reviewer_cli"]}"
		active_sidecar_mode="review"
	fi
	if ! deps::exists "$active_cli"; then
		log::error "Active CLI not found for $active_agent_config_role: $active_cli"
		_turn["action"]="return"
		_turn["status"]=1
		return 0
	fi

	comms::archive_all "$task" "worker"
	comms::archive_all "$task" "orchestrator"
	sidecar::clear_completion "$task" 2>/dev/null || true
	_iteration=$((_iteration + 1))

	local timestamp
	timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
	local session_id
	session_id=$(session::id "$task" "$_iteration")
	local session_file="${NANCY_CURRENT_TASK_DIR}/sessions/session_${timestamp}_iter${_iteration}.md"

	session::init "$task" "$_iteration"
	export NANCY_SESSION_ID="$session_id"

	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	log::info "Iteration #$_iteration - $(date)"
	log::info "Session: $session_id"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""

	local prompt
	if ! prompt=$(_start_render_worker_prompt "$task" "$session_id" "${_project[identifier]}" "${_project[title]}" \
		"${_project[description]}" "${_worktree[dir]}" "$agent_role" "$active_cli"); then
		_turn["action"]="return"
		_turn["status"]=1
		return 0
	fi
	echo "$prompt" >"$NANCY_CURRENT_TASK_DIR/PROMPT.${task}.md"

	local exit_code=0
	_start_run_worker_agent "$task" "$session_id" "$session_file" "$prompt" "$agent_role" "${_worktree[dir]}" \
		"$active_agent_config_role" "$active_sidecar_mode" || exit_code=$?

	_turn["action"]="epilogue"
	_turn["exit_code"]=$exit_code
	_turn["prompt_mode"]="$prompt_mode"
	_turn["session_id"]="$session_id"
}

_start_iteration_epilogue() {
	local task="$1"
	local -n _project=$2
	local -n _worktree=$3
	local -n _runtime=$4
	# shellcheck disable=SC2178
	local -n _turn=$5
	local iteration="$6"
	local stop_file="${NANCY_CURRENT_TASK_DIR}/STOP"
	local exit_code="${_turn["exit_code"]}"
	local prompt_mode="${_turn["prompt_mode"]}"
	local session_id="${_turn["session_id"]}"

	if [[ -f "$stop_file" ]]; then
		log::info "Stop requested. Exiting worker loop."
		rm -f "$stop_file"
		notify::stop_all_watchers "$task" 2>/dev/null || true
		return 0
	fi

	if [[ $exit_code -eq 0 ]]; then
		ui::success "Iteration #$iteration completed"
		comms::archive_all "$task" "worker"
		if _start_should_run_reviewer_after_worker "$prompt_mode" "$task"; then
			local reviewer_prompt_mode
			reviewer_prompt_mode=$(_start_reviewer_followup_mode "$prompt_mode")
			_start_reviewer_agent "$task" "$session_id" "$iteration" "${_project[identifier]}" "${_project[title]}" \
				"${_project[description]}" "${_worktree[dir]}" "${_runtime["reviewer_cli"]}" "$reviewer_prompt_mode" || return $?
		elif [[ "$prompt_mode" == "planning" ]]; then
			log::error "Planning mode requires agents.reviewer.cli in .nancy/config.json"
			return 1
		else
			_start_maybe_run_review_agent "$prompt_mode" "$task" "$session_id" "$iteration" \
				"${_project[identifier]}" "${_project[title]}" "${_worktree[dir]}" "${_runtime["reviewer_cli"]}"
		fi

		if task::is_complete "$task"; then
			echo ""
			ui::banner "🎉 Task Complete!" "$task"
			return 0
		fi
	else
		log::warn "Iteration #$iteration exited with code $exit_code"
	fi

	if [ "${NANCY_EXECUTION_MODE:-loop}" == "single-run" ]; then
		log::info "Single-run mode enabled. Exiting."
		return 0
	fi

	_start_wait_while_paused "$task"

	echo ""
	log::info "Starting next iteration in 2s..."
	comms::archive_all "$task" "worker"
	comms::archive_all "$task" "orchestrator"
	sleep 2
	return 2
}
