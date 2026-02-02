<!-- b_path:: .github/copilot-instructions.md -->
## <!-- b_path:: .github/copilot-instructions.md -->

description: AI rules derived by SpecStory from the project AI interaction history
globs: \*

---

## HEADERS

## TECH STACK

- Consider using `gum` (charmbracelet/gum) for the CLI interface.
- `gum` 0.17.0 is already installed and up-to-date.
- Just require `gum` and `tmux`. If no `gum` or `tmux` then no bueno.

## PROJECT DOCUMENTATION & CONTEXT SYSTEM

## CODING STANDARDS

## WORKFLOW & RELEASE RULES

- If ESC is pressed during "new task" it should return to options.
- If ESC is pressed during "new task" and no task name is provided, return to options.

- After setup completes and it asks "Create your first task?", if ESC (or cancel) is pressed, return to the menu options.

- The prompts should use skills.

## DEBUGGING

## INDEXING

- When asked to index the codebase, start from the entry point (e.g., `nancy`).
- Provide a general outline of the codebase structure and workflow.
- List key components, dependencies, and their purposes.
- Offer options for diving deeper into specific areas of the codebase.

When indexing the `nancy` codebase:

- Note that the entry point `nancy` currently has a convoluted flow with potentially redundant checks in `_nancy_check_deps`, `_nancy_check_first_run`, and `cmd::interactive`.
- The desired future state is a simplified flow:

```
User types: nancy
     │
     ▼
nancy::main()
  ├── Not initialized? → nancy setup (wizard)
  ├── No tasks?        → nancy init <name> (create first task)
  └── Has tasks?       → Show menu, pick one, run
```

- Consider renaming `cmd::interactive` to `cmd::menu` or inlining it in `main()`.
- The preferred approach is to create a "clean room" entry point rather than a full rewrite. This involves creating a new `nancy` entry point and selectively copying in existing libraries and commands in a more organized and intuitive manner.
- The new `nancy` entry point should avoid redundant checks and have a clear, concise flow.
- The user is not a fan of the `./commands` directory structure and may want to use `src` instead.
- `Lib` needs to be decomposed.
- Export core paths in `nancy` entry point.
- `fs::task_list` belongs in `tasks`.
- `fs: file exists` is just a one-liner simple bash command no value in abstracting it.
- Remove `fs.sh`.

Example of a minimal, fresh `nancy` entry point:

```bash
#!/usr/bin/env bash
set -euo pipefail

NANCY_FRAMEWORK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NANCY_PROJECT_ROOT="$(pwd)"

. "${NANCY_FRAMEWORK_ROOT}/lib/index.sh"

main() {
    case "${1:-}" in
        setup)  cmd::setup ;;
        init)   cmd::init "${2:-}" ;;
        start)  cmd::start "${2:-}" ;;
        doctor) cmd::doctor ;;
        help)   cmd::help ;;
        *)      cmd::menu ;;  # The default - clean menu
    esac
}

main "$@"
```

- Gum is a fantastic fit for Nancy.

### Perfect Use Cases in Nancy

| Feature       | Nancy Use Case                                         |
| ------------- | ------------------------------------------------------ |
| `gum confirm` | "Run setup?", "Create task?", "Deploy?"                |
| `gum choose`  | Task selection menu (replaces janky numbered list)     |
| `gum input`   | Task name input, directive message                     |
| `gum filter`  | Fuzzy task search when you have many tasks             |
| `gum spin`    | "Starting worker...", "Initializing session..."        |
| `gum style`   | Headers, status output, log formatting                 |
| `gum log`     | Structured logging (replace `log::info`, `log::error`) |

## Considerations

1.  **Dependency** - Add `gum` and `tmux` to `deps::required`. Easy install via `brew install gum` or single binary download.
2.  **Graceful fallback?** - Just require `gum` and `tmux`. If no `gum` or `tmux` then no bueno.
3.  **Consistent styling** - Use env vars for project-wide theme:

```bash
export GUM_CONFIRM_SELECTED_FOREGROUND="212"
export GUM_CHOOSE_CURSOR_FOREGROUND="212"
```

4.  **Setup wizard** (`cmd::setup`) becomes gorgeous with gum's `choose`, `input`, `confirm` flow.

## Nancy Architecture Analysis

### The Core Problem

```
nancy → _nancy_check_deps → _nancy_check_first_run → cmd::interactive
                                    ↓
                            ALSO checks .nancy exists (duplicate!)
                            ALSO offers setup (duplicate!)
```

**4 places checking the same conditions.** Convoluted.

### Proposed Structure

```
src/
├── nancy                    # ~30 lines, THIN entry
├── core/                    # log, fs, deps (no dependencies)
├── config/                  # config.json handling
├── cli/                     # dispatch.sh + drivers/
├── task/                    # task CRUD + session + prompt
├── orchestration/           # comms, tmux layout, worker
├── skills/                  # resolve, tokens, builtin/
├── cmd/                     # THIN command wrappers
├── bin/                     # standalone executables
└── templates/
```

### Key Changes

| Before                | After                       |
| --------------------- | --------------------------- |
| `cmd::interactive`    | `cmd::menu` (default)       |
| `cmd::init` (project) | Merged into `cmd::setup`    |
| `cmd::task:init`      | `cmd::init` (THE init)      |
| `` flat               | Organized by domain         |
| 3+ duplicate checks   | Single check in `cmd::menu` |

### Current State Analysis

### 1. `nancy init` Flow - The Real Next Step

Currently `cmd::init` in `init.sh` says "edit files manually" but `task.sh` (`cmd::task:new`) does it properly - it launches an **interactive chat session** with a prompt that guides spec creation.

The flow should be:

```
nancy init <task>  →  Create task dir  →  Open interactive chat to create SPEC.md
```

### 2. Prompts are Inline

In `undefined`, there's a ~50-line `init_prompt` string embedded in bash. This is:

- Hard to read/edit
- Not reusable
- Mixes concerns (code + prompt content)

**Proposal:** Move to `` (already exists) as`templates/task-init.md.template`

### 3. Current Skills Inventory

| Skill              | Purpose                        | Status                        |
| ------------------ | ------------------------------ | ----------------------------- |
| `check-directives` | Poll for orchestrator messages | Works, but complex            |
| `tokens-remaining` | Check context usage            | Works, CLI-agnostic           |
| `create-spec`      | Requirements elicitation       | Detailed skill.md, no script? |
| `update-spec`      | Mark criteria done             | Has script + `skill.md`       |

**Issues I see:**

- `create-spec` has a great `skill.md` but seems to overlap with the inline prompt in `task.sh`
- Skills are split between `skill.md` (prompts) and `.sh` (scripts) - inconsistent
- Some skills are for **workers** (tokens, directives), others for **interactive** (create-spec)
- Current skills are bloated (e.g., providing jq when agents can parse JSON natively).

## Questions for Discussion

1. **Prompt organization**:

   - `` for static templates (PROMPT.md.template)
   - `prompts/` for interactive system prompts (task-init, create-spec)?
   - Or just `` for everything?
   - **Decision:** Keep prompts simple (KISS)

2. **Skills architecture**: What's the model here?

   - Are skills **worker-only** (autonomous loop)?
   - Are some skills **interactive** (human in the loop)?
   - Should `create-spec` be a skill or just a prompt template?
   - **Decision**: Skills are for the agent, prompts are thin and there to guide. Leverage Anthropic's skills API.

3. **Skill simplification**:
   - `check-directives` is 147 lines of `skill.md` - is that overkill? **Decision:** YES OVERKILL
   - Do workers actually need step-by-step instructions or just the command?

## Thoughts on Skills

- Skills are for the agent.
- Leverage the Anthropic skills API.
- Everything is a skill; prompts should be thin and there to guide.
- Current `./skills` are poorly put together. Agents have amazing built-in capabilities to parse JSON, yet we provide jq tooling! Modern LLMs can:
  - Parse JSON natively.
  - Execute bash commands.
  - Understand file formats.
- So skills should just be:
  - The command to run.
  - Maybe a one-liner description.
  - Let the agent figure out the rest.

Example of a minimal skill:

```markdown
---
name: check-directives
---

Check for orchestrator messages:
`ls $NANCY_TASK_DIR/comms/directives/`

If files exist, read them and respond appropriately.
```

## Directory and Path Management

- Export core paths in `nancy` entry point:

  ```bash
  export NANCY_VERSION="2.0.0"
  export NANCY_DIR_NAME=".nancy"

  export NANCY_FRAMEWORK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  export NANCY_PROJECT_ROOT="$(pwd)"
  export NANCY_DIR="${NANCY_PROJECT_ROOT}/${NANCY_DIR_NAME}"
  export NANCY_TASK_DIR="${NANCY_DIR}/tasks"
  export NANCY_CONFIG_FILE="${NANCY_DIR}/config.json"
  ```

- `fs::task_list` belongs in `tasks`.
- `fs: file exists` is just a one-liner simple bash command no value in abstracting it.
- Remove `fs.sh`.

## WORKFLOW & RELEASE RULES

- If ESC is pressed during "new task" it should return to options.
- If ESC is pressed during "new task" and no task name is provided, return to options.

- After setup completes and it asks "Create your first task?", if ESC (or cancel) is pressed, return to the menu options.
