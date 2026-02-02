# Nancy + Linear Integration Design (v2)

> Linear as the source of truth. Git/GitHub for version control. Prevention through smart backlog management.

## Core Principle

**We control the backlog.** Sequential dispatch of dependent work. Parallel only for truly independent features. No fine-grained file scoping - if you're analyzing that deeply, just do the work.

---

## Part 1: Issue Structure

### Issue Description Template

```markdown
## Description

[What needs to be built/changed and why. Be as detailed as needed -
this IS the spec. Include background, motivation, technical context.]

## Acceptance Criteria

- [ ] Criterion 1: specific, testable outcome
- [ ] Criterion 2: specific, testable outcome
- [ ] Criterion 3: specific, testable outcome

## Context

[Links to related issues, docs, or code. Prior art. Dependencies.]

## Notes

[Implementation hints, constraints, preferences, gotchas to watch for.]
```

### Labels Strategy

| Label                 | Purpose                              |
| --------------------- | ------------------------------------ |
| `epic:{name}`         | Groups related issues                |
| `type:feature`        | New functionality                    |
| `type:bug`            | Fix existing behavior                |
| `type:refactor`       | Code improvement, no behavior change |
| `type:docs`           | Documentation only                   |
| `blocked`             | Waiting on something                 |
| `needs-decomposition` | Too large, needs breakdown           |

### Priority = Dispatch Order

Linear's priority field determines what gets worked on:

- **Urgent** - Drop everything
- **High** - Next up
- **Medium** - In the queue
- **Low** - Eventually
- **No priority** - Backlog parking lot

Worker always picks highest priority **Todo** issue.

---

## Part 2: The Workflow

### States

```
Backlog → Todo → In Progress → In Review → Done
                      ↑              │
                      └── (changes) ─┘
```

| State           | Meaning                           |
| --------------- | --------------------------------- |
| **Backlog**     | Idea captured, not ready for work |
| **Todo**        | Fully specified, ready for worker |
| **In Progress** | Worker actively working           |
| **In Review**   | PR created, awaiting human review |
| **Done**        | Merged and deployed               |

### Interactive Mode (Human + Claude)

1. Discuss idea/problem
2. Create issue in **Backlog** with rough description
3. When ready: flesh out description, add acceptance criteria
4. Move to **Todo**

### Worker Mode (Nancy)

1. Query: `list_issues(state="Todo", project="Nancy", orderBy="priority")`
2. Pick highest priority issue
3. Update: `update_issue(state="In Progress")`
4. Post starting comment
5. Create branch: `git checkout -b ALP-75-short-description`
6. Work, commit frequently
7. When done:

   ```bash
   git fetch origin main
   git rebase origin/main
   # resolve conflicts if any
   git push -u origin ALP-75-short-description
   gh pr create --fill-verbose
   ```

8. Post completion comment with PR link
9. **PR creation → Linear auto-updates to In Review**
10. **PR merge → Linear auto-updates to Done**

### Review Mode (Human)

1. Review PR in GitHub
2. **Approve** → Merge → Linear auto-moves to Done
3. **Request changes** → Comment in Linear → Move to Todo

---

## Part 3: Multi-Iteration Support

A single issue often takes multiple Nancy sessions (token limits, blockers, review feedback).

### Session ID Format

```
nancy-{issue-id}-iter{n}

Examples:
nancy-ALP-75-iter1    # First attempt
nancy-ALP-75-iter2    # After review feedback
nancy-ALP-75-iter3    # After more feedback
```

### Iteration Triggers

| Trigger         | What Happens                                                           |
| --------------- | ---------------------------------------------------------------------- |
| Token limit     | Worker commits, posts progress, stops. Next session continues.         |
| Blocker         | Worker posts question, moves to blocked. Human responds, back to Todo. |
| Review feedback | Human requests changes, back to Todo. Worker picks up iter+1.          |

### Context Across Iterations

Use `git log` for previous work context:

```bash
git log --format=full origin/main..HEAD
```

This shows all commits on the branch - the worker's own previous work.

---

## Part 4: Comment Templates

### On Start

```markdown
## 🤖 Starting - Session: nancy-ALP-75-iter1

Reading issue and planning approach...

**Branch:** `ALP-75-cost-estimation`
```

### Progress Update

```markdown
## 📊 Progress - Session: nancy-ALP-75-iter1

### Completed

- [x] Created cost estimation service
- [x] Added API endpoint

### In Progress

- [ ] Writing tests

### Commits

- `abc123` feat(ALP-75): add cost estimation service
- `def456` feat(ALP-75): add pricing endpoint
```

### On Complete

```markdown
## ✅ Complete - Session: nancy-ALP-75-iter1

### Summary

Implemented cost estimation with OpenAI pricing models.

### PR

[#142: feat(ALP-75): Add cost estimation](https://github.com/org/repo/pull/142)

### Acceptance Criteria Status

- [x] Estimates token costs before API calls
- [x] Shows estimated cost in CLI output
- [x] Tests cover main scenarios
```

### On Blocker

```markdown
## ⚠️ Blocked - Session: nancy-ALP-75-iter1

### Issue

The description mentions "industry standard pricing" but doesn't specify which model.

### Options

A) Use OpenAI pricing (text-embedding-3-small: $0.02/1M tokens)
B) Use Anthropic pricing (claude-3-haiku: $0.25/1M input)
C) Make it configurable

### Request

Please reply with preferred approach to unblock.
```

### On Token Limit

```markdown
## ⏸️ Pausing - Session: nancy-ALP-75-iter1

### Progress So Far

- [x] Created service skeleton
- [x] Implemented token counting
- [ ] Cost calculation (in progress)

### Commits Pushed

- `abc123` feat(ALP-75): add cost estimation service skeleton
- `def456` feat(ALP-75): implement token counting

### Next Session

Continue with cost calculation logic in `src/services/cost-estimator.ts:45`
```

---

## Part 5: GitHub ↔ Linear Integration

### Auto-Linking

Linear's GitHub integration auto-links when:

- Branch name contains issue ID: `ALP-75-description`
- PR title contains issue ID: `feat(ALP-75): description`
- PR description contains: `Closes ALP-75`

### Auto-Status Updates

With GitHub integration enabled:

- PR opened → Issue stays In Progress
- PR merged → Issue moves to Done (automatic!)

So worker only needs to:

1. Move to **In Progress** on start (manual)
2. **In Review** happens automatically when PR created
3. **Done** happens automatically on PR merge

### PR Template

```markdown
## Summary

{Brief description of changes}

## Linear Issue

Closes ALP-{id}

## Changes

- Change 1
- Change 2

## Testing

- [ ] Tests pass
- [ ] Manual testing done

---

🤖 Generated by Nancy - Session: nancy-ALP-{id}-iter{n}
```

---

## Part 6: Foundational Docs

Agents can pull these for context:

### `.nancy/docs/PROJECT.md`

```markdown
# Project: {name}

## Overview

{What this project does, who it's for}

## Architecture

{High-level system design, key components}

## Tech Stack

- Language: TypeScript
- Framework: {x}
- Database: {y}

## Key Concepts

{Domain-specific terms and their meanings}

## Development Setup

{How to get running locally}
```

### `.nancy/docs/CODING-STYLE.md`

```markdown
# Coding Style Guide

## TypeScript

- Use strict mode
- Prefer interfaces over types for objects
- Use explicit return types on exported functions

## Naming

- Files: kebab-case
- Classes: PascalCase
- Functions/variables: camelCase
- Constants: SCREAMING_SNAKE_CASE

## Patterns

- Prefer composition over inheritance
- Use dependency injection
- Error handling: {approach}

## Testing

- Test file naming: `*.test.ts`
- Prefer integration tests over unit tests
- Mock external services, not internal modules

## Commits

- Format: `type(scope): description`
- Types: feat, fix, refactor, test, docs, chore
```

### `.nancy/docs/CONVENTIONS.md`

```markdown
# Project Conventions

## API Design

{REST conventions, error formats, etc.}

## File Organization

{Where things go}

## Dependencies

{How to add, what to avoid}

## Configuration

{Env vars, config files}
```

### Worker Prompt Integration

Worker prompt includes:

```markdown
## Project Context

{{#if PROJECT_DOC}}

### Project Overview

{{PROJECT_DOC}}
{{/if}}

{{#if CODING_STYLE}}

### Coding Style

{{CODING_STYLE}}
{{/if}}
```

---

## Part 7: Configuration

```yaml
# .nancy/config.yaml

linear:
  enabled: true
  team: "Alphabio"
  project: "Nancy"

  states:
    ready: "Todo"
    working: "In Progress"
    review: "In Review"
    done: "Done"

git:
  main_branch: "main"
  branch_format: "{issue-id}-{slug}" # ALP-75-cost-estimation
  commit_format: "feat({issue-id}): {message}"

github:
  auto_pr: true
  pr_template: ".nancy/templates/PR.md"

docs:
  project: ".nancy/docs/PROJECT.md"
  coding_style: ".nancy/docs/CODING-STYLE.md"
  conventions: ".nancy/docs/CONVENTIONS.md"
```

---

## Part 8: API Options

### Option A: Direct MCP Tools

Worker uses Linear MCP tools directly:

```
mcp__linear-server__update_issue
mcp__linear-server__create_comment
mcp__linear-server__list_issues
```

Pros: Built into Claude Code, no extra setup
Cons: Tied to Claude Code runtime

### Option B: Linear TypeScript SDK

```typescript
import { LinearClient } from "@linear/sdk";

const linear = new LinearClient({ apiKey: process.env.LINEAR_API_KEY });

await linear.updateIssue(issueId, { stateId: "in-progress-state-id" });
await linear.createComment({ issueId, body: "Starting work..." });
```

Pros: Works anywhere, scriptable
Cons: Needs API key management

### Option C: Hybrid

- Worker uses MCP tools (natural)
- Hooks use SDK (reliable, scriptable)

---

## Part 9: Implementation Phases

### Phase 1: Manual Workflow (Now)

1. Human creates issues with proper structure
2. Human moves to Todo when ready
3. Tell Claude "work on ALP-75"
4. Claude uses Linear MCP to update status/comments
5. Claude creates branch, works, creates PR
6. Human reviews, merges

**Test with:** 3-5 mdcontext backlog issues

### Phase 2: Worker Automation (Next)

1. Nancy queries Linear for highest priority Todo
2. Nancy auto-claims and works
3. Human only does review

### Phase 3: Multi-Worker (Later)

1. Multiple workers query independently
2. Linear blocking prevents conflicts
3. Workers skip blocked issues

---

## Quick Reference

### Linear MCP Tools

| Tool             | Use                           |
| ---------------- | ----------------------------- |
| `list_issues`    | Query Todo issues by priority |
| `get_issue`      | Get full description          |
| `update_issue`   | Change state                  |
| `create_comment` | Post progress                 |
| `list_comments`  | Get previous context          |

### Git Flow

```bash
# Start
git checkout -b ALP-75-description

# Work
git commit -m "feat(ALP-75): description"

# Complete
git fetch origin main
git rebase origin/main
git push -u origin ALP-75-description
gh pr create --fill-verbose
```

### Session Flow

```
Issue: Todo
  ↓ Worker picks up, updates Linear
Issue: In Progress (Session: iter1)
  ↓ Token limit / blocker
Issue: In Progress (paused)
  ↓ Resume or human input
Issue: In Progress (Session: iter2)
  ↓ PR created (GitHub → Linear auto-update)
Issue: In Review
  ↓ Human merges (GitHub → Linear auto-update)
Issue: Done
```

---

## Sources

- [Linear GitHub Integration](https://linear.app/docs/github-integration)
- [Linear MCP Server](https://linear.app/docs/mcp)
- [Linear TypeScript SDK](https://github.com/linear/linear)
