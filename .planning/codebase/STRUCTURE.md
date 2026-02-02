<!-- b_path:: .planning/codebase/STRUCTURE.md -->

# Codebase Structure

**Analysis Date:** 2026-01-13

## Directory Layout

```
nancy/
├── nancy                    # Main CLI entry point (executable)
├── README.md                # Project documentation
├── AGENTS.md                # Agent/worker documentation
├── justfile                 # Task automation (just command)
├── test.sh                  # Test runner entry point
│
├── src/                     # Source code modules
│   ├── core/               # Core utilities (no dependencies)
│   │   ├── index.sh        # Module loader
│   │   ├── log.sh          # Logging functions
│   │   ├── deps.sh         # Dependency validation
│   │   └── ui.sh           # UI components (gum wrappers)
│   │
│   ├── config/             # Configuration management
│   │   ├── index.sh        # Module loader
│   │   └── config.sh       # Config loading and inheritance
│   │
│   ├── task/               # Task lifecycle management
│   │   ├── index.sh        # Module loader
│   │   ├── task.sh         # Task CRUD operations
│   │   └── session.sh      # Session ID and initialization
│   │
│   ├── cli/                # CLI abstraction layer
│   │   ├── index.sh        # Module loader
│   │   ├── dispatch.sh     # CLI router and detection
│   │   └── drivers/        # CLI driver implementations
│   │       ├── index.sh    # Driver loader
│   │       ├── claude.sh   # Claude Code driver
│   │       └── copilot.sh  # GitHub Copilot driver
│   │
│   ├── comms/              # Orchestrator-worker IPC
│   │   ├── index.sh        # Module loader
│   │   └── comms.sh        # Directive/ACK file operations
│   │
│   └── cmd/                # User-facing commands
│       ├── index.sh        # Command loader
│       ├── menu.sh         # Interactive task menu (default)
│       ├── setup.sh        # First-time setup wizard
│       ├── init.sh         # Create new task
│       ├── start.sh        # Autonomous task loop
│       ├── status.sh       # Status reporting
│       ├── doctor.sh       # Diagnostic checks
│       ├── orchestrate.sh  # Tmux orchestration mode
│       ├── direct.sh       # Send directives to worker
│       ├── internal.sh     # Internal commands (_worker, _orchestrator, _logs)
│       └── help.sh         # Help information
│
├── skills/                  # Prompt skills for Claude
│   ├── orchestrator/       # Orchestrator skill
│   ├── update-spec/        # Update-spec skill
│   ├── create-spec/        # Create-spec skill
│   ├── check-directives/   # Check-directives skill
│   ├── check-tokens/       # Check-tokens skill
│   └── session-history/    # Session-history skill
│
├── templates/               # Template files
│   ├── PROMPT.md.template  # Default PROMPT.md template
│   └── task-init.md        # Task initialization template
│
├── schemas/                 # JSON schemas
│   ├── task.schema.json    # Task specification schema
│   └── prd.schema.json     # Product requirements schema
│
├── docs/                    # Documentation
├── docs.llm/                # LLM-specific documentation
│
├── .planning/               # Planning documents
├── .claude/                 # Claude Code configuration
├── .github/                 # GitHub workflows
├── .vscode/                 # VSCode configuration
└── .shellcheckrc            # ShellCheck configuration
```

## Directory Purposes

**src/core/**

- Purpose: Foundation utilities
- Contains: Logging, dependency checking, UI components
- Key files: `log.sh`, `deps.sh`, `ui.sh`

**src/config/**

- Purpose: Configuration management
- Contains: Config loading with hierarchical inheritance
- Key files: `config.sh`

**src/task/**

- Purpose: Task lifecycle
- Contains: Task CRUD, session ID generation
- Key files: `task.sh`, `session.sh`

**src/cli/**

- Purpose: AI CLI abstraction
- Contains: CLI detection, driver dispatch, driver implementations
- Key files: `dispatch.sh`, `drivers/claude.sh`, `drivers/copilot.sh`

**src/comms/**

- Purpose: Inter-process communication
- Contains: Directive and acknowledgment file operations
- Key files: `comms.sh`

**src/cmd/**

- Purpose: User-facing commands
- Contains: All command implementations
- Key files: `menu.sh`, `start.sh`, `orchestrate.sh`

**skills/**

- Purpose: Claude prompt injection skills
- Contains: SKILL.md files with prompt templates
- Key files: `*/SKILL.md`

## Key File Locations

**Entry Points:**

- `nancy` - CLI entry point
- `src/cmd/index.sh` - Command registration

**Configuration:**

- `.shellcheckrc` - ShellCheck config
- `.vscode/settings.json` - Editor/formatter config
- `justfile` - Task automation

**Core Logic:**

- `src/cli/drivers/claude.sh` - Claude Code driver (largest file)
- `src/cmd/start.sh` - Main execution loop
- `src/cmd/orchestrate.sh` - Tmux orchestration

**Testing:**

- `test.sh` - Test runner entry
- `.github/workflows/test.yml` - CI workflow

## Naming Conventions

**Files:**

- `*.sh` - Bash scripts
- `index.sh` - Module loaders
- `UPPERCASE.md` - Key documents (SPEC, PROMPT, SKILL)
- `*.schema.json` - JSON schemas

**Directories:**

- Lowercase with hyphens: `src/`, `skills/`
- Module names: `core/`, `cli/`, `cmd/`
- Driver subdirectory: `cli/drivers/`

**Special Patterns:**

- `index.sh` - Single import point per module
- `SKILL.md` - Skill definition files
- `config.json` - Configuration files

## Where to Add New Code

**New Command:**

- Implementation: `src/cmd/<command>.sh`
- Registration: Add source in `src/cmd/index.sh`
- Entry: Add case in `nancy` main()

**New CLI Driver:**

- Implementation: `src/cli/drivers/<cli>.sh`
- Registration: Add source in `src/cli/drivers/index.sh`
- Detection: Add to `cli::detect` in `src/cli/dispatch.sh`

**New Skill:**

- Implementation: `skills/<skill-name>/SKILL.md`
- Documentation: Follow existing skill format

**Utilities:**

- Shared helpers: `src/core/<utility>.sh`
- Module-specific: In respective module directory

## Special Directories

**.nancy/ (runtime, per-project):**

- Purpose: Project-specific Nancy data
- Contains: `config.json`, `tasks/` directory
- Committed: No (gitignored)

**skills/:**

- Purpose: Prompt skills for Claude injection
- Contains: SKILL.md files
- Committed: Yes

---

_Structure analysis: 2026-01-13_
_Update when directory structure changes_
