# Nancy — Project Map

Multi-agent orchestration framework for Claude Code. Worker/orchestrator pattern with parallel task
execution, directive-based communication, and session management.

Two entry points:

- `nancy` — interactive planning, Linear management, commands
- `nancy go <LINEAR_REF>` — autonomous worker execution

---

## `nancy go` Execution Trace

A single `nancy go ALP-123` invocation spawns **four** independent shell processes, each
re-sourcing the full module tree:

1. **Foreground** — `cmd::go` → `cmd::orchestrate` (exits after creating tmux window)
2. **Worker pane** (tmux pane 0) — `nancy _worker` → `cmd::start` loop
3. **Monitor pane** (tmux pane 1) — `nancy _monitor` → `tail -F` on sidecar logs
4. **Sidecar session** (detached tmux) — `nancy _sidecar` → `sidecar::_monitor_loop`

### Phase 1 — Entry & Module Bootstrap

Every invocation of `./nancy` runs this sequence before any command dispatches.

**`nancy`** (entry script)

- Sets framework env: `NANCY_VERSION`, `NANCY_FRAMEWORK_ROOT`, `NANCY_PROJECT_ROOT`,
  `NANCY_DIR`, `NANCY_TASK_DIR`, `NANCY_SIDECAR_MODE=1`, `CLAUDE_CODE_SUBAGENT_MODEL=opus`, etc.
- Sources eleven module index files (see Module Tree below).
- Loads `.nancy/config.json` via `config::load` if present.
- Dispatches `main "$@"` → `cmd::go`.

### Phase 2 — `cmd::go` (foreground)

**`src/cmd/go.sh`** — `cmd::go`

- Validates task arg (or prompts via `ui::input`).
- Calls `task::create` if task directory does not exist → seeds `PROMPT.md` from
  `templates/PROMPT.md.template`, creates `.nancy/tasks/<task>/` subdirs.
- Exports `NANCY_CURRENT_TASK_DIR`.
- Calls `cmd::orchestrate`.

**`src/cmd/orchestrate.sh`** — `cmd::orchestrate`

- Requires `$TMUX` (must be inside a tmux session).
- Creates tmux window `nancy-<task>`, splits into two panes.
- Sends `nancy _worker <task>` to pane 0, `nancy _monitor <task>` to pane 1.
- Returns immediately (worker runs independently in pane 0).

### Phase 3 — Worker Loop (pane 0)

**`src/cmd/internal.sh`** — `cmd::_worker` → delegates to `cmd::start`.

**`src/cmd/start.sh`** — `cmd::start` (the worker loop heart)

Per-startup (once):

1. `_start_fetch_linear_context` — GraphQL `get_issue.gql` → parses title/description,
   calls `update_status.gql` to mark "In Progress" (`get_workflow_states.gql` first).
2. `_start_setup_worktree` — creates git worktree at
   `<parent>/<repo>-worktrees/nancy-<task>/`, copies `.env*` and `.fmm.db`, runs
   `just install` if needed.
3. Installs SIGINT/SIGTERM trap → `_start_cleanup` (stops sidecar, kills Claude PID).

Per-iteration (the `while :` loop):

1. `_start_create_issues_file` — `get_sub_issues.gql` → writes `ISSUES.md`, extracts
   next uncompleted issue's Agent Role label into `agent_role`.
2. Renders `templates/PROMPT.md.template` → `PROMPT.<task>.md` (appends
   `$NANCY_PROJECT_ROOT/PROMPT.md` if present).
3. Generates UUID via `uuid::generate`.
4. Spawns sidecar: `sidecar::spawn_bg` → detached tmux session running `nancy _sidecar`.
5. Runs Claude: `cli::run_prompt` → `cli::claude::run_prompt` →
   `exec claude --dangerously-skip-permissions --session-id $uuid --agent helioy-tools:<role> --model opus --effort max <prompt>`.
   - Writes `.worker_uuid` and `.worker_pid` before exec.
   - After Claude exits: copies `$CLAUDE_CONFIG_DIR/projects/.../<uuid>.jsonl` →
     `session-state/<session_id>.jsonl`, writes session export markdown.
6. Stops sidecar via `sidecar::stop`.
7. Checks `STOP` sentinel → exit loop if present.
8. If exit code 0 and `NANCY_CODE_REVIEW_AGENT_ENABLED=true`: runs
   `_start_run_review_agent` — renders `templates/REVIEW.md.template` → runs Claude
   again as `clinical-reviewer`.
9. Checks `COMPLETE` sentinel → exit cleanly.
10. Checks `PAUSE` sentinel → spin-waits until removed.
11. `sleep 2` → next iteration.

### Phase 4 — Monitor Pane (pane 1)

**`src/cmd/internal.sh`** — `cmd::_monitor`

- `exec tail -F logs/sidecar.log logs/sidecar-runtime.log`
- Passive observer. Shows sidecar lifecycle and runtime events.

### Phase 5 — Sidecar (detached tmux session)

**`src/sidecar/sidecar.sh`** — `sidecar::_monitor_loop`

- Polls every 10s (`NANCY_SIDECAR_POLL_SECONDS`).
- Captures worker pane via `tmux capture-pane -p -t $worker_pane -S -80`.
- Extracts Claude Code context % from status line.
- State machine: `monitoring → armed` at 75%, kills at 85%.
- Also watches for new git commit or "Worker Done" text (issue-transition breakpoint).
- On kill: sends `/session-logger` then `/exit` to worker pane, waits, SIGTERM, SIGKILL.
- Logs everything to `logs/sidecar-runtime.log`.

---

## Module Tree

All modules sourced by every `./nancy` invocation, in order:

```
src/lib/index.sh
  ├── src/lib/fmt.sh         — fmt::strip_ansi
  ├── src/lib/log.sh         — log::debug/info/warn/error/fatal/success/header (gum)
  └── src/lib/uuid.sh        — uuid::generate

src/core/index.sh
  ├── src/core/deps.sh       — deps::check_required, deps::detect_cli
  └── src/core/ui.sh         — ui::confirm/choose/input/spin/header/box/banner (gum)

src/gql/index.sh             — gql::client::query, gql::query::generate (curl → Linear API)

src/config/index.sh
  └── src/config/config.sh   — config::load, config::load_task, config::get

src/cli/index.sh
  ├── src/cli/dispatch.sh    — cli::run_prompt, cli::run_interactive, cli::init_session
  └── src/cli/drivers/index.sh
        ├── src/cli/drivers/copilot.sh
        └── src/cli/drivers/claude.sh  — claude driver (lsof :8123 probe at source time)

src/task/index.sh
  ├── src/task/task.sh       — task::create/list/exists/is_complete/count_sessions
  ├── src/task/session.sh    — session::id, session::init
  └── src/task/token.sh      — token::update/read/percent/check_threshold → token-usage.json

src/bus/index.sh
  └── src/bus/bus.sh         — helioy-bus bridge (Python heredoc); loaded, not called in go

src/comms/index.sh
  └── src/comms/comms.sh     — file-based IPC: send/read_inbox/has_messages/archive

src/notify/index.sh
  ├── src/notify/os.sh       — macOS notifications (terminal-notifier / afplay)
  ├── src/notify/tmux.sh     — tmux display-message / display-popup
  ├── src/notify/inject.sh   — tmux send-keys prompt injection
  ├── src/notify/router.sh   — message routing by type/priority
  └── src/notify/watcher.sh  — fswatch comms loop, token threshold watcher

src/sidecar/index.sh
  └── src/sidecar/sidecar.sh — sidecar::spawn_bg/stop/run/_monitor_loop

src/linear/index.sh
  └── src/linear/issue.sh    — linear::issue, issue:sub, issue:next, issue:update:status

src/nav/index.sh
  └── src/nav/nav.sh         — tmux menu/zoom helpers; loaded, not called in go

src/cmd/index.sh             — sources all cmd modules:
  ├── src/cmd/go.sh          ★ cmd::go
  ├── src/cmd/orchestrate.sh ★ cmd::orchestrate
  ├── src/cmd/start.sh       ★ cmd::start (worker loop)
  ├── src/cmd/internal.sh    ★ cmd::_worker, cmd::_monitor, cmd::_sidecar
  ├── src/cmd/menu.sh
  ├── src/cmd/setup.sh
  ├── src/cmd/init.sh
  ├── src/cmd/status.sh
  ├── src/cmd/doctor.sh
  ├── src/cmd/direct.sh
  ├── src/cmd/pause.sh
  ├── src/cmd/unpause.sh
  ├── src/cmd/stop.sh
  ├── src/cmd/msg.sh
  ├── src/cmd/inbox.sh
  ├── src/cmd/notify-test.sh
  ├── src/cmd/experiment.sh
  └── src/cmd/help.sh
```

---

## GQL Queries

All under `src/gql/q/`:

| File                      | Called by                     | Purpose                               |
| ------------------------- | ----------------------------- | ------------------------------------- |
| `get_issue.gql`           | `linear::issue`               | Fetch parent issue details            |
| `get_sub_issues.gql`      | `linear::issue:sub`           | Fetch sub-issues (per loop iteration) |
| `get_workflow_states.gql` | `linear::issue:update:status` | Resolve state ID before updating      |
| `update_status.gql`       | `linear::issue:update:status` | Mark issue In Progress / Done         |
| `create_comment.gql`      | `linear::issue:comment:add`   | Post comment (via comms layer)        |
| `get_next_todo_issue.gql` | `linear::issue:next`          | Find next Todo sub-issue              |

---

## Config Files (READ)

| File                              | Purpose                                             |
| --------------------------------- | --------------------------------------------------- |
| `.nancy/config.json`              | CLI, model, token threshold, git auto-commit        |
| `.nancy/tasks/<task>/config.json` | Optional task-level overrides                       |
| `.env`, `.env.nancy`              | Copied into worktree on first setup                 |
| `.fmm.db`                         | Copied into worktree on first setup                 |
| `justfile`                        | `just install` run in worktree if node_modules miss |

---

## Templates (READ)

| File                           | Used by                      | Purpose                              |
| ------------------------------ | ---------------------------- | ------------------------------------ |
| `templates/PROMPT.md.template` | `task::create`, `cmd::start` | System prompt rendered each iter     |
| `templates/REVIEW.md.template` | `_start_run_review_agent`    | Code review prompt rendered per iter |
| `PROMPT.md` (project root)     | `cmd::start`                 | Optional project-local prompt append |
| `PROMPT.review.md` (root)      | `_start_run_review_agent`    | Optional project-local review append |

Template variables for `PROMPT.md.template`:
`{{NANCY_PROJECT_ROOT}}` `{{NANCY_CURRENT_TASK_DIR}}` `{{SESSION_ID}}` `{{TASK_NAME}}`
`{{PROJECT_IDENTIFIER}}` `{{PROJECT_TITLE}}` `{{PROJECT_DESCRIPTION}}` `{{WORKTREE_DIR}}`
`{{AGENT_ROLE_SECTION}}`

Template variables for `REVIEW.md.template`:
`{{SESSION_ID}}` `{{ITERATION}}` `{{TASK_NAME}}` `{{PROJECT_IDENTIFIER}}` `{{PROJECT_TITLE}}`
`{{NANCY_CURRENT_TASK_DIR}}` `{{WORKTREE_DIR}}` `{{GIT_LOG}}`

---

## Runtime Artifacts (WRITTEN)

All under `.nancy/tasks/<task>/` unless noted:

| Path                                          | Writer                      | Purpose                            |
| --------------------------------------------- | --------------------------- | ---------------------------------- |
| `PROMPT.md`                                   | `task::create`              | Seeded once from template          |
| `PROMPT.<task>.md`                            | `cmd::start`                | Rendered system prompt (per iter)  |
| `PROMPT.review.md`                            | `_start_run_review_agent`   | Rendered review prompt             |
| `ISSUES.md`                                   | `_start_create_issues_file` | Sub-issue table (per iter)         |
| `sessions/session_<ts>_iter<n>.md`            | `cli::claude::run_prompt`   | Claude session export markdown     |
| `sessions/session_<ts>_iter<n>-review.md`     | `cli::claude::run_prompt`   | Review session export              |
| `session-state/<session_id>.jsonl`            | `cli::claude::run_prompt`   | Raw Claude JSONL copy              |
| `logs/sidecar.log`                            | `cmd::start`                | Sidecar spawn events (append-only) |
| `logs/sidecar-runtime.log`                    | sidecar session             | Sidecar monitor loop runtime       |
| `.worker_uuid`                                | `cli::claude::run_prompt`   | Current Claude session UUID        |
| `.worker_pid`                                 | `cli::claude::run_prompt`   | Claude process PID                 |
| `.sidecar_session`                            | `sidecar::spawn_bg`         | Sidecar tmux session name          |
| `token-usage.json`                            | `token::update`             | Token accounting                   |
| `comms/{orchestrator,worker}/{inbox,outbox}/` | `comms::send`               | File-based IPC messages            |
| `STOP`                                        | `nancy stop`                | Sentinel: exit loop cleanly        |
| `PAUSE`                                       | `nancy pause`               | Sentinel: block loop until removed |
| `COMPLETE`                                    | worker Claude agent         | Sentinel: task finished            |
| `<repo>-worktrees/nancy-<task>/` (sibling)    | `_start_setup_worktree`     | Git worktree for isolated work     |

Claude's own state (outside task dir):

- `~/.claude.nancy/projects/<encoded>/<uuid>.jsonl` — written by Claude, copied to `session-state/`.

---

## Key Environment Variables

Set by entry script (all subshells inherit):

| Variable                          | Value                           |
| --------------------------------- | ------------------------------- |
| `NANCY_FRAMEWORK_ROOT`            | Resolved path to `./nancy` repo |
| `NANCY_PROJECT_ROOT`              | `$(pwd)` at invocation time     |
| `NANCY_DIR`                       | `$NANCY_PROJECT_ROOT/.nancy`    |
| `NANCY_TASK_DIR`                  | `$NANCY_DIR/tasks`              |
| `NANCY_SIDECAR_MODE`              | `1`                             |
| `NANCY_CODE_REVIEW_AGENT_ENABLED` | `true`                          |
| `CLAUDE_CODE_SUBAGENT_MODEL`      | `opus`                          |

Set by `config::load` (from `.nancy/config.json`):

| Variable                | Typical value |
| ----------------------- | ------------- |
| `NANCY_CLI`             | `claude`      |
| `NANCY_MODEL`           | `opus`        |
| `NANCY_TOKEN_THRESHOLD` | `0.5`         |

Set at Claude invocation time:

| Variable             | Value                         |
| -------------------- | ----------------------------- |
| `CLAUDE_CONFIG_DIR`  | `/Users/alphab/.claude.nancy` |
| `ANTHROPIC_BASE_URL` | `http://localhost:8002`       |
| `NANCY_SESSION_ID`   | `nancy-<task>-iter<n>`        |

---

## Cross-Process Coordination

```
cmd::start (worker loop)
  │  writes: .worker_pid, .worker_uuid, NANCY_SESSION_ID
  │  writes: logs/sidecar.log (spawn events)
  │  polls:  STOP, PAUSE, COMPLETE sentinels
  │
  ├─► sidecar::_monitor_loop (detached tmux session)
  │     reads:  .worker_pid (to kill)
  │     reads:  tmux capture-pane (context %)
  │     writes: logs/sidecar-runtime.log
  │     sends:  /session-logger, /exit via tmux send-keys
  │
  ├─► notify::watch_tokens_bg (background subshell, if started)
  │     reads:  Claude JSONL stream
  │     writes: token-usage.json
  │     writes: comms/worker/inbox/*.md (threshold alerts)
  │
  └─► notify::watch_comms (background subshell, if started)
        watches: comms/orchestrator/inbox, comms/worker/inbox
        injects: tmux send-keys into worker/orchestrator panes

cmd::_monitor (pane 1)
  └─► tail -F logs/sidecar.log logs/sidecar-runtime.log
```
