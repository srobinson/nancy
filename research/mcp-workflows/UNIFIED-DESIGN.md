# Nancy Unified Design: Linear + Jujutsu Integration

> A comprehensive design for AI-native task execution with Linear as the source of truth and Jujutsu as the version control foundation.

## Executive Summary

This document synthesizes research into a unified architecture where:

- **Linear** is the single source of truth for work items, status, and communication
- **Jujutsu (jj)** replaces Git for AI-friendly version control with bulletproof recovery
- **Nancy** orchestrates workers that safely experiment, fail, and recover without human intervention

The combination solves the two hardest problems in AI-assisted development:

1. **Safe concurrency** - Multiple agents working without destroying each other's work
2. **Graceful recovery** - Agents can experiment freely knowing any mistake is instantly reversible

---

## Part 1: Why Jujutsu for Nancy

### The Problem with Git for AI Agents

Git was designed for careful human developers who:

- Think before committing
- Craft clean commit history manually
- Resolve conflicts interactively
- Rarely need to undo operations

AI agents operate differently:

- **Rapid iteration** - Try, fail, try again in seconds
- **Large diffs** - Generate more code per session than humans
- **No judgment calls** - Can't decide which conflict resolution is "right"
- **Fragile state** - One wrong `git rebase -i` destroys everything

> "For an autonomous agent, Git is a minefield of footguns: confusing states like 'detached HEAD,' complex interactive prompts, and a staging area that adds another layer of complexity."
> — [Alpha Insights](https://slavakurilyak.com/posts/use-jujutsu-not-git)

### Jujutsu: Built for AI Workflows

Jujutsu is a Git-compatible VCS from Google (25k+ stars, 293 contributors) that reimagines version control for modern workflows.

#### Core Philosophy: Safety, Automation, Intuitive Data Model

| Git Concept         | Jujutsu Equivalent              | AI Benefit                  |
| ------------------- | ------------------------------- | --------------------------- |
| Staging area        | None - working copy IS a commit | No `git add` friction       |
| `git stash`         | Not needed - changes auto-saved | No lost work                |
| `git rebase -i`     | `jj squash`, `jj split`         | Non-interactive, scriptable |
| Detached HEAD       | Anonymous commits are normal    | No scary states             |
| Conflict = blocker  | Conflict = stored in commit     | Work continues              |
| History = permanent | Operation log = reversible      | Safe experimentation        |

#### The Operation Log (oplog)

Every action in Jujutsu is recorded in an append-only operation log:

```bash
jj op log
# Shows every commit, rebase, edit, undo...

jj op restore @--  # Go back 2 operations
jj undo           # Undo last operation
```

**Why this matters for Nancy:**

- Agent corrupts working state? `jj undo`
- Need to rollback 5 operations? `jj op restore`
- Debugging what went wrong? `jj op log` shows everything
- Supervisor can always recover to known-good state

#### First-Class Conflict Handling

In Git, conflicts block all progress until resolved. In Jujutsu:

```bash
# Conflict is stored IN the commit
jj new           # Create new commit on top of conflict
jj edit          # Continue working
# Resolve conflict later, resolution auto-propagates to descendants
```

**Why this matters for Nancy:**

- Agent hits conflict? Work continues on other parts
- Resolution propagates automatically when applied
- No stuck states requiring human intervention

#### Automatic Snapshots

```bash
# In Git:
# (work) -> git add . -> git commit -m "WIP" -> (more work) -> git commit --amend

# In Jujutsu:
# (work) -> (automatically committed) -> (more work) -> (automatically amended)
```

> "I'll just be like, snapshot at this point, and then continue... In Jujutsu, it's the default behavior."
> — Mitchell Hashimoto

**Why this matters for Nancy:**

- Every state is recoverable by default
- No "forgot to commit" problems
- Natural checkpoint/rollback workflow

---

## Part 2: The Nancy + Jujutsu Workflow

### Single Agent Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│  Nancy Worker with Jujutsu                                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Worker starts on Linear issue                               │
│     └─ jj new -m "nancy: starting ALP-75"                      │
│                                                                 │
│  2. Worker makes changes (auto-committed)                       │
│     └─ Working copy always equals latest commit                │
│                                                                 │
│  3. Checkpoint before risky operation                           │
│     └─ jj commit -m "checkpoint: before refactor"              │
│                                                                 │
│  4. Risky refactor fails                                        │
│     └─ jj undo  # Instant recovery                             │
│                                                                 │
│  5. Try different approach (succeeds)                           │
│     └─ Changes auto-committed                                  │
│                                                                 │
│  6. Clean up history for PR                                     │
│     └─ jj squash  # Combine WIP commits                        │
│     └─ jj describe -m "feat: implement cost estimation"        │
│                                                                 │
│  7. Push to Git remote (jj is Git-compatible)                   │
│     └─ jj git push -c @                                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Parallel Agent Workflow

For multiple agents working simultaneously, combine Jujutsu with colocated repos:

```
project/
├── .jj/                    # Shared Jujutsu repo
├── main/                   # Main working copy
├── workers/
│   ├── agent-1/           # Colocated working copy for Agent 1
│   ├── agent-2/           # Colocated working copy for Agent 2
│   └── agent-3/           # Colocated working copy for Agent 3
```

```bash
# Create colocated working copies (like git worktrees but better)
jj workspace add workers/agent-1 --name agent-1
jj workspace add workers/agent-2 --name agent-2

# Each agent works independently
# All share same history, conflicts auto-detected
```

**Advantages over Git worktrees:**

- Anonymous commits reduce branch naming overhead
- Conflicts stored in commits, not blocking
- Operation log spans all workspaces
- Automatic rebasing when base changes

### The Supervisor Pattern

```
┌─────────────────────────────────────────────────────────────────┐
│  Supervisor (Orchestrator)                                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Responsibilities:                                              │
│  1. Checkpoint before dispatching agent                         │
│     └─ op_id = $(jj op log -n1 --no-graph -T 'operation_id')   │
│                                                                 │
│  2. Monitor agent progress                                      │
│     └─ Check Linear comments for status                        │
│                                                                 │
│  3. On agent failure/timeout:                                   │
│     └─ jj op restore $op_id  # Guaranteed recovery             │
│                                                                 │
│  4. On agent success:                                           │
│     └─ jj squash  # Clean up messy history                     │
│     └─ jj describe -m "feat(ALP-75): ..."                      │
│     └─ jj git push  # Create PR                                │
│                                                                 │
│  5. Post summary to Linear                                      │
│     └─ linear::create_comment with PR link                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Part 3: Linear Integration Design

### Workflow States

```
┌──────────────────────────────────────────────────────────────────┐
│  Linear Issue States                                             │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Backlog  ──────────────────────────────────────────────────┐   │
│     │                                                        │   │
│     │ (Human: spec ready)                                    │   │
│     ▼                                                        │   │
│  Todo  ─────────────────────────────────────────────────┐   │   │
│     │                                                    │   │   │
│     │ (Nancy: picks up, posts "Starting - Session: X")  │   │   │
│     ▼                                                    │   │   │
│  In Progress  ──────────────────────────────────────┐   │   │   │
│     │                                                │   │   │   │
│     │ (Nancy: posts progress, checkpoints in jj)    │   │   │   │
│     │                                                │   │   │   │
│     ├─── (Blocker) ──► posts question, waits ───────┼───┘   │   │
│     │                                                │       │   │
│     │ (Nancy: completes, posts summary + PR link)   │       │   │
│     ▼                                                │       │   │
│  In Review  ────────────────────────────────────────┤       │   │
│     │                                                │       │   │
│     ├─── (Human: changes needed) ───────────────────┴───────┘   │
│     │                                                            │
│     │ (Human: approved)                                          │
│     ▼                                                            │
│  Done                                                            │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### Session Tracking

**Session ID Format:**

```
nancy-{issue-id}-iter{iteration}

Examples:
nancy-ALP-75-iter1
nancy-ALP-75-iter2  (after changes requested)
```

**Linear Comment Templates:**

```markdown
## Starting - Session: nancy-ALP-75-iter1

**Checkpoint:** `jj op: abc123`
**Branch:** `nancy/ALP-75`

Reading issue description and planning approach...
```

```markdown
## Progress - Session: nancy-ALP-75-iter1

### Completed

- [x] Analyzed existing cost calculation logic
- [x] Created estimation service module

### In Progress

- [ ] Implementing UI components

### Checkpoint

`jj op: def456` (recoverable)
```

```markdown
## Complete - Session: nancy-ALP-75-iter1

### Summary

Implemented cost estimation feature with 3 endpoints and React components.

### Changes

- `src/services/cost-estimator.ts` (new)
- `src/components/CostBreakdown.tsx` (new)
- `src/api/routes/estimates.ts` (modified)

### PR

[#142: feat(ALP-75): Add cost estimation](https://github.com/...)

### Recovery Point

`jj op: ghi789` (if changes needed)
```

### MCP Integration

Use Linear's official MCP server (HTTP transport preferred):

```yaml
# .claude/settings.json
{
  "mcpServers":
    {
      "linear":
        {
          "command": "npx",
          "args": ["-y", "mcp-remote", "https://mcp.linear.app/mcp"],
        },
    },
}
```

**Available Operations:**

- `list_issues` - Query by state, priority, project
- `get_issue` - Fetch full issue details
- `update_issue` - Change state, assignee
- `create_comment` - Post progress/completion
- `list_comments` - Fetch previous session context

---

## Part 4: Implementation Architecture

### Directory Structure

```
.nancy/
├── config.yaml              # Nancy configuration
├── tasks/
│   └── {task-name}/
│       ├── SPEC.md          # (Optional if using Linear)
│       ├── PROMPT.md        # Worker prompt (generated)
│       ├── sessions/        # Session transcripts
│       └── jj-ops/          # Jujutsu operation checkpoints
│           ├── start.txt    # Op ID at session start
│           └── checkpoints/ # Named checkpoints
└── workers/                 # Jujutsu workspaces for parallel agents
    ├── agent-1/
    ├── agent-2/
    └── agent-3/
```

### Configuration

```yaml
# .nancy/config.yaml

# Version Control
vcs:
  backend: jujutsu # or "git" for fallback

  jujutsu:
    auto_checkpoint: true # Checkpoint before risky ops
    checkpoint_interval: "5m" # Periodic checkpoints
    cleanup_on_success: true # Squash WIP commits on completion

  parallel:
    enabled: true
    max_workers: 4
    isolation: workspace # jj workspace (or "worktree" for git)

# Linear Integration
linear:
  enabled: true
  server: "https://mcp.linear.app/mcp"

  workspace:
    team: "Alphabio"
    project: "Nancy"

  task_source:
    state: "Todo"
    order_by: "priority"
    labels: []

  states:
    picked: "In Progress"
    complete: "In Review"
    approved: "Done"
    rejected: "Todo"

  comments:
    on_start: true
    on_progress: "milestone" # "interval:5m", "milestone", or "never"
    on_complete: true
    include_session_id: true
    include_jj_checkpoint: true
    include_pr_link: true

# Worker Configuration
worker:
  prompt_template: "templates/PROMPT.md.template"

  context:
    fetch_linear_description: true
    fetch_previous_sessions: true
    include_jj_status: true
```

### Worker Prompt Template

````markdown
# Nancy Worker - {{LINEAR_ISSUE_ID}}

**Session:** `{{SESSION_ID}}`
**Linear Issue:** [{{LINEAR_ISSUE_ID}}]({{LINEAR_ISSUE_URL}})
**Recovery Point:** `jj op: {{JJ_START_OP}}`

## Context from Linear

{{ISSUE_DESCRIPTION}}

## Previous Sessions

{{PREVIOUS_SESSION_SUMMARIES}}

## Jujutsu Commands

You have Jujutsu (jj) available instead of Git. Key commands:

```bash
# Your changes are auto-committed. To see status:
jj status

# Create named checkpoint before risky operation:
jj commit -m "checkpoint: before refactor"

# If something goes wrong:
jj undo              # Undo last operation
jj op restore @--    # Go back 2 operations

# When done, clean up history:
jj squash            # Combine recent commits
jj describe -m "feat({{LINEAR_ISSUE_ID}}): description"

# Push to create PR:
jj git push -c @
```
````

## Work Loop

1. Read issue description fully
2. Break into discrete tasks
3. Checkpoint before risky operations
4. Use `jj undo` freely if experiments fail
5. Post progress to Linear periodically
6. Clean up history before pushing

## Completion

When done:

1. `jj squash` to clean history
2. `jj git push -c @` to create PR
3. Post completion comment to Linear with PR link
4. Update issue state to "In Review"

````

### Lifecycle Hooks

```bash
# hooks/on_worker_start.sh
#!/bin/bash
issue_id="$1"
session_id="$2"

# Record starting operation for recovery
jj_op=$(jj op log -n1 --no-graph -T 'operation_id')
echo "$jj_op" > ".nancy/tasks/$issue_id/jj-ops/start.txt"

# Update Linear
linear::update_issue "$issue_id" --state "In Progress"
linear::create_comment "$issue_id" "$(cat <<EOF
## Starting - Session: $session_id

**Recovery Point:** \`jj op: $jj_op\`

Reading issue and planning approach...
EOF
)"
````

```bash
# hooks/on_worker_checkpoint.sh
#!/bin/bash
issue_id="$1"
checkpoint_name="$2"
summary="$3"

# Create named checkpoint
jj commit -m "checkpoint: $checkpoint_name"
jj_op=$(jj op log -n1 --no-graph -T 'operation_id')

# Save checkpoint
echo "$jj_op" > ".nancy/tasks/$issue_id/jj-ops/checkpoints/$checkpoint_name.txt"

# Post to Linear
linear::create_comment "$issue_id" "$(cat <<EOF
## Checkpoint: $checkpoint_name

$summary

**Recovery Point:** \`jj op: $jj_op\`
EOF
)"
```

```bash
# hooks/on_worker_complete.sh
#!/bin/bash
issue_id="$1"
session_id="$2"
summary="$3"

# Clean up history
jj squash
jj describe -m "feat($issue_id): $summary"

# Push to create PR
pr_output=$(jj git push -c @ 2>&1)
pr_url=$(echo "$pr_output" | grep -o 'https://github.com/[^ ]*')

# Record final op
jj_op=$(jj op log -n1 --no-graph -T 'operation_id')

# Update Linear
linear::create_comment "$issue_id" "$(cat <<EOF
## Complete - Session: $session_id

### Summary
$summary

### PR
[$pr_url]($pr_url)

### Recovery Point
\`jj op: $jj_op\` (if changes needed)
EOF
)"

linear::update_issue "$issue_id" --state "In Review"
```

```bash
# hooks/on_worker_failure.sh
#!/bin/bash
issue_id="$1"
session_id="$2"
error="$3"

# Get start op for recovery instructions
start_op=$(cat ".nancy/tasks/$issue_id/jj-ops/start.txt")

# Post to Linear
linear::create_comment "$issue_id" "$(cat <<EOF
## Failed - Session: $session_id

### Error
\`\`\`
$error
\`\`\`

### Recovery
To restore to session start:
\`\`\`bash
jj op restore $start_op
\`\`\`

### Next Steps
- Review error and fix issue description
- Move back to Todo when ready for retry
EOF
)"

# Don't change state - leave In Progress for manual review
```

---

## Part 5: Migration Path

### Phase 1: Jujutsu Evaluation (Now)

**Goal:** Validate jj works for Nancy's use case

```bash
# Install jujutsu
brew install jj  # or cargo install jj-cli

# Initialize existing repo
cd project
jj git init --colocate

# Test basic workflow
jj status
jj commit -m "test"
jj undo
jj op log
```

**Success criteria:**

- [ ] Basic commands work (`jj status`, `jj commit`, `jj undo`)
- [ ] Git push/pull works (`jj git push`, `jj git fetch`)
- [ ] Workspaces work for parallel agents
- [ ] Operation log enables reliable recovery

### Phase 2: Single-Agent Integration (Next)

**Goal:** Nancy worker uses jj instead of git

**Changes:**

1. Add `vcs.backend: jujutsu` config option
2. Update worker prompt with jj commands
3. Add lifecycle hooks with jj checkpointing
4. Test with single agent on real Linear issue

**Success criteria:**

- [ ] Worker can complete task using jj
- [ ] Checkpoints posted to Linear work
- [ ] Recovery via `jj undo` / `jj op restore` works
- [ ] PR created via `jj git push`

### Phase 3: Parallel Agents (Later)

**Goal:** Multiple agents work simultaneously with jj workspaces

**Changes:**

1. Add workspace management to Nancy
2. Implement agent isolation via `jj workspace add`
3. Add file-level lock tracking (prevention)
4. Add merge coordination for completed work

**Success criteria:**

- [ ] 2-3 agents work in parallel without conflicts
- [ ] Each agent has isolated workspace
- [ ] Work merges cleanly after completion
- [ ] Conflicts detected early, not at merge time

### Phase 4: Full Linear Integration (Future)

**Goal:** Linear is the only interface needed

**Changes:**

1. `nancy start` queries Linear for highest priority Todo
2. No local SPEC.md - issue description IS the spec
3. `@nancy` mentions trigger worker (requires Linear Agent SDK)
4. Full bidirectional comment sync

**Success criteria:**

- [ ] Start work by assigning issue to Nancy in Linear
- [ ] All progress visible in Linear
- [ ] No local Nancy commands needed for basic workflow

---

## Part 6: agentic-jujutsu Integration (Experimental)

The [agentic-jujutsu](https://www.npmjs.com/package/agentic-jujutsu) npm package provides additional capabilities:

```bash
npm install agentic-jujutsu
```

**Features:**

- Lock-free concurrency (10-100x faster parallel ops claimed)
- MCP Protocol integration for AI agents
- Pattern learning from past operations
- 87% automatic conflict resolution (claimed)

**Evaluation needed:**

- [ ] Does it add value over raw jj?
- [ ] Is it stable enough for production?
- [ ] Does the MCP integration work with Claude Code?

---

## Part 7: Comparison Summary

### Git vs Jujutsu for Nancy

| Aspect                | Git                         | Jujutsu                 | Winner      |
| --------------------- | --------------------------- | ----------------------- | ----------- |
| **Learning curve**    | Industry standard           | New tool to learn       | Git         |
| **Recovery**          | Complex (`reflog`, `reset`) | Simple (`jj undo`)      | **Jujutsu** |
| **Parallel work**     | Worktrees (separate dirs)   | Workspaces (same repo)  | **Jujutsu** |
| **Conflict handling** | Blocking                    | Non-blocking            | **Jujutsu** |
| **AI suitability**    | Not designed for            | Explicitly designed for | **Jujutsu** |
| **History cleanup**   | Interactive rebase          | Scriptable commands     | **Jujutsu** |
| **Ecosystem**         | Universal                   | Growing                 | Git         |
| **Git compatibility** | Native                      | Full (colocated repos)  | Tie         |

### Recommendation

**Use Jujutsu for Nancy** with Git as the backend (colocated repos).

- All Git tooling (GitHub, CI, etc.) continues to work
- Agents get bulletproof recovery via operation log
- Parallel execution is simpler with workspaces
- History cleanup is scriptable, not interactive

The only downside is teaching agents new commands, which is a one-time prompt update.

---

## Sources

### Jujutsu

- [GitHub: jj-vcs/jj](https://github.com/jj-vcs/jj) - 25k+ stars
- [Jujutsu Documentation](https://docs.jj-vcs.dev/latest/)
- [Use Jujutsu, Not Git (Alpha Insights)](https://slavakurilyak.com/posts/use-jujutsu-not-git)
- [Ian Bull: AI-Native Development Workflow](https://ianbull.com/posts/jj-vibes)

### Linear

- [Linear for Agents](https://linear.app/agents)
- [Agent Interaction SDK](https://linear.app/developers/agent-interaction)
- [MCP Server Documentation](https://linear.app/docs/mcp)
- [GitHub Copilot + Linear](https://linear.app/changelog/2025-10-28-github-copilot-agent)

### Orchestration

- [claude-flow](https://github.com/ruvnet/claude-flow) - Multi-agent swarms
- [mcp-agent](https://github.com/lastmile-ai/mcp-agent) - MCP workflow patterns
- [Swarm-IOSM](https://dev.to/rokoss21/swarm-iosm-orchestrating-parallel-ai-agents-with-quality-gates-8fk)
- [agentic-jujutsu](https://www.npmjs.com/package/agentic-jujutsu)

### Git Workflows

- [Git Worktrees for AI Agents](https://nx.dev/blog/git-worktrees-ai-agents)
- [Graphite MCP](https://graphite.com/docs/gt-mcp)
- [GitHub Agent HQ](https://github.blog/ai-and-ml/github-copilot/how-to-orchestrate-agents-using-mission-control/)
