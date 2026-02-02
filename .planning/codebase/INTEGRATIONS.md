<!-- b_path:: .planning/codebase/INTEGRATIONS.md -->

# External Integrations

**Analysis Date:** 2026-01-13

## APIs & External Services

**AI CLI Tools (at least one required):**

1. **Claude Code CLI** (`src/cli/drivers/claude.sh`)
   - Command: `claude`
   - Flags: `--dangerously-skip-permissions`, `--session-id`, `--model`, `--output-format stream-json`
   - Session format: JSONL streaming
   - Config directory: `~/.claude/projects/<encoded-project>/<uuid>.jsonl`
   - UUID mapping: `.nancy/tasks/<task>/session-uuids.json`
   - Models: sonnet, haiku, opus

2. **GitHub Copilot CLI** (`src/cli/drivers/copilot.sh`)
   - Command: `copilot`
   - Flags: `--allow-all-tools`, `--allow-all-paths`, `--resume`, `--share`, `--model`
   - Session format: JSONL
   - Session directory: `$XDG_STATE_HOME/.copilot/session-state/`
   - Models: claude-sonnet-4 (default)

3. **OpenCode CLI** (referenced in `src/cmd/setup.sh`)
   - Command: `opencode`
   - Default model: sonnet
   - Token threshold: 0.20

4. **Gemini CLI** (referenced in `src/cmd/setup.sh`)
   - Command: `gemini`
   - Default model: gemini-2.0-flash
   - Token threshold: 0.20

## Data Storage

**Databases:**

- None (file-based storage only)

**File Storage:**

- Task data: `.nancy/tasks/<task>/`
- Sessions: `.nancy/tasks/<task>/sessions/`
- Session state: `.nancy/tasks/<task>/session-state/`
- Configuration: `.nancy/config.json`

**Caching:**

- None (stateless execution)

## Authentication & Identity

**Auth Provider:**

- None (CLI tools handle their own auth)

**CLI Authentication:**

- Claude: Uses Claude Code's built-in auth
- Copilot: Uses GitHub Copilot's auth
- No credentials stored by Nancy

## Monitoring & Observability

**Error Tracking:**

- None (local execution only)
- Errors logged to stderr via `log::error`

**Analytics:**

- None

**Logs:**

- stdout/stderr only
- Session files capture CLI output
- Log viewer in orchestration mode (`nancy _logs`)

## CI/CD & Deployment

**Hosting:**

- Not applicable (local CLI tool)

**CI Pipeline:**

- GitHub Actions (`.github/workflows/test.yml`)
- Tests: ShellCheck linting
- Matrix: Ubuntu + macOS

## Environment Configuration

**Development:**

- Required: git, jq, gum, tmux + AI CLI
- Config: `.nancy/config.json`
- No secrets required by Nancy itself

**Production:**

- Same as development (runs locally)

## Webhooks & Callbacks

**Incoming:**

- None

**Outgoing:**

- None

## Inter-Process Communication

**File-Based IPC (Orchestration Mode):**

- Directives (orchestrator → worker): `.nancy/tasks/<task>/comms/directives/`
- Acknowledgments (worker → orchestrator): `.nancy/tasks/<task>/comms/acks/`
- Archive: `.nancy/tasks/<task>/comms/archive/`
- Format: Timestamped markdown files

**Tmux Integration:**

- 3-pane layout for orchestration
- Window naming: `nancy-<task>`
- Pane communication via IPC files

## Session Management

**Claude Sessions:**

- UUID-based session IDs
- Mapping stored in `session-uuids.json`
- Session files in `~/.claude/projects/` and copied to task directory
- Export format: Markdown with statistics

**Copilot Sessions:**

- Session ID as filename
- JSONL format
- `XDG_STATE_HOME` override for task isolation

## Task Runtime Structure

Per-task directory (`.nancy/tasks/<task>/`):

```
<task>/
├── SPEC.md              # Task specification
├── PROMPT.md            # Execution prompt
├── config.json          # Task-specific config (optional)
├── COMPLETE             # Completion marker
├── sessions/            # Session history
├── session-state/       # CLI session files
├── outputs/             # Task outputs
└── comms/               # IPC files
    ├── directives/
    ├── acks/
    └── archive/
```

---

_Integration audit: 2026-01-13_
_Update when adding/removing external services_
