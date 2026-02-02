<!-- b_path:: .planning/codebase/ARCHITECTURE.md -->

# Architecture

**Analysis Date:** 2026-01-13

## Pattern Overview

**Overall:** Modular CLI Framework with Plugin Driver System

**Key Characteristics:**

- Single executable with subcommands (`nancy`)
- Module-based organization with loader pattern
- Function namespacing (`module::function`)
- File-based IPC for orchestration mode
- Pluggable CLI drivers for AI tool abstraction

## Layers

**Core Layer (`src/core/`):**

- Purpose: Foundation utilities with zero dependencies
- Contains: `log.sh`, `deps.sh`, `ui.sh`
- Depends on: Nothing
- Used by: All other modules

**Configuration Layer (`src/config/`):**

- Purpose: Hierarchical config management
- Contains: `config.sh` - loading with inheritance
- Depends on: Core (for logging)
- Used by: CLI, Task, Command layers

**Task Layer (`src/task/`):**

- Purpose: Task lifecycle and session management
- Contains: `task.sh`, `session.sh`
- Depends on: Core, Config
- Used by: Command layer

**CLI Abstraction Layer (`src/cli/`):**

- Purpose: Pluggable CLI driver system
- Contains: `dispatch.sh`, `drivers/claude.sh`, `drivers/copilot.sh`
- Depends on: Core, Config
- Used by: Command layer

**Communication Layer (`src/comms/`):**

- Purpose: File-based orchestrator-worker IPC
- Contains: `comms.sh` - directive/ack file operations
- Depends on: Core
- Used by: Command layer (orchestration mode)

**Command Layer (`src/cmd/`):**

- Purpose: User-facing commands
- Contains: `menu.sh`, `setup.sh`, `init.sh`, `start.sh`, `orchestrate.sh`, etc.
- Depends on: All other layers
- Used by: Entry point (`nancy`)

## Data Flow

**CLI Command Execution (e.g., `nancy start <task>`):**

1. Entry point `nancy` sets environment variables
2. Sources all modules in dependency order via `index.sh` loaders
3. `main()` function routes to `cmd::start`
4. Command validates task, loads config via `config::load_task`
5. CLI detected via `cli::detect`, driver selected
6. Event loop: generate session → read PROMPT.md → dispatch to CLI driver
7. CLI driver invokes actual tool (`claude`, `copilot`)
8. Check completion marker → continue or exit

**Orchestration Mode (3-pane tmux):**

1. `nancy orchestrate <task>` creates tmux window
2. Pane 0 (left): Orchestrator - `nancy _orchestrator`
3. Pane 1 (top-right): Worker - `nancy _worker`
4. Pane 2 (bottom-right): Logs - `nancy _logs`
5. IPC via filesystem: directives in `comms/directives/`, acks in `comms/acks/`

**State Management:**

- File-based: All state in `.nancy/` directory
- No persistent in-memory state
- Each command execution independent

## Key Abstractions

**Module Loader Pattern:**

- Purpose: Single import point per module
- Examples: `src/core/index.sh`, `src/cmd/index.sh`
- Pattern: Each `index.sh` sources its sub-modules

**Function Namespacing:**

- Purpose: Avoid collisions, clarify dependencies
- Examples: `log::info()`, `task::create()`, `cli::run_prompt()`
- Pattern: `<module>::<action>`

**CLI Driver Plugin:**

- Purpose: Abstract different AI CLI tools
- Examples: `src/cli/drivers/claude.sh`, `src/cli/drivers/copilot.sh`
- Pattern: `cli::${driver}::function` with dynamic dispatch

**Config Inheritance:**

- Purpose: Defaults with task-specific overrides
- Examples: Global `.nancy/config.json` → task `config.json`
- Pattern: Load global, overlay task values

## Entry Points

**CLI Entry (`nancy`):**

- Location: `nancy` (project root)
- Triggers: User runs `nancy <command>`
- Responsibilities: Set env, source modules, route to command

**Commands (`src/cmd/*.sh`):**

- Location: `src/cmd/menu.sh`, `src/cmd/start.sh`, etc.
- Triggers: Matched command from CLI
- Responsibilities: Validate input, orchestrate layers, format output

## Error Handling

**Strategy:** `set -euo pipefail` with early returns

**Patterns:**

- Functions return 0 on success, 1 on error
- `log::error()` for error messages to stderr
- Signal handlers for cleanup (`trap _cleanup SIGINT SIGTERM`)
- Validation before operations with early exits

## Cross-Cutting Concerns

**Logging:**

- `log::debug()`, `log::info()`, `log::warn()`, `log::error()` in `src/core/log.sh`
- Uses `gum` for styled output
- DEBUG env var enables debug logging

**Validation:**

- `task::validate_name()` for task name validation
- `deps::check_required()` for dependency checking
- Early returns on validation failure

**File Operations:**

- All paths via `$NANCY_*` environment variables
- Consistent directory structure per task
- Atomic operations where possible

---

_Architecture analysis: 2026-01-13_
_Update when major patterns change_
