<!-- b_path:: .planning/codebase/STACK.md -->

# Technology Stack

**Analysis Date:** 2026-01-13

## Languages

**Primary:**

- Bash 4+ - All application code (`nancy`, `src/**/*.sh`)

**Secondary:**

- JSON - Configuration files (`config.json`, `*.schema.json`)
- Markdown - Documentation, prompts, skills (`PROMPT.md`, `SKILL.md`)

## Runtime

**Environment:**

- Bash 4.0+ (associative arrays require Bash 4)
- macOS or Linux (portable shebang: `#!/usr/bin/env bash`)

**Package Manager:**

- None (pure bash, no package management)
- Dependencies installed via system package managers (brew, apt)

## Frameworks

**Core:**

- None (vanilla Bash CLI architecture)

**Testing:**

- ShellCheck for static analysis
- No runtime test framework detected (tests planned in `.github/workflows/test.yml`)

**Build/Dev:**

- `just` task runner (`justfile`)
- `shfmt` for formatting (configured in `.vscode/settings.json`)
- `b_path_helper` / `b_llm_txt` custom tools

## Key Dependencies

**Critical:**

- `jq` - JSON parsing throughout (`src/config/config.sh`, `src/cli/drivers/claude.sh`)
- `gum` - Terminal UI components (`src/core/ui.sh`, `src/core/log.sh`)
- `tmux` - Orchestration mode panes (`src/cmd/orchestrate.sh`)
- `git` - Version control (`src/core/deps.sh`)

**CLI Tools (at least one required):**

- `claude` - Claude Code CLI driver (`src/cli/drivers/claude.sh`)
- `copilot` - GitHub Copilot CLI driver (`src/cli/drivers/copilot.sh`)
- `opencode` - OpenCode CLI (referenced in `src/cmd/setup.sh`)
- `gemini` - Gemini CLI (referenced in `src/cmd/setup.sh`)

**Infrastructure:**

- `uuidgen` - UUID generation with fallbacks (`src/cli/drivers/claude.sh`)
- Standard Unix utilities: `date`, `find`, `sed`, `grep`, `tr`, `cp`, `mkdir`, `cat`

## Configuration

**Environment:**

- `NANCY_VERSION` - Framework version (2.0.0)
- `NANCY_CLI` - Selected CLI tool
- `NANCY_MODEL` - AI model selection
- `NANCY_TOKEN_THRESHOLD` - Token management (default 0.20)
- `NANCY_DIR`, `NANCY_TASK_DIR`, `NANCY_PROJECT_ROOT`, `NANCY_FRAMEWORK_ROOT`

**Build:**

- `.shellcheckrc` - ShellCheck configuration (disables SC1091, SC2124)
- `.vscode/settings.json` - Editor configuration, shfmt flags

## Platform Requirements

**Development:**

- macOS or Linux
- Bash 4.0+ (for associative arrays)
- Dependencies: git, jq, gum, tmux + at least one AI CLI

**Production:**

- Same as development (CLI tool runs locally)
- No server deployment

---

_Stack analysis: 2026-01-13_
_Update after major dependency changes_
