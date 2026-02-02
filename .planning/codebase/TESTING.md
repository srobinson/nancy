<!-- b_path:: .planning/codebase/TESTING.md -->

# Testing Patterns

**Analysis Date:** 2026-01-13

## Test Framework

**Runner:**

- No formal test framework currently
- Entry point: `test.sh` (forwards to `tests/run.sh`)
- CI: `.github/workflows/test.yml`

**Assertion Library:**

- Not applicable (no test framework)
- Manual verification via exit codes

**Run Commands:**

```bash
./test.sh                    # Run all tests (planned)
shellcheck src/**/*.sh       # Static analysis
```

## Test File Organization

**Location:**

- Planned: `tests/unit/*.sh`, `tests/integration/*.sh`
- Currently: No test files exist

**Naming:**

- Planned: `*-test.sh` or `test-*.sh`

**Structure:**

```
tests/                       # (Planned, not yet created)
├── run.sh                  # Test runner
├── unit/                   # Unit tests
│   └── *.sh
└── integration/            # Integration tests
    └── *.sh
```

## Test Structure

**Suite Organization:**

- No formal structure yet
- Would follow bash testing conventions

**Patterns:**

- Not established (no tests exist)

## Mocking

**Framework:**

- Not applicable

**What to Mock (if tests existed):**

- CLI tool invocations (`claude`, `copilot`)
- File system operations
- External commands (`jq`, `gum`)

## Fixtures and Factories

**Test Data:**

- Not established

**Location:**

- Would be in `tests/fixtures/`

## Coverage

**Requirements:**

- No coverage requirements
- Focus on ShellCheck passing

**Configuration:**

- Not applicable (no coverage tool)

## Test Types

**Static Analysis:**

- ShellCheck for linting
- Config in `.shellcheckrc`
- CI runs on push

**Unit Tests:**

- Not implemented
- Would test individual functions

**Integration Tests:**

- Not implemented
- Would test command execution

**Manual Testing:**

- Primary current method
- Run commands and verify output

## Common Patterns

**Static Analysis:**

```bash
# Run ShellCheck on all scripts
shellcheck src/**/*.sh

# With specific exclusions
shellcheck -e SC1090,SC2034 src/**/*.sh
```

**CI Configuration (from `.github/workflows/test.yml`):**

```yaml
- name: Run ShellCheck
  run: |
    shellcheck -e SC1090,SC2034,SC2154,SC1091 \
      nancy src/**/*.sh
```

## Quality Gates

**ShellCheck:**

- Must pass for all `src/**/*.sh` files
- Configured exclusions in `.shellcheckrc`:
  - SC1091: Not following sourced files
  - SC2124: Quoted array expansion

**Formatting:**

- `shfmt` for consistent formatting
- Configured in `.vscode/settings.json`

## Recommendations

**If implementing tests:**

1. Use BATS (Bash Automated Testing System)
2. Structure: `tests/unit/`, `tests/integration/`
3. Mock external CLI tools
4. Test function outputs and exit codes
5. Integration test key workflows

**Example BATS test (recommendation):**

```bash
#!/usr/bin/env bats

@test "task::validate_name accepts valid names" {
    source src/task/task.sh
    run task::validate_name "valid-task"
    [ "$status" -eq 0 ]
}

@test "task::validate_name rejects spaces" {
    source src/task/task.sh
    run task::validate_name "invalid task"
    [ "$status" -eq 1 ]
}
```

---

_Testing analysis: 2026-01-13_
_Update when test patterns change_
