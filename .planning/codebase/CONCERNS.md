<!-- b_path:: .planning/codebase/CONCERNS.md -->

# Codebase Concerns

**Analysis Date:** 2026-01-13

## Tech Debt

**Large Claude Driver File:**

- Issue: `src/cli/drivers/claude.sh` is 511 lines with 50+ jq invocations
- Why: Grew organically as features added
- Impact: Hard to navigate, each jq call spawns subprocess
- Fix approach: Extract session export to separate file, batch jq operations

**No Formal Test Framework:**

- Issue: Tests planned in CI but not implemented
- Files: `test.sh`, `.github/workflows/test.yml` reference non-existent `tests/run.sh`
- Why: MVP phase prioritized functionality
- Impact: Regressions possible, no automated verification
- Fix approach: Add BATS test framework, start with critical path tests

**Hardcoded Token Threshold:**

- Issue: `0.20` hardcoded in multiple places
- Files: `src/cmd/setup.sh` (lines 17-20), `src/config/config.sh` (line 16)
- Why: Single default for all CLI types
- Impact: No tuning per CLI, magic number
- Fix approach: Document meaning, consider CLI-specific defaults

## Known Bugs

**No critical bugs detected.**

The codebase handles most edge cases appropriately with validation and early returns.

## Security Considerations

**Task Names in Shell Commands:**

- Risk: Task names passed to tmux `send-keys` and sed commands
- Files: `src/cmd/orchestrate.sh` (lines 70-76), `src/cmd/init.sh` (lines 50-52)
- Current mitigation: Task name validation via `task::validate_name`
- Recommendations: Continue enforcing validation, document allowed characters

**PIPESTATUS Usage:**

- Risk: Fragile pattern - only works immediately after pipe
- File: `src/cli/drivers/claude.sh` (line 324)
- Current mitigation: Used correctly in current code
- Recommendations: Add comment warning, consider alternative pattern

## Performance Bottlenecks

**Excessive jq Subprocess Invocations:**

- Problem: 50+ individual jq calls in `src/cli/drivers/claude.sh`
- File: `src/cli/drivers/claude.sh` (lines 57, 99, 199, 378-397, etc.)
- Cause: Each jq call parsed separately instead of batching
- Improvement path: Use `jq -s` for batch operations, cache parsed results

**Session Export Processing:**

- Problem: `cli::claude::export_session` is 136 lines with multiple file reads
- File: `src/cli/drivers/claude.sh` (lines 349-484)
- Cause: Processes entire session file multiple times
- Improvement path: Single-pass processing, stream instead of load all

## Fragile Areas

**Module Load Order:**

- Why fragile: Modules must be sourced in specific order
- File: `nancy` (lines 26-31)
- Common failures: Missing module causes cascade failure
- Safe modification: Document dependency graph, add checks
- Test coverage: None

**Orchestration tmux Layout:**

- Why fragile: Hardcoded pane percentages and sleep timings
- File: `src/cmd/orchestrate.sh` (lines 53-77)
- Common failures: Pane creation race conditions, wrong sizing
- Safe modification: Test on different terminal sizes
- Test coverage: None

## Scaling Limits

**File-Based IPC:**

- Current capacity: Works well for single worker
- Limit: Multiple concurrent workers would conflict
- Symptoms at limit: Race conditions on directive files
- Scaling path: Add locking or unique worker IDs

**Session File Size:**

- Current capacity: Works for typical sessions
- Limit: Very long sessions cause slow export
- Symptoms at limit: Export takes minutes, high memory
- Scaling path: Stream processing instead of load-all

## Dependencies at Risk

**gum CLI:**

- Risk: Third-party tool, may have breaking changes
- Impact: All UI components break
- Migration plan: Abstract via `ui::*` functions (already done), version pin if needed

**Bash 4+ Requirement:**

- Risk: Not documented, older systems may fail
- Impact: Associative arrays fail on Bash 3.x
- Migration plan: Document requirement or add version check

## Missing Critical Features

**Session Resume:**

- Problem: No way to resume interrupted session mid-iteration
- Current workaround: Restart from next iteration
- Blocks: Long-running tasks lose partial progress
- Implementation complexity: Medium (save checkpoint state)

**Multi-Worker Support:**

- Problem: Only single worker per task
- Current workaround: None
- Blocks: Parallel execution strategies
- Implementation complexity: High (worker coordination, IPC redesign)

## Test Coverage Gaps

**CLI Driver Functions:**

- What's not tested: All of `src/cli/drivers/claude.sh`, `src/cli/drivers/copilot.sh`
- Risk: Driver changes could break silently
- Priority: High
- Difficulty: Requires mocking CLI tools

**Orchestration Mode:**

- What's not tested: `src/cmd/orchestrate.sh`, IPC in `src/comms/comms.sh`
- Risk: tmux integration could break
- Priority: Medium
- Difficulty: Requires tmux mocking

**Task Lifecycle:**

- What's not tested: `src/task/task.sh` functions
- Risk: Task creation/validation bugs
- Priority: Medium
- Difficulty: Low (pure functions, easy to test)

## Documentation Gaps

**UUID Session Mapping:**

- Location: `src/cli/drivers/claude.sh` (lines 46-66)
- Issue: No explanation of why UUIDs are needed or format of mapping file
- Recommendation: Add design doc or detailed comments

**Token Threshold:**

- Location: `src/config/config.sh`, `src/cmd/setup.sh`
- Issue: No explanation of what 0.20 means or how to tune
- Recommendation: Document in README or config template

---

_Concerns audit: 2026-01-13_
_Update as issues are fixed or new ones discovered_
