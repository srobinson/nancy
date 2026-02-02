#!/usr/bin/env bash
# b_path:: src/notify/watcher.sh
# Bidirectional file watcher for orchestrator and worker inboxes
# ------------------------------------------------------------------------------
#
# Watches BOTH inboxes:
#   - orchestrator/inbox - messages FROM worker TO orchestrator
#   - worker/inbox - messages FROM orchestrator TO worker
#
# Functions:
#   notify::check_fswatch           - Check if fswatch is installed
#   notify::watch_comms <task>      - Watch both inboxes (blocking)
#   notify::watch_inbox <task>      - Legacy: watch orchestrator inbox only
#
# Requires: fswatch (brew install fswatch)
# ------------------------------------------------------------------------------

# Token threshold constants
readonly TOKEN_WARNING_THRESHOLD=50
readonly TOKEN_CRITICAL_THRESHOLD=60
readonly TOKEN_INFO_THRESHOLD=30
readonly TOKEN_DANGER_THRESHOLD=70

# Check fswatch availability on source (warn but don't fail)
if ! command -v fswatch &>/dev/null; then
	log::warn "fswatch not installed - notification watching disabled"
	log::warn "Install with: brew install fswatch"
fi

# -----------------------------------------------------------------------------
# notify::check_fswatch - Check if fswatch is available
# Returns 0 if available, 1 if missing
# -----------------------------------------------------------------------------
notify::check_fswatch() {
	if command -v fswatch &>/dev/null; then
		return 0
	else
		log::error "fswatch not installed"
		log::info "Install with: brew install fswatch"
		return 1
	fi
}

# -----------------------------------------------------------------------------
# notify::_format_message_display - Format a message for display
# Args: filepath, direction (to-orchestrator|to-worker)
# -----------------------------------------------------------------------------
notify::_format_message_display() {
	local filepath="$1"
	local direction="$2"
	local filename
	filename=$(basename "$filepath")

	# Extract metadata
	local msg_type msg_from msg_priority
	msg_type=$(grep -m1 '^\*\*Type:\*\*' "$filepath" 2>/dev/null | sed 's/.*\*\*Type:\*\*[[:space:]]*//')
	msg_from=$(grep -m1 '^\*\*From:\*\*' "$filepath" 2>/dev/null | sed 's/.*\*\*From:\*\*[[:space:]]*//')
	msg_priority=$(grep -m1 '^\*\*Priority:\*\*' "$filepath" 2>/dev/null | sed 's/.*\*\*Priority:\*\*[[:space:]]*//')

	# Determine icon and label based on direction
	local icon label
	if [[ "$direction" == "to-orchestrator" ]]; then
		icon="📤"
		label="WORKER → ORCHESTRATOR"
	else
		icon="📥"
		label="ORCHESTRATOR → WORKER"
	fi

	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "$icon $label"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "File: $filename"
	echo "Type: ${msg_type:-unknown} | From: ${msg_from:-unknown} | Priority: ${msg_priority:-normal}"
	echo "────────────────────────────────────────────────────────"
	cat "$filepath"
	echo ""
}

# -----------------------------------------------------------------------------
# notify::watch_comms - Watch both inboxes for new messages (blocking)
# Args: task
# Displays all communication in both directions
# -----------------------------------------------------------------------------
notify::watch_comms() {
	local task="$1"

	if [[ -z "$task" ]]; then
		log::error "Usage: notify::watch_comms <task>"
		return 1
	fi

	notify::check_fswatch || return 1

	local orchestrator_inbox="$NANCY_TASK_DIR/$task/comms/orchestrator/inbox"
	local worker_inbox="$NANCY_TASK_DIR/$task/comms/worker/inbox"
	local watcher_log="$NANCY_TASK_DIR/$task/logs/watcher.log"

	# Ensure directories exist
	mkdir -p "$orchestrator_inbox"
	mkdir -p "$worker_inbox"
	mkdir -p "$(dirname "$watcher_log")"

	# Get pane base index dynamically (user may have pane-base-index set to 1)
	# Layout: Orchestrator=0, Worker=1, Inbox=2
	local pane_base
	pane_base=$(tmux show-window-option -gv pane-base-index 2>/dev/null || echo "0")
	local pane_orch=$((pane_base + 0))
	local pane_worker=$((pane_base + 1))
	local pane_inbox=$((pane_base + 2))
	local win="nancy-${task}"

	# Set up cleanup and error traps
	trap 'echo "[$(date -Iseconds)] Watcher stopped (SIGINT/SIGTERM)" >> "$watcher_log"; exit 0' SIGINT SIGTERM
	trap 'echo "[$(date -Iseconds)] ERROR: Watcher exited unexpectedly (exit code: $?)" >> "$watcher_log"; exit 1' EXIT

	echo "[$(date -Iseconds)] Watcher started" >>"$watcher_log"
	log::info "Watching bidirectional comms for: $task"
	log::info "  📤 Worker → Orchestrator: $orchestrator_inbox"
	log::info "  📥 Orchestrator → Worker: $worker_inbox"
	log::info "  📝 Logs: $watcher_log"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

	# Watch both directories with fswatch (capture stderr to log)
	fswatch -0 --event Created "$orchestrator_inbox" "$worker_inbox" 2>>"$watcher_log" | while IFS= read -r -d '' event; do
		# Only process .md files
		if [[ "$event" == *.md ]]; then
			sleep 0.1 # Brief delay for file write completion

			if [[ -f "$event" ]]; then
				local filename direction
				filename=$(basename "$event")

				if [[ "$event" == *"/orchestrator/inbox/"* ]]; then
					direction="to-orchestrator"
					echo "[$(date -Iseconds)] Worker message received: $filename" >>"$watcher_log"
					log::info "Worker message received: $filename"
					notify::worker_message "$task" "$event"

					# Update Inbox pane title to show [NEW] indicator
					tmux select-pane -t "$win.$pane_inbox" -T "Inbox [NEW]" 2>/dev/null || true

					# Inject message check into orchestrator pane (Claude Code specific)
					if notify::can_inject; then
						echo "[$(date -Iseconds)] Injecting 'nancy messages' to pane $win.$pane_orch" >>"$watcher_log"
						notify::inject_worker_check "$win.$pane_orch"
						log::info "Injected 'nancy messages' into orchestrator"
					else
						echo "[$(date -Iseconds)] Injection disabled (can_inject=false)" >>"$watcher_log"
					fi
				else
					direction="to-worker"
					echo "[$(date -Iseconds)] Directive sent to worker: $filename" >>"$watcher_log"
					log::info "Directive sent to worker: $filename"

					# Inject directive check into worker pane (Claude Code specific)
					if notify::can_inject; then
						echo "[$(date -Iseconds)] Injecting 'nancy inbox' to pane $win.$pane_worker" >>"$watcher_log"
						notify::inject_directive_check "$win.$pane_worker"
						log::info "Injected 'nancy inbox' into worker"
					else
						echo "[$(date -Iseconds)] Injection disabled (can_inject=false)" >>"$watcher_log"
					fi
				fi

				notify::_format_message_display "$event" "$direction"
			fi
		fi
	done

	# If we reach here, fswatch died
	echo "[$(date -Iseconds)] CRITICAL: fswatch pipe closed - watcher loop exited" >>"$watcher_log"
	log::error "fswatch died unexpectedly - check $watcher_log"
}

# -----------------------------------------------------------------------------
# notify::watch_inbox - Legacy function: watch orchestrator inbox only
# Args: task
# Kept for backwards compatibility
# -----------------------------------------------------------------------------
notify::watch_inbox() {
	local task="$1"

	if [[ -z "$task" ]]; then
		log::error "Usage: notify::watch_inbox <task>"
		return 1
	fi

	# Delegate to bidirectional watcher
	notify::watch_comms "$task"
}

# -----------------------------------------------------------------------------
# notify::watch_inbox_bg - Start inbox watcher in background
# Args: task
# Stores PID in .watcher_pid file, returns immediately
# -----------------------------------------------------------------------------
notify::watch_inbox_bg() {
	local task="$1"

	if [[ -z "$task" ]]; then
		log::error "Usage: notify::watch_inbox_bg <task>"
		return 1
	fi

	notify::check_fswatch || return 1

	local orchestrator_inbox="$NANCY_TASK_DIR/$task/comms/orchestrator/inbox"
	local worker_inbox="$NANCY_TASK_DIR/$task/comms/worker/inbox"
	local pid_file="$NANCY_TASK_DIR/$task/.watcher_pid"

	mkdir -p "$orchestrator_inbox"
	mkdir -p "$worker_inbox"

	# Get pane base index dynamically (user may have pane-base-index set to 1)
	# Layout: Orchestrator=0, Worker=1, Inbox=2
	local pane_base
	pane_base=$(tmux show-window-option -gv pane-base-index 2>/dev/null || echo "0")
	local pane_orch=$((pane_base + 0))
	local pane_worker=$((pane_base + 1))
	local pane_inbox=$((pane_base + 2))
	local win="nancy-${task}"

	# Check if watcher already running
	if [[ -f "$pid_file" ]]; then
		local old_pid
		old_pid=$(cat "$pid_file")
		if kill -0 "$old_pid" 2>/dev/null; then
			log::warn "Watcher already running (PID: $old_pid)"
			return 0
		fi
		rm -f "$pid_file"
	fi

	local watcher_log="$NANCY_TASK_DIR/$task/logs/watcher-bg.log"
	mkdir -p "$(dirname "$watcher_log")"

	# Start watcher in background
	(
		trap 'echo "[$(date -Iseconds)] BG watcher stopped (SIGINT/SIGTERM)" >> "$watcher_log"; rm -f "$pid_file"; exit 0' SIGINT SIGTERM
		trap 'echo "[$(date -Iseconds)] ERROR: BG watcher exited unexpectedly" >> "$watcher_log"; rm -f "$pid_file"; exit 1' EXIT

		echo "[$(date -Iseconds)] BG watcher started (PID: $$)" >>"$watcher_log"

		fswatch -0 --event Created "$orchestrator_inbox" "$worker_inbox" 2>>"$watcher_log" | while IFS= read -r -d '' event; do
			if [[ "$event" == *.md && -f "$event" ]]; then
				sleep 0.1
				if [[ "$event" == *"/orchestrator/inbox/"* ]]; then
					# Worker → Orchestrator message
					echo "[$(date -Iseconds)] Worker message: $(basename "$event")" >>"$watcher_log"
					notify::worker_message "$task" "$event"
					# Update Inbox pane title to show [NEW] indicator
					tmux select-pane -t "$win.$pane_inbox" -T "Inbox [NEW]" 2>/dev/null || true
					# Inject message check into orchestrator pane
					if notify::can_inject; then
						echo "[$(date -Iseconds)] Injecting to orchestrator pane $win.$pane_orch" >>"$watcher_log"
						notify::inject_worker_check "$win.$pane_orch"
					fi
				elif [[ "$event" == *"/worker/inbox/"* ]]; then
					# Orchestrator → Worker directive
					echo "[$(date -Iseconds)] Directive to worker: $(basename "$event")" >>"$watcher_log"
					# Inject directive check into worker pane
					if notify::can_inject; then
						echo "[$(date -Iseconds)] Injecting to worker pane $win.$pane_worker" >>"$watcher_log"
						notify::inject_directive_check "$win.$pane_worker"
					fi
				fi
			fi
		done

		# If we reach here, fswatch died
		echo "[$(date -Iseconds)] CRITICAL: BG fswatch pipe closed" >>"$watcher_log"
	) &

	local watcher_pid=$!
	echo "$watcher_pid" >"$pid_file"
	log::success "Started bidirectional watcher (PID: $watcher_pid)"
}

# -----------------------------------------------------------------------------
# notify::stop_watcher - Stop background inbox watcher
# Args: task
# Kills watcher process and removes PID file
# -----------------------------------------------------------------------------
notify::stop_watcher() {
	local task="$1"

	if [[ -z "$task" ]]; then
		log::error "Usage: notify::stop_watcher <task>"
		return 1
	fi

	local pid_file="$NANCY_TASK_DIR/$task/.watcher_pid"

	if [[ ! -f "$pid_file" ]]; then
		log::warn "No watcher running for task: $task"
		return 0
	fi

	local watcher_pid
	watcher_pid=$(cat "$pid_file")

	if kill -0 "$watcher_pid" 2>/dev/null; then
		kill "$watcher_pid" 2>/dev/null
		log::success "Stopped watcher (PID: $watcher_pid)"
	else
		log::warn "Watcher process not running (stale PID file)"
	fi

	rm -f "$pid_file"
}

# -----------------------------------------------------------------------------
# notify::watch_tokens_bg - Start token usage watcher in background
# Args: task, iteration (default: 1)
# Tails JSONL session file, updates token-usage.json on each assistant message
# Also monitors token usage thresholds and sends progressive alerts via nancy direct
# -----------------------------------------------------------------------------

notify::watch_tokens_bg() {
	local task="$1"
	local iteration="${2:-1}"

	if [[ -z "$task" ]]; then
		log::error "Usage: notify::watch_tokens_bg <task> [iteration]"
		return 1
	fi

	local session_id="nancy-${task}-iter${iteration}"
	local jsonl_file="$NANCY_TASK_DIR/$task/logs/${session_id}.log"
	local pid_file="$NANCY_TASK_DIR/$task/.token_watcher_pid"
	local alert_log="$NANCY_TASK_DIR/$task/logs/token-alerts.log"

	# Check if watcher already running
	if [[ -f "$pid_file" ]]; then
		local old_pid
		old_pid=$(cat "$pid_file")
		if kill -0 "$old_pid" 2>/dev/null; then
			log::warn "Token watcher already running (PID: $old_pid)"
			return 0
		fi
		rm -f "$pid_file"
	fi

	# Ensure directories exist
	mkdir -p "$(dirname "$jsonl_file")"
	mkdir -p "$(dirname "$alert_log")"

	# Create JSONL file if it doesn't exist
	touch "$jsonl_file"

	# Reset token tracking for fresh start
	token::reset "$task"

	# Start watcher in background
	(
		trap 'rm -f "$pid_file"; exit 0' SIGINT SIGTERM

		# Track previous threshold for one-way progression
		local _prev_threshold="ok"

		# tail -F follows by name (handles file rotation/recreation)
		tail -n 0 -F "$jsonl_file" 2>/dev/null | while IFS= read -r line; do
			# Skip empty lines
			[[ -z "$line" ]] && continue

			# Update token usage (function handles filtering for assistant messages)
			if token::update "$task" "$line" 2>/dev/null; then
				# Token update succeeded - check thresholds
				local current_threshold
				current_threshold=$(token::check_threshold "$task")

				# Check if we should alert (only on threshold escalation)
				if notify::_should_alert_on_threshold "$_prev_threshold" "$current_threshold"; then
					local percent
					percent=$(token::percent "$task")

					local message
					message=$(notify::_get_threshold_message "$current_threshold" "$percent")

					# Log the alert attempt
					echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Sending $current_threshold alert at ${percent}%" >>"$alert_log"

					# Send directive using comms API directly
					local filename
					if filename=$(comms::orchestrator_send "$task" "directive" "$message" "urgent" 2>&1); then
						echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] ✓ Alert sent: $filename" >>"$alert_log"
					else
						echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] ✗ Failed to send alert: $filename" >>"$alert_log"
					fi

					_prev_threshold="$current_threshold"
				fi
			fi
		done
	) &

	local watcher_pid=$!
	echo "$watcher_pid" >"$pid_file"
	log::success "Started token watcher (PID: $watcher_pid)"
	log::info "  Watching: $jsonl_file"
	log::info "  Alerts logged to: $alert_log"
}

# -----------------------------------------------------------------------------
# notify::_should_alert_on_threshold - Check if we should alert on threshold change
# Args: prev_threshold, current_threshold
# Returns: 0 if should alert, 1 if should not
# Helper function for token watcher
# -----------------------------------------------------------------------------
notify::_should_alert_on_threshold() {
	local prev="$1"
	local current="$2"

	# Never notify
	# return 1

	# Only alert when crossing into a new threshold (not when staying in same or decreasing)
	[[ "$current" == "ok" ]] && return 1

	# Check for valid escalations
	case "$prev" in
	ok)
		[[ "$current" =~ ^(info|warning|critical|danger)$ ]] && return 0
		;;
	info)
		[[ "$current" =~ ^(warning|critical|danger)$ ]] && return 0
		;;
	warning)
		[[ "$current" =~ ^(critical|danger)$ ]] && return 0
		;;
	critical)
		[[ "$current" == "danger" ]] && return 0
		;;
	esac

	return 1
}

# -----------------------------------------------------------------------------
# notify::_get_threshold_message - Get threshold alert message
# Args: threshold, percent
# Returns: formatted message string
# Helper function for token watcher
# -----------------------------------------------------------------------------
notify::_get_threshold_message() {
	local threshold="$1"
	local percent="$2"

	case "$threshold" in
	info)
		echo "👋 Hi! You've used ${percent}% of your context. Keep on trucking!"
		;;
	warning)
		echo "Token usage at ${percent}% of context limit. Start thinking about wrapping up your current work and preparing to hand off or complete the task."
		;;
	critical)
		echo "CRITICAL: Token usage at ${percent}% of context limit. You MUST start winding down your work now. Complete current task and prepare to stop."
		;;
	danger)
		echo "DANGER: Token usage at ${percent}% of context limit. You MUST STOP immediately. No further work can be done without losing critical context."
		;;
	esac
}

# -----------------------------------------------------------------------------
# notify::stop_token_watcher - Stop background token watcher
# Args: task
# -----------------------------------------------------------------------------
notify::stop_token_watcher() {
	local task="$1"

	if [[ -z "$task" ]]; then
		log::error "Usage: notify::stop_token_watcher <task>"
		return 1
	fi

	local pid_file="$NANCY_TASK_DIR/$task/.token_watcher_pid"

	if [[ ! -f "$pid_file" ]]; then
		log::debug "No token watcher running for task: $task"
		return 0
	fi

	local watcher_pid
	watcher_pid=$(cat "$pid_file")

	if kill -0 "$watcher_pid" 2>/dev/null; then
		kill "$watcher_pid" 2>/dev/null
		log::success "Stopped token watcher (PID: $watcher_pid)"
	else
		log::debug "Token watcher process not running (stale PID file)"
	fi

	rm -f "$pid_file"
}

# -----------------------------------------------------------------------------
# notify::stop_all_watchers - Stop all background watchers for a task
# Args: task
# -----------------------------------------------------------------------------
notify::stop_all_watchers() {
	local task="$1"

	if [[ -z "$task" ]]; then
		log::error "Usage: notify::stop_all_watchers <task>"
		return 1
	fi

	notify::stop_watcher "$task"
	notify::stop_token_watcher "$task"
}
