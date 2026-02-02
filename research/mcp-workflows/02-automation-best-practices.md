# Linear Automation Best Practices Research

## Overview

Research into Linear's native automation features and community best practices for workflow management.

## Linear Native Automation

### Workflow States

Linear's opinionated workflow:

```
Issues → Cycles → Projects → Initiatives
```

Standard issue states:

- **Backlog**: Ideas, unrefined work
- **Todo**: Ready to work, prioritized
- **In Progress**: Active development
- **In Review**: Awaiting approval/QA
- **Done**: Completed
- **Canceled**: Won't do

### Auto-Assign & Triage

- Issues can auto-assign based on labels, projects, or cycles
- Triage workflow for new issues before entering backlog
- SLA escalation for priority issues

### Cycles (Sprints)

- Time-boxed work periods
- Auto-move incomplete issues to next cycle
- Velocity tracking and forecasting

## Community Best Practices

### Priority-Based Task Picking

Recommended strategy for AI agents:

1. Query issues in "Todo" state, ordered by priority
2. Pick highest priority unassigned issue (or assigned to agent)
3. Consider blockers/dependencies before starting
4. Respect WIP limits if configured

### Workflow State Patterns

**Pattern A: Simple Linear Flow**

```
Backlog → Todo → In Progress → Done
```

Best for small teams, straightforward work.

**Pattern B: With Review Gate**

```
Backlog → Todo → In Progress → In Review → Done
                                   ↓
                              Needs Work → In Progress
```

Best for quality gates, code review requirements.

**Pattern C: With Triage**

```
Triage → Backlog → Todo → In Progress → In Review → Done
   ↓
 Canceled
```

Best for teams receiving external requests.

### API Integration Patterns

**Webhooks** (push):

- Issue state changes
- Comment additions
- Assignment changes
- Good for: Real-time notifications, audit logging

**API Polling** (pull):

- Query for ready work
- Check completion status
- Good for: Worker task picking, dashboard updates

**MCP** (interactive):

- AI agent operations
- Natural language queries
- Good for: Claude Code integration, conversational interfaces

## Error Handling & Recovery

### Stuck Issue Detection

Monitor for issues stuck "In Progress" too long:

- Alert after configurable threshold (e.g., 24h)
- Auto-add "stale" label
- Notify assignee/team

### Rollback Pattern

If work fails:

1. Add comment explaining failure
2. Move back to "Todo" (not Backlog)
3. Preserve context for next attempt
4. Optionally add "needs-investigation" label

### Partial Completion

For interrupted work:

1. Comment with progress summary
2. Keep "In Progress" if resumable
3. Or move to "Todo" with continuation context
4. Never lose work silently

## Recommendations for Nancy Integration

### Status Mapping

| Nancy State    | Linear State |
| -------------- | ------------ |
| SPEC created   | Backlog      |
| Ready to start | Todo         |
| Worker running | In Progress  |
| COMPLETE file  | In Review    |
| Human approved | Done         |

### Webhook Integration Points

1. **Issue moved to Todo**: Trigger worker check for available work
2. **Comment added**: Parse for directives (e.g., "@nancy pause")
3. **Priority changed**: Re-evaluate work queue
4. **Issue assigned**: Start work if assigned to Nancy agent

### API Operations

On worker start:

```
1. list_issues(state="Todo", orderBy="priority")
2. update_issue(id, state="In Progress")
3. create_comment(id, "🤖 Starting work - Session: {session_id}")
```

On worker complete:

```
1. create_comment(id, "✅ Work complete - {summary}")
2. update_issue(id, state="In Review")
```

## Sources

- [Linear Review 2025](https://skywork.ai/blog/linear-review-2025-ai-dashboards-enterprise/)
- [Agentic AI Workflow Patterns](https://skywork.ai/blog/agentic-ai-examples-workflow-patterns-2025/)
- [AI Automation Agents Guide](https://latenode.com/blog/ai-automation-agents-in-2025-complete-guide-to-workflow-intelligence-9-implementation-strategies)
