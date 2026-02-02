---
id: workflow.linear
description: Linear integration workflow
priority: 70
section: workflow
version: "1.0"
tags: ["workflow", "linear", "task-management"]
---

# Linear Integration Workflow

## Issue Management

Use Linear MCP tools to manage work:

- `mcp__linear-server__list_issues` - Find existing issues
- `mcp__linear-server__get_issue` - Get full issue details
- `mcp__linear-server__create_issue` - Create new issues
- `mcp__linear-server__update_issue` - Update status, description, assignee
- `mcp__linear-server__create_comment` - Add context or discussion

## Creating Issues

When creating Linear issues, use this structure:

```markdown
## Description

[Detailed explanation of what needs to be built/changed and why]

## Acceptance Criteria

- [ ] Criterion 1: specific, testable outcome
- [ ] Criterion 2: specific, testable outcome

## Context

[Links to related issues, docs, or code]

## Notes

[Implementation hints, constraints, gotchas]
```

## Work Structure

**Simple tasks**: Single issue with clear acceptance criteria

**Complex tasks**:

- Parent issue in Backlog (container, overview)
- Sub-issues for discrete pieces of work
- Parent stays in Backlog, only sub-issues move to Todo

## Ready for Worker

When issue is fully specified:

1. Set priority (Urgent/High/Medium/Low)
2. Assign to worker
3. Move to **Todo** state
