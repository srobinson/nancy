<!-- b_path:: README.md -->

# Nancy

[![Test Suite](https://github.com/YOUR_USERNAME/nancy/actions/workflows/test.yml/badge.svg)](https://github.com/YOUR_USERNAME/nancy/actions/workflows/test.yml)

Autonomous task execution loop with context awareness and token management.

## Installation

Add to your PATH:

```bash
# Add to ~/.bashrc or ~/.zshrc
export PATH="$PATH:/Users/alphab/Dev/LLM/DEV/TMP/nancy"
```

Then reload your shell:

```bash
source ~/.zshrc  # or ~/.bashrc
```

## Usage

### Initialize Nancy in a project

```bash
cd /path/to/your/project
nancy
```

This creates `.nancy/config.json` with default settings.

### Create a task

```bash
nancy init feature-auth
```

This starts an interactive Copilot session to help you define:

- **SPEC.md** - What to build (AI/human collaboration)
- **PROMPT.md** - Instructions for Nancy

### Start the Nancy loop

```bash
nancy start feature-auth
```

Nancy will iterate:

1. Read previous session history from `./sessions/`
2. Check git log for progress
3. Work on the task
4. Export session to `./sessions/`
5. Repeat

### Other commands

```bash
nancy status              # Show all tasks and progress
nancy list                # List task names
nancy help                # Show help
```

## Directory Structure

```
your-project/
├── .nancy/
│   ├── config.json           # Nancy configuration
│   └── tasks/
│       ├── feature-auth/
│       │   ├── SPEC.md       # Task specification
│       │   ├── PROMPT.md     # Nancy instructions
│       │   └── sessions/     # Session history
│       │       ├── session_2026-01-08_iter1.md
│       │       └── session_2026-01-08_iter2.md
│       └── bugfix-memory/
│           ├── SPEC.md
│           ├── PROMPT.md
│           └── sessions/
└── ... your project files
```

## Configuration

`.nancy/config.json`:

```json
{
  "version": "1.0",
  "nancy_dir": ".nancy",
  "model": "claude-sonnet-4.5",
  "token_threshold": 0.2,
  "git": {
    "auto_commit": true,
    "commit_message_template": "nancy(${task}): ${summary}",
    "commit_per_iteration": false
  },
  "session": {
    "export_format": "markdown",
    "keep_history": true,
    "max_sessions": 100
  }
}
```

## How It Works

Nancy is based on the "Nancy Wiggum" technique:

```bash
while :; do cat PROMPT.md | copilot --share session.md ; done
```

Each iteration:

1. **Context Gathering** - Agent reads previous sessions, git log, spec
2. **Work** - Agent makes progress on the task
3. **Token Management** - Agent ends turn gracefully at 20% remaining
4. **Export** - Session is saved to `./sessions/` for next iteration
5. **Completion Check** - If agent signals `<complete>`, loop exits
6. **Loop** - Process repeats until complete

### Key Principles

- **No summaries** - Agent derives context from source (git, sessions)
- **Maximum utilization** - Use full context window per turn
- **Self-correcting** - Agent sees mistakes in history and fixes them
- **Project-scoped** - All history stays in `.nancy/` directory
- **Concurrent-safe** - Each task has isolated session state

### Task Completion

When the agent determines the task is fully complete, it outputs `<complete>` and Nancy exits the loop gracefully.

### Concurrency Support

Nancy supports running multiple tasks simultaneously:

- Each task gets a unique session ID: `nancy-<task-name>`
- Session state is isolated in `~/.copilot/session-state/nancy-<task-name>.jsonl`
- Token checking works correctly for each concurrent Nancy instance
- No conflicts between parallel executions

Example:

```bash
# Terminal 1
nancy start feature-auth

# Terminal 2 (simultaneously)
nancy start bugfix-memory

# Each Nancy runs independently with isolated state
```

## Philosophy

> "That's the beauty of Nancy - the technique is deterministically bad in an undeterministic world."

Nancy will make mistakes. The loop allows Nancy to:

- See mistakes in git log
- Learn from session history
- Self-correct in next iteration
- Build complex systems through iteration

**When Nancy falls off the slide, add a sign. Eventually Nancy learns to read the signs.**
