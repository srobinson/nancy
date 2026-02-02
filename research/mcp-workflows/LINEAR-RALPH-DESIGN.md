# Nancy + Linear Integration Design

> Linear as the source of truth. Git/GitHub for version control. Conflict prevention through smart task management.

## Core Principle

**We control the backlog.** If we control what work gets dispatched and when, we prevent conflicts at the source - not at merge time.

---

## Part 1: The Workflow

### Interactive Mode (Human + Claude)

```
┌─────────────────────────────────────────────────────────────────┐
│  Interactive Session                                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Discuss idea/problem                                        │
│  2. Create Linear issue (Backlog)                              │
│     - Title, description, labels                               │
│     - NO implementation details yet                            │
│                                                                 │
│  3. When ready to implement:                                    │
│     - Flesh out issue description with:                        │
│       • Clear scope                                            │
│       • Success criteria                                       │
│       • File boundaries (what CAN be touched)                  │
│     - Move to Todo                                             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Worker Mode (Autonomous)

```
┌─────────────────────────────────────────────────────────────────┐
│  Nancy Worker                                                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Query Linear: highest priority Todo issue                   │
│     └─ list_issues(state="Todo", project="Nancy", order="priority")
│                                                                 │
│  2. Claim issue                                                 │
│     └─ update_issue(state="In Progress")                       │
│     └─ create_comment("🤖 Starting - Session: {session_id}")   │
│                                                                 │
│  3. Create branch                                               │
│     └─ git checkout -b nancy/{issue-id}                        │
│                                                                 │
│  4. Work loop                                                   │
│     └─ Read issue description as spec                          │
│     └─ Implement changes                                       │
│     └─ Commit with: nancy({issue-id}): {description}           │
│     └─ Post progress comments periodically                     │
│                                                                 │
│  5. Complete                                                    │
│     └─ Push branch, create PR                                  │
│     └─ create_comment("✅ Complete - PR: {url}")               │
│     └─ update_issue(state="In Review")                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Review Mode (Human)

```
┌─────────────────────────────────────────────────────────────────┐
│  Human Review                                                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Check "In Review" issues in Linear                         │
│  2. Review linked PR                                           │
│                                                                 │
│  3a. Approved:                                                  │
│      └─ Merge PR                                               │
│      └─ update_issue(state="Done")                             │
│                                                                 │
│  3b. Changes needed:                                            │
│      └─ Add comment with feedback                              │
│      └─ update_issue(state="Todo")                             │
│      └─ Worker picks up again in next iteration                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Part 2: Issue Structure

### Issue Description Template

```markdown
## Goal

[One sentence: what should be true when this is done]

## Success Criteria

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## Scope

**Files to modify:**
- `src/feature/*.ts`
- `tests/feature/*.test.ts`

**Off limits:**
- `src/core/*` (shared infrastructure)
- `src/auth/*` (owned by other task)

## Context

[Any background the worker needs]

## Notes

[Implementation hints, constraints, preferences]
```

### Why Scope Matters

The **Scope** section is how we prevent conflicts:

```
Issue ALP-75: Add cost estimation
  Scope: src/services/cost-estimator.ts, src/api/pricing/*

Issue ALP-76: Add usage tracking
  Scope: src/services/usage-tracker.ts, src/api/metrics/*

Issue ALP-77: Refactor shared types
  Scope: src/types/*
  ⚠️ BLOCKS: ALP-75, ALP-76 (must complete first)
```

If scopes overlap → issues should be sequential (use Linear's blocking feature).

---

## Part 3: Conflict Prevention Strategy

### Rule 1: One Writer Per File

Before moving issue to Todo, check:
- Does this issue's scope overlap with any In Progress issue?
- If yes: Either wait, or adjust scope

### Rule 2: Use Linear's Blocking Feature

```
ALP-77 (shared types) ──blocks──► ALP-75, ALP-76

Must complete ALP-77 first, then ALP-75/76 can run in parallel
```

### Rule 3: Decompose Large Tasks

**Bad:**
```
Issue: "Implement authentication system"
Scope: src/auth/*, src/api/*, src/middleware/*, src/types/*
```

**Good:**
```
Issue: "Add auth types and interfaces"
Scope: src/types/auth.ts
Blocks: next 3 issues

Issue: "Implement auth service"
Scope: src/auth/service.ts
Blocked by: types issue

Issue: "Add auth API endpoints"
Scope: src/api/auth/*
Blocked by: service issue

Issue: "Add auth middleware"
Scope: src/middleware/auth.ts
Blocked by: endpoints issue
```

### Rule 4: Parallel Only When Truly Isolated

```
✅ Can run in parallel:
- ALP-80: Add feature A (src/features/a/*)
- ALP-81: Add feature B (src/features/b/*)
- ALP-82: Update docs (docs/*)

❌ Cannot run in parallel:
- ALP-83: Refactor API layer (src/api/*)
- ALP-84: Add new endpoint (src/api/users.ts)
```

---

## Part 4: Session Tracking

### Session ID Format

```
nancy-{issue-id}-iter{n}

Examples:
nancy-ALP-75-iter1    # First attempt
nancy-ALP-75-iter2    # After review feedback
nancy-ALP-75-iter3    # After more feedback
```

### Comment Templates

**On Start:**
```markdown
## 🤖 Starting - Session: nancy-ALP-75-iter1

Reading issue and planning approach...

**Branch:** `nancy/ALP-75`
```

**Progress Update:**
```markdown
## 📊 Progress - Session: nancy-ALP-75-iter1

### Completed
- [x] Created cost estimation service
- [x] Added API endpoint

### In Progress
- [ ] Writing tests

### Commits
- `abc123` nancy(ALP-75): add cost estimation service
- `def456` nancy(ALP-75): add pricing endpoint
```

**On Complete:**
```markdown
## ✅ Complete - Session: nancy-ALP-75-iter1

### Summary
Implemented cost estimation with OpenAI pricing models.

### Changes
- `src/services/cost-estimator.ts` (new)
- `src/api/pricing.ts` (new)
- `tests/services/cost-estimator.test.ts` (new)

### PR
[#142: feat(ALP-75): Add cost estimation](https://github.com/org/repo/pull/142)

### Success Criteria
- [x] Estimates token costs before API calls
- [x] Shows estimated cost in CLI output
- [x] Tests cover main scenarios
```

**On Blocker:**
```markdown
## ⚠️ Blocked - Session: nancy-ALP-75-iter1

### Issue
The spec mentions "industry standard pricing" but doesn't specify which model.

### Options
A) Use OpenAI pricing (text-embedding-3-small: $0.02/1M tokens)
B) Use Anthropic pricing (claude-3-haiku: $0.25/1M input)
C) Make it configurable

### Request
Please reply with preferred approach to unblock.
```

---

## Part 5: Implementation

### Directory Structure

```
.nancy/
├── config.yaml
└── tasks/
    └── {issue-id}/           # e.g., ALP-75/
        ├── session.txt       # Current session ID
        ├── PROMPT.md         # Generated worker prompt
        └── sessions/
            ├── iter1/
            │   └── transcript.md
            └── iter2/
                └── transcript.md
```

### Configuration

```yaml
# .nancy/config.yaml

linear:
  enabled: true

  workspace:
    team: "Alphabio"
    project: "Nancy"

  task_source:
    state: "Todo"
    order_by: "priority"  # highest priority first

  states:
    working: "In Progress"
    complete: "In Review"
    approved: "Done"
    rejected: "Todo"

  comments:
    on_start: true
    on_progress: true      # Post progress updates
    on_complete: true
    on_blocker: true
    include_session_id: true
    include_pr_link: true

git:
  branch_prefix: "nancy/"
  commit_prefix: "nancy({issue-id}):"

  pr:
    draft: false
    auto_create: true
    title_template: "feat({issue-id}): {issue-title}"
```

### Worker Prompt Template

```markdown
# Nancy Worker - {{ISSUE_ID}}

**Session:** `{{SESSION_ID}}`
**Linear Issue:** [{{ISSUE_ID}}: {{ISSUE_TITLE}}]({{ISSUE_URL}})

## Your Task

{{ISSUE_DESCRIPTION}}

## Previous Sessions

{{#if PREVIOUS_SESSIONS}}
{{PREVIOUS_SESSIONS}}
{{else}}
This is the first iteration.
{{/if}}

## Git Workflow

1. You're on branch: `nancy/{{ISSUE_ID}}`
2. Commit frequently: `nancy({{ISSUE_ID}}): description`
3. When complete: Push and create PR

## Linear Updates

Post progress to Linear using the Linear MCP tools:
- `create_comment` for progress updates
- `update_issue` to change state

## Completion Checklist

Before marking complete:
1. All success criteria in issue description are met
2. Code compiles/passes linting
3. Tests pass (if applicable)
4. PR created and linked in Linear comment
5. Issue moved to "In Review"
```

### Lifecycle Hooks (Bash)

```bash
# hooks/linear/on_start.sh
#!/bin/bash
set -e

issue_id="$1"
session_id="$2"

# Update Linear
claude --print "Update Linear issue $issue_id to In Progress and post starting comment" \
  --allowedTools "mcp__linear-server__update_issue,mcp__linear-server__create_comment"

# Create branch
git checkout -b "nancy/$issue_id" 2>/dev/null || git checkout "nancy/$issue_id"
```

```bash
# hooks/linear/on_complete.sh
#!/bin/bash
set -e

issue_id="$1"
session_id="$2"
summary="$3"

# Push and create PR
git push -u origin "nancy/$issue_id"
pr_url=$(gh pr create --title "feat($issue_id): $summary" --body "Closes $issue_id" --fill)

# Update Linear
claude --print "Post completion comment to Linear issue $issue_id with PR link: $pr_url, then move to In Review" \
  --allowedTools "mcp__linear-server__update_issue,mcp__linear-server__create_comment"
```

---

## Part 6: Parallel Execution (Future)

When we're ready for multiple workers:

### Strategy: Worker Pool with Scope Checking

```
┌─────────────────────────────────────────────────────────────────┐
│  Dispatcher                                                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Query Todo issues ordered by priority                       │
│                                                                 │
│  2. For each issue, check:                                      │
│     - Is scope defined?                                        │
│     - Does scope overlap with any In Progress issue?           │
│     - Is issue blocked by another issue?                       │
│                                                                 │
│  3. Dispatch to available worker if:                           │
│     - Scope is defined AND                                     │
│     - No overlap with In Progress AND                          │
│     - Not blocked                                              │
│                                                                 │
│  4. Otherwise: Skip, try next issue                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Scope Extraction

Parse issue description for scope:

```markdown
## Scope

**Files to modify:**
- `src/api/pricing.ts`
- `src/services/cost-*.ts`

**Off limits:**
- `src/core/*`
```

Extract into:
```json
{
  "include": ["src/api/pricing.ts", "src/services/cost-*.ts"],
  "exclude": ["src/core/*"]
}
```

Check overlap using glob matching before dispatch.

### Labels for Quick Filtering

```
Labels:
- `scope:api` - touches src/api/*
- `scope:services` - touches src/services/*
- `scope:tests` - touches tests/*
- `scope:docs` - touches docs/*
- `parallel-safe` - explicitly marked as isolated
```

Quick check: No two In Progress issues should share a scope label.

---

## Part 7: Success Metrics

Track to validate the workflow:

| Metric | Target | Why |
|--------|--------|-----|
| Merge conflict rate | <5% | Prevention working |
| First-attempt success | >70% | Issues well-specified |
| Time in Review | <24h | Human bottleneck |
| Iteration count | <2 avg | Specs clear enough |

---

## Part 8: Migration Path

### Phase 1: Single Worker (Now)

1. Create Linear issues with scope sections
2. Worker queries Linear for highest priority Todo
3. Worker posts comments, creates PRs
4. Human reviews, moves to Done

**Test with:** 3-5 real issues from mdcontext backlog

### Phase 2: Review Workflow (Next)

1. Add review checklist to PR template
2. Track review time metrics
3. Automate "changes requested" → back to Todo

### Phase 3: Parallel Workers (Later)

1. Add scope parsing
2. Add overlap detection
3. Run 2 workers on isolated tasks
4. Scale up gradually

### Phase 4: Full Automation (Future)

1. Auto-decompose large issues
2. Auto-detect scope from code analysis
3. Auto-assign based on capacity
4. `@nancy` mentions in Linear trigger work

---

## Quick Reference

### Linear MCP Tools

```
list_issues      - Query issues (state, project, priority)
get_issue        - Get full issue details
update_issue     - Change state, assignee, etc.
create_comment   - Post progress/completion
list_comments    - Get previous session context
```

### Git Commands

```bash
git checkout -b nancy/{issue-id}     # Create branch
git commit -m "nancy({id}): msg"     # Commit
git push -u origin nancy/{issue-id}  # Push
gh pr create --fill                   # Create PR
```

### Session Flow

```
Todo → In Progress → [work] → In Review → Done
              ↑                    │
              └── (changes needed) ┘
```
