#!/usr/bin/env bash
# b_path:: src/sidecar/sidecar.sh
# Interactive worker sidecar for tmux-based context observation
# ------------------------------------------------------------------------------

sidecar::enabled() {
	[[ "${NANCY_SIDECAR_MODE:-1}" == "1" ]]
}

sidecar::session_file() {
	local task="$1"
	echo "$NANCY_TASK_DIR/$task/.sidecar_session"
}

sidecar::safe_fragment() {
	local value="$1"

	value=$(printf '%s' "$value" | tr -c '[:alnum:]._-' '_')
	value=${value#_}
	value=${value%_}

	if [[ -z "$value" ]]; then
		echo "unknown"
	else
		echo "$value"
	fi
}

sidecar::canonical_worker_target() {
	local worker_pane="$1"
	local canonical_target

	[[ -z "$worker_pane" ]] && return 1

	canonical_target=$(tmux display-message -p -t "$worker_pane" '#{session_name}:#{window_index}.#{pane_index}' 2>/dev/null || true)
	if [[ -n "$canonical_target" && "$canonical_target" != ":." ]]; then
		printf '%s\n' "$canonical_target"
	else
		printf '%s\n' "$worker_pane"
	fi
}

sidecar::session_name() {
	local task="$1"
	local worker_pane="$2"
	local uuid="$3"
	local pane_target pane_fragment uuid_fragment

	pane_target=$(sidecar::canonical_worker_target "$worker_pane" 2>/dev/null || printf '%s\n' "$worker_pane")
	pane_fragment=$(sidecar::safe_fragment "$pane_target")
	uuid_fragment=$(sidecar::safe_fragment "${uuid%%-*}")

	echo "sidecar-${task}-${pane_fragment}-${uuid_fragment}"
}

sidecar::remember_session() {
	local task="$1"
	local session_name="$2"
	local session_file

	[[ -z "$task" || -z "$session_name" ]] && return 1

	session_file=$(sidecar::session_file "$task")
	mkdir -p "$(dirname "$session_file")"
	printf '%s\n' "$session_name" >"$session_file"
}

sidecar::current_session_name() {
	local task="$1"
	local session_file

	[[ -z "$task" ]] && return 1

	session_file=$(sidecar::session_file "$task")
	[[ -f "$session_file" ]] || return 1

	cat "$session_file" 2>/dev/null
}

sidecar::clear_session() {
	local task="$1"
	local expected_session_name="${2:-}"
	local session_file recorded_session_name

	[[ -z "$task" ]] && return 1

	session_file=$(sidecar::session_file "$task")
	[[ -f "$session_file" ]] || return 0

	recorded_session_name=$(cat "$session_file" 2>/dev/null)
	if [[ -z "$expected_session_name" || "$recorded_session_name" == "$expected_session_name" ]]; then
		rm -f "$session_file"
	fi
}

sidecar::spawn_bg() {
	local task="$1"
	local uuid="$2"
	local worker_pane="$3"
	local worktree_dir="$4"

	[[ -z "$task" || -z "$uuid" || -z "$worker_pane" || -z "$worktree_dir" ]] && return 1
	sidecar::enabled || return 0

	local session_name
	local runtime_log
	session_name=$(sidecar::session_name "$task" "$worker_pane" "$uuid")
	runtime_log="$NANCY_TASK_DIR/$task/logs/sidecar-runtime.log"

	SIDECAR_LAST_SESSION_NAME="$session_name"
	sidecar::stop "$task" >/dev/null 2>&1 || true
	mkdir -p "$(dirname "$runtime_log")"
	: >"$runtime_log"

	tmux new-session -d -s "$session_name" -c "$NANCY_PROJECT_ROOT" \
		"bash -c '$NANCY_FRAMEWORK_ROOT/nancy _sidecar \"$task\" \"$uuid\" \"$worker_pane\" \"$worktree_dir\" >>\"$runtime_log\" 2>&1'" ||
		return 1
	sidecar::remember_session "$task" "$session_name"
	log::info "Spawned sidecar session: $session_name"
}

sidecar::stop() {
	local task="$1"
	local session_name="${2:-}"
	local legacy_session_name
	legacy_session_name="sidecar-${task}"

	[[ -z "$task" ]] && return 1

	if [[ -z "$session_name" ]]; then
		session_name=$(sidecar::current_session_name "$task" 2>/dev/null || true)
	fi

	if [[ -n "$session_name" ]]; then
		if tmux has-session -t "$session_name" 2>/dev/null; then
			tmux kill-session -t "$session_name" 2>/dev/null || true
			log::debug "Stopped sidecar session: $session_name"
		fi
		sidecar::clear_session "$task" "$session_name"
	fi

	if [[ "$legacy_session_name" != "$session_name" ]] && tmux has-session -t "$legacy_session_name" 2>/dev/null; then
		tmux kill-session -t "$legacy_session_name" 2>/dev/null || true
		log::debug "Stopped legacy sidecar session: $legacy_session_name"
	fi
}

sidecar::run() {
	local task="$1"
	local _uuid="$2"
	local worker_pane="$3"
	local worktree_dir="$4"

	if [[ -z "$task" || -z "$worker_pane" || -z "$worktree_dir" ]]; then
		log::error "Usage: nancy _sidecar <task> <uuid> <worker_pane> <worktree_dir>"
		return 1
	fi

	sidecar::_monitor_loop "$task" "$worker_pane" "$worktree_dir"
}

sidecar::_handover_file() {
	local task="$1"

	[[ -z "$task" ]] && return 1
	printf '%s\n' "$NANCY_TASK_DIR/$task/HANDOVER.md"
}

sidecar::_file_mtime() {
	local file="$1"

	[[ -f "$file" ]] || return 1

	stat -f '%m' "$file" 2>/dev/null ||
		stat -c '%Y' "$file" 2>/dev/null
}

sidecar::_handover_changed() {
	local task="$1"
	local baseline_mtime="${2:-0}"
	local handover_file current_mtime

	handover_file=$(sidecar::_handover_file "$task") || return 1
	current_mtime=$(sidecar::_file_mtime "$handover_file" 2>/dev/null || true)
	[[ -n "$current_mtime" ]] || return 1

	((current_mtime > baseline_mtime))
}

sidecar::_detect_handover_active() {
	local pane_text="$1"

	printf '%s\n' "$pane_text" | grep -Eq 'session-handover|Successfully loaded skill|Handover written to|HANDOVER\.md|/handovers/' 
}

sidecar::_monitor_loop() {
	local task="$1"
	local worker_pane="$2"
	local worktree_dir="$3"

	local poll_seconds="${NANCY_SIDECAR_POLL_SECONDS:-10}"
	local bootstrap_retries="${NANCY_SIDECAR_BOOTSTRAP_RETRIES:-10}"
	local bootstrap_sleep_seconds="${NANCY_SIDECAR_BOOTSTRAP_SLEEP_SECONDS:-1}"
	local armed_threshold="${NANCY_SIDECAR_ARMED_THRESHOLD:-70}"
	local kill_threshold="${NANCY_SIDECAR_KILL_THRESHOLD:-75}"
	local handover_grace_seconds="${NANCY_SIDECAR_HANDOVER_GRACE_SECONDS:-45}"
	local handover_timeout_seconds="${NANCY_SIDECAR_HANDOVER_TIMEOUT_SECONDS:-180}"
	local worker_grace_polls="${NANCY_SIDECAR_WORKER_GRACE_POLLS:-6}"
	local max_capture_failures="${NANCY_SIDECAR_MAX_CAPTURE_FAILURES:-5}"

	local state="monitoring"
	local last_commit=""
	local missing_worker_checks=0
	local seen_worker=0
	local bootstrap_checks=0
	local logged_worker_ready=0
	local logged_context_visible=0
	local logged_handover_grace=0
	local last_percent=""
	local consecutive_capture_failures=0
	local armed_at=0
	local handover_mtime_at_arm=0
	local handover_active=0
	last_commit=$(git -C "$worktree_dir" rev-parse HEAD 2>/dev/null || echo "")

	log::info "Watching worker pane $worker_pane for task $task (arm@${armed_threshold}% kill@${kill_threshold}% handover-grace=${handover_grace_seconds}s handover-timeout=${handover_timeout_seconds}s)"

	while true; do
		if ! sidecar::_pane_exists "$worker_pane"; then
			log::info "Worker pane $worker_pane disappeared; sidecar stopping"
			return 0
		fi

		if ! sidecar::_worker_alive "$task"; then
			if ((seen_worker == 1)); then
				log::info "Worker exited; sidecar stopping"
				rm -f "$NANCY_TASK_DIR/$task/.worker_pid" 2>/dev/null || true
				return 0
			fi
			missing_worker_checks=$((missing_worker_checks + 1))
			if ((missing_worker_checks > worker_grace_polls)); then
				log::info "Worker never came up; sidecar stopping"
				return 0
			fi
			log::debug "Worker not ready yet (check ${missing_worker_checks}/${worker_grace_polls})"
			if ((bootstrap_checks < bootstrap_retries)); then
				bootstrap_checks=$((bootstrap_checks + 1))
				sleep "$bootstrap_sleep_seconds"
			else
				sleep "$poll_seconds"
			fi
			continue
		fi

		seen_worker=1
		missing_worker_checks=0
		if ((logged_worker_ready == 0)); then
			log::info "Worker process detected for task $task on pane $worker_pane"
			logged_worker_ready=1
		fi

		local pane_text percent
		pane_text=$(sidecar::_capture_worker "$worker_pane")
		if sidecar::_detect_exit_ready "$pane_text"; then
			log::info "Worker emitted completion signal; terminating worker"
			sidecar::_kill_worker "$task" "$worker_pane"
			return 0
		fi
		percent=$(sidecar::_extract_context_percent "$pane_text")

		if [[ -z "$percent" ]]; then
			if ((logged_context_visible == 0)); then
				log::debug "Context meter not visible yet; waiting for worker UI"
				if ((bootstrap_checks < bootstrap_retries)); then
					bootstrap_checks=$((bootstrap_checks + 1))
					sleep "$bootstrap_sleep_seconds"
				else
					sleep "$poll_seconds"
				fi
				continue
			fi
			consecutive_capture_failures=$((consecutive_capture_failures + 1))
			if ((consecutive_capture_failures >= max_capture_failures)); then
				log::warn "Context meter lost after ${consecutive_capture_failures} consecutive failures; using last known ${last_percent}%"
			fi
			percent="$last_percent"
		else
			consecutive_capture_failures=0
			last_percent="$percent"
		fi

		if [[ -z "$percent" ]]; then
			sleep "$poll_seconds"
			continue
		fi

		bootstrap_checks=$bootstrap_retries
		if ((logged_context_visible == 0)); then
			log::info "Context meter detected at ${percent}% on pane $worker_pane"
			logged_context_visible=1
		fi

		case "$state" in
			monitoring)
				if ((percent >= armed_threshold)); then
					last_commit=$(git -C "$worktree_dir" rev-parse HEAD 2>/dev/null || echo "")
					state="armed"
					armed_at=$(date +%s)
					handover_mtime_at_arm=$(sidecar::_file_mtime "$(sidecar::_handover_file "$task")" 2>/dev/null || echo 0)
					handover_active=0
					logged_handover_grace=0
					sidecar::_request_handover "$worker_pane"
					log::info "Sidecar armed at ${percent}% context"
				fi
				;;
			armed)
				if ((handover_active == 0)) && sidecar::_detect_handover_active "$pane_text"; then
					handover_active=1
					log::info "Handover skill activity detected; waiting for handover artifact"
				fi
				if sidecar::_handover_changed "$task" "$handover_mtime_at_arm"; then
					log::info "Handover file updated; terminating worker"
					sidecar::_kill_worker "$task" "$worker_pane"
					return 0
				fi
				if sidecar::_detect_break_point "$worker_pane" "$worktree_dir" "$last_commit"; then
					local break_kind="$SIDECAR_BREAK_KIND"
					last_commit="$SIDECAR_LAST_COMMIT"
					log::info "Breakpoint (${break_kind}) at ${percent}%; terminating worker"
					sidecar::_kill_worker "$task" "$worker_pane"
					return 0
				fi
				if sidecar::_detect_exit_ready "$pane_text"; then
					log::info "Worker appears ready to exit at ${percent}%; terminating worker"
					sidecar::_kill_worker "$task" "$worker_pane"
					return 0
				fi
				local now handover_elapsed
				now=$(date +%s)
				handover_elapsed=$((now - armed_at))
				if ((handover_active == 1)); then
					if ((handover_elapsed >= handover_timeout_seconds)); then
						log::warn "Handover skill exceeded ${handover_timeout_seconds}s without updating HANDOVER.md; terminating worker"
						sidecar::_kill_worker "$task" "$worker_pane"
						return 0
					fi
					sleep "$poll_seconds"
					continue
				fi
				if ((handover_elapsed < handover_grace_seconds)); then
					if ((percent >= kill_threshold && logged_handover_grace == 0)); then
						log::info "Kill threshold reached at ${percent}% but preserving handover grace (${handover_elapsed}s/${handover_grace_seconds}s)"
						logged_handover_grace=1
					fi
					sleep "$poll_seconds"
					continue
				fi
				if ((percent >= kill_threshold)); then
					log::warn "Kill threshold reached at ${percent}% after ${handover_elapsed}s handover grace; terminating worker"
					sidecar::_kill_worker "$task" "$worker_pane"
					return 0
				fi
				;;
			esac

		sleep "$poll_seconds"
	done
}

sidecar::_capture_worker() {
	local worker_pane="$1"
	tmux capture-pane -p -t "$worker_pane" -S -80 2>/dev/null || true
}

sidecar::_pane_exists() {
	local worker_pane="$1"
	tmux list-panes -t "$worker_pane" >/dev/null 2>&1
}

sidecar::_extract_context_percent() {
	local pane_text="$1"
	cli::extract_context_percent "$pane_text"
}

sidecar::_worker_alive() {
	local task="$1"
	local pid_file="$NANCY_TASK_DIR/$task/.worker_pid"

	if [[ ! -f "$pid_file" ]]; then
		return 1
	fi

	local worker_pid
	worker_pid=$(cat "$pid_file" 2>/dev/null)

	[[ -n "$worker_pid" ]] && kill -0 "$worker_pid" 2>/dev/null
}

sidecar::_detect_break_point() {
	local worker_pane="$1"
	local worktree_dir="$2"
	local last_commit="$3"

	SIDECAR_BREAK_KIND=""
	SIDECAR_LAST_COMMIT="$last_commit"

	# TODO: Re-enable commit-based breakpoints if we can make them more reliable. This triggers on git add
	# local current_commit
	# current_commit=$(git -C "$worktree_dir" rev-parse HEAD 2>/dev/null || echo "")
	# if [[ -n "$current_commit" && "$current_commit" != "$last_commit" ]]; then
	# 	SIDECAR_BREAK_KIND="commit"
	# 	SIDECAR_LAST_COMMIT="$current_commit"
	# 	return 0
	# fi

	local pane_text
	pane_text=$(sidecar::_capture_worker "$worker_pane")

	if echo "$pane_text" | grep -Fq '"Worker Done"'; then
		SIDECAR_BREAK_KIND="issue-transition"
		return 0
	fi

	return 1
}

sidecar::_detect_exit_ready() {
	local pane_text="$1"

	if printf '%s\n' "$pane_text" | grep -Eq '<END_TURN>|Log saved:|Session summary:|^✻ Worked for'; then
		return 0
	fi

	return 1
}

sidecar::_inject_message() {
	local worker_pane="$1"
	local message="$2"
	local pane_mode=""

	[[ -z "$worker_pane" || -z "$message" ]] && return 1

	pane_mode=$(tmux display-message -t "$worker_pane" -p '#{pane_in_mode}' 2>/dev/null || true)
	if [[ "$pane_mode" == "1" ]]; then
		tmux send-keys -t "$worker_pane" -X cancel 2>/dev/null || true
	fi

	tmux send-keys -t "$worker_pane" -l "$message" 2>/dev/null || return 1
	tmux send-keys -t "$worker_pane" -H 0d 2>/dev/null || return 1
	tmux send-keys -t "$worker_pane" Enter 2>/dev/null || return 1
	log::info "Injected sidecar message into $worker_pane"
}

sidecar::_request_handover() {
	local worker_pane="$1"

	[[ -z "$worker_pane" ]] && return 1

	tmux send-keys -t "$worker_pane" Escape 2>/dev/null || true
	tmux send-keys -t "$worker_pane" Escape 2>/dev/null || true
	sidecar::_inject_message "$worker_pane" "/session-handover" || return 1
	log::info "Injected /session-handover into $worker_pane"
}

sidecar::_request_exit() {
	local worker_pane="$1"

	[[ -z "$worker_pane" ]] && return 1

	tmux send-keys -t "$worker_pane" Escape 2>/dev/null || true
	sidecar::_inject_message "$worker_pane" "/exit" || return 1
	log::info "Injected /exit into $worker_pane"
}

sidecar::_kill_worker() {
	local task="$1"
	local worker_pane="$2"
	local pid_file="$NANCY_TASK_DIR/$task/.worker_pid"
	local grace_seconds="${NANCY_SIDECAR_KILL_GRACE_SECONDS:-10}"

	sidecar::_request_exit "$worker_pane"
	sleep "$grace_seconds"

	if [[ ! -f "$pid_file" ]]; then
		log::info "Worker already exited after /exit"
		return 0
	fi

	local worker_pid
	worker_pid=$(cat "$pid_file" 2>/dev/null)

	if [[ -z "$worker_pid" ]] || ! kill -0 "$worker_pid" 2>/dev/null; then
		log::info "Worker already exited after /exit"
		return 0
	fi

	log::warn "Worker still alive after /exit; sending SIGTERM"
	kill "$worker_pid" 2>/dev/null || true
	sleep 2
	if kill -0 "$worker_pid" 2>/dev/null; then
		kill -9 "$worker_pid" 2>/dev/null || true
		log::warn "Worker required SIGKILL"
	fi
	rm -f "$pid_file" 2>/dev/null || true
}
