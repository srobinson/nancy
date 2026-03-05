#!/usr/bin/env bash
# b_path:: src/bus/bus.sh
# Shell bridge for helioy-bus runtime integration
# ------------------------------------------------------------------------------

bus::root() {
	local candidate

	for candidate in \
		"${NANCY_HELIOY_BUS_ROOT:-}" \
		"$NANCY_PROJECT_ROOT" \
		"$(dirname "$NANCY_PROJECT_ROOT")/helioy-bus" \
		"$(dirname "$NANCY_FRAMEWORK_ROOT")/helioy-bus"; do
		[[ -z "$candidate" ]] && continue
		if [[ -f "$candidate/server/bus_server.py" ]]; then
			printf '%s\n' "$candidate"
			return 0
		fi
	done

	return 1
}

bus::python_bin() {
	local root
	root=$(bus::root) || return 1

	if [[ -x "$root/.venv/bin/python" ]]; then
		printf '%s\n' "$root/.venv/bin/python"
	elif command -v python3 >/dev/null 2>&1; then
		command -v python3
	else
		return 1
	fi
}

bus::available() {
	bus::root >/dev/null 2>&1 && bus::python_bin >/dev/null 2>&1
}

bus::current_tmux_target() {
	if [[ -n "${TMUX_PANE:-}" ]]; then
		tmux display-message -p -t "$TMUX_PANE" '#{session_name}:#{window_index}.#{pane_index}' 2>/dev/null || true
	fi
}

bus::task_worktree_dir() {
	local task="$1"
	local main_repo_dir main_repo_name parent_dir

	main_repo_dir=$(git rev-parse --show-toplevel 2>/dev/null || printf '%s\n' "$NANCY_PROJECT_ROOT")
	main_repo_name=$(basename "$main_repo_dir")
	parent_dir=$(dirname "$main_repo_dir")
	printf '%s\n' "${parent_dir}/${main_repo_name}-worktrees/nancy-${task}"
}

bus::resolve_agent_by_cwd() {
	local cwd="$1"
	local tmux_target="${2:-}"
	local root py

	root=$(bus::root) || return 1
	py=$(bus::python_bin) || return 1

	(
		cd "$root" &&
			BUS_LOOKUP_CWD="$cwd" \
			BUS_LOOKUP_TMUX="$tmux_target" \
			"$py" - <<'PY'
import os

from server.bus_server import list_agents

cwd = os.environ["BUS_LOOKUP_CWD"]
tmux_target = os.environ.get("BUS_LOOKUP_TMUX", "")
agents = [agent for agent in list_agents() if agent.get("cwd") == cwd]
if tmux_target:
    exact = [agent for agent in agents if agent.get("tmux_target") == tmux_target]
    if exact:
        agents = exact
agents.sort(key=lambda agent: agent.get("last_seen", ""), reverse=True)
if agents:
    print(agents[0]["agent_id"])
PY
	)
}

bus::resolve_current_agent_id() {
	local cwd tmux_target

	cwd=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
	tmux_target=$(bus::current_tmux_target)
	bus::resolve_agent_by_cwd "$cwd" "$tmux_target"
}

bus::resolve_task_worker_agent() {
	local task="$1"
	local worktree_dir

	worktree_dir=$(bus::task_worktree_dir "$task")
	bus::resolve_agent_by_cwd "$worktree_dir"
}

bus::resolve_task_worker_pane() {
	local task="$1"
	local window_name="nancy-${task}"

	tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index} #{window_name} #{pane_title}' 2>/dev/null |
		awk -v window_name="$window_name" '
			$2 == window_name && index($0, "📡 Monitor:") == 0 {
				print $1
				exit
			}
		'
}

bus::inject_task_worker() {
	local task="$1"
	local message="$2"
	local pane

	pane=$(bus::resolve_task_worker_pane "$task")
	[[ -n "$pane" ]] || return 1

	tmux send-keys -t "$pane" -l "$message" 2>/dev/null || return 1
	tmux send-keys -t "$pane" Enter 2>/dev/null || return 1
	printf '%s\n' "$pane"
}

bus::send_message() {
	local to="$1"
	local content="$2"
	local from_agent="${3:-}"
	local reply_to="${4:-}"
	local topic="${5:-}"
	local nudge="${6:-1}"
	local root py

	root=$(bus::root) || return 1
	py=$(bus::python_bin) || return 1

	(
		cd "$root" &&
			BUS_TO="$to" \
			BUS_CONTENT="$content" \
			BUS_FROM_AGENT="$from_agent" \
			BUS_REPLY_TO="$reply_to" \
			BUS_TOPIC="$topic" \
			BUS_NUDGE="$nudge" \
			"$py" - <<'PY'
import json
import os

from server.bus_server import send_message

result = send_message(
    to=os.environ["BUS_TO"],
    content=os.environ["BUS_CONTENT"],
    from_agent=os.environ.get("BUS_FROM_AGENT", ""),
    reply_to=os.environ.get("BUS_REPLY_TO", ""),
    topic=os.environ.get("BUS_TOPIC", ""),
    nudge=os.environ.get("BUS_NUDGE", "1") != "0",
)
print(json.dumps(result))
PY
	)
}
