<!-- b_path:: .planning/codebase/CONVENTIONS.md -->

# Coding Conventions

**Analysis Date:** 2026-01-13

## Naming Patterns

**Files:**

- Lowercase with hyphens: `session.sh`, `task.sh`
- Module loaders: `index.sh`
- Drivers: `<cli-name>.sh` (e.g., `claude.sh`, `copilot.sh`)

**Functions:**

- Namespace pattern: `module::function_name()`
- Examples: `log::info()`, `task::create()`, `cli::run_prompt()`
- Private functions: `_function_name()` (e.g., `_start_cleanup()`)
- Driver functions: `cli::${driver}::function()` (e.g., `cli::claude::run_prompt()`)

**Variables:**

- Exports (UPPER_CASE): `NANCY_VERSION`, `NANCY_CLI`, `NANCY_DIR`
- Locals (lower_case): `local task`, `local session_id`
- Constants: `DEPS_REQUIRED=(...)`, `CLAUDE_CMD="claude"`
- Defaults pattern: `"${VAR:-default}"`

**Types:**

- Not applicable (bash has no types)
- Arrays: `local tasks=()`, `declare -A NANCY_DEFAULTS_MODEL`

## Code Style

**Formatting:**

- Tool: `shfmt` via VSCode
- Indentation: Tabs (2-space equivalent)
- Line length: 120 characters (ruler in editor)
- Flags: `-i 2 -ci -bn -sr -kp -ln -w`

**Linting:**

- Tool: ShellCheck
- Config: `.shellcheckrc`
- Disabled: SC1091 (sourced files), SC2124 (array expansion)
- Run: Via VSCode extension or CI

**Shebang:**

```bash
#!/usr/bin/env bash
```

**Error Mode:**

```bash
set -euo pipefail  # In main entry point
```

## Import Organization

**Order:**

1. Core modules (`src/core/index.sh`)
2. Configuration (`src/config/index.sh`)
3. CLI abstraction (`src/cli/index.sh`)
4. Task management (`src/task/index.sh`)
5. Communication (`src/comms/index.sh`)
6. Commands (`src/cmd/index.sh`)

**Pattern:**

```bash
. "$NANCY_FRAMEWORK_ROOT/src/core/index.sh"
. "$NANCY_FRAMEWORK_ROOT/src/config/index.sh"
# etc.
```

**Module Loaders:**

```bash
# src/core/index.sh
. "$NANCY_FRAMEWORK_ROOT/src/core/log.sh"
. "$NANCY_FRAMEWORK_ROOT/src/core/deps.sh"
. "$NANCY_FRAMEWORK_ROOT/src/core/ui.sh"
```

## Error Handling

**Patterns:**

- Early returns: `[[ -z "$task" ]] && return 1`
- Conditional execution: `cli::detect || return 1`
- Exit code capture: `local exit_code=0; command || exit_code=$?`

**Error Messages:**

```bash
log::error "Task name required"
return 1
```

**Signal Handling:**

```bash
trap _cleanup SIGINT SIGTERM
```

**Error Types:**

- Return 1 for validation failures
- `log::error` before returning
- Preserve exit codes with `|| exit_code=$?`

## Logging

**Framework:**

- Custom logging via `src/core/log.sh`
- Uses `gum` for styled output

**Levels:**

- `log::debug` - Debug info (requires DEBUG env)
- `log::info` - Normal output
- `log::warn` - Warnings
- `log::error` - Errors (to stderr)

**Patterns:**

```bash
log::info "Starting task: $task"
log::error "Task '$task' not found"
```

## Comments

**When to Comment:**

- File headers with purpose
- Complex logic explanation
- Section separators

**Header Format:**

```bash
#!/usr/bin/env bash
# b_path:: src/core/log.sh
# Logging utilities - gum powered
# ------------------------------------------------------------------------------
```

**Function Documentation:**

```bash
# Check if a command exists
deps::exists() {
    command -v "$1" &>/dev/null
}
```

**Section Markers:**

```bash
# ------------------------------------------------------------------------------
# UUID and Session Mapping
# ------------------------------------------------------------------------------
```

## Function Design

**Size:**

- Keep under 50 lines when possible
- Extract helpers for complex logic

**Parameters:**

- Pattern: `local var="${1:-default}"`
- Multiple: `local task="$1" dir="$2"`
- Arrays: `local args=("$@")`

**Return Values:**

- Success: `return 0` (or implicit)
- Failure: `return 1`
- Output: `echo` to stdout

## Module Design

**Exports:**

- Named functions with namespace prefix
- No default exports (bash concept doesn't apply)

**Loader Pattern:**

```bash
# index.sh sources all module files
. "$NANCY_FRAMEWORK_ROOT/src/module/file1.sh"
. "$NANCY_FRAMEWORK_ROOT/src/module/file2.sh"
```

**Dependencies:**

- Explicitly source required modules
- No circular dependencies
- Order matters (source in dependency order)

---

_Convention analysis: 2026-01-13_
_Update when patterns change_
