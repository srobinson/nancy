# Linear AI Agent Workflows Research

## Executive Summary

Linear has evolved from a project management tool into a first-class AI agent collaboration platform. With the launch of "Linear for Agents" (May 2025) and the "Agent Interaction SDK" (July 2025), Linear now provides comprehensive infrastructure for AI agents to work alongside human teammates. This document captures the key capabilities, patterns, and recommendations for Nancy integration.

---

## 1. Linear's Official AI/Agent Features

### Linear for Agents (Launched May 2025)

**Core Concept**: Agents are first-class users in Linear workspaces - they can be assigned issues, added to teams/projects, and @mentioned in comments, just like human team members.

**Key Characteristics**:
- Agents have full user profiles, clearly identified as "app users"
- Do NOT count as billable users
- Cannot sign in independently or access admin features
- Work is delegated, not assigned (human remains responsible)

**Official Launch Partners**:
- **Devin**: Scopes issues, drafts PRs
- **ChatPRD**: Writes requirements, manages issues, gives feedback
- **Codegen**: Builds features, debugs, answers codebase questions
- **Cursor**: Cloud agents for issue-to-PR automation
- **GitHub Copilot**: Asynchronous autonomous background agent
- **Factory AI**: Remote workspaces for coding agents
- **Sentry**: Error resolution automation
- **Intercom/Zendesk/Gong**: Customer feedback to issues

### Agent Interaction SDK (July 2025)

**Status**: Developer Preview (APIs may change before GA)

**Core Abstraction**: The **Agent Session** - tracks the lifecycle of an agent task.

**Session States**:
| State | Description |
|-------|-------------|
| `pending` | Session created, agent not yet responding |
| `active` | Agent is working |
| `awaitingInput` | Agent needs human input |
| `error` | Agent encountered a failure |
| `complete` | Work finished |

**Key Feature**: Session state is managed automatically by Linear based on emitted activities - no manual state management required.

### Agent Activities

Agents communicate through five semantic activity types:

1. **thought**: Internal reasoning (can be ephemeral)
2. **elicitation**: Request clarification or confirmation from user
3. **action**: Tool invocations with optional results (can be ephemeral)
4. **response**: Completion or final results
5. **error**: Failure reporting

**Ephemeral Activities**: Marked with `ephemeral: true`, displayed temporarily and replaced by next activity. Only `thought` and `action` types can be ephemeral.

### Agent Plans

Session-level checklists that evolve during execution:
- Steps have `content` (string) and `status` (pending/inProgress/completed/canceled)
- Entire plan must be replaced on update (no partial updates)
- Useful for multi-step tasks to keep users informed

### Webhook Events

| Event | Trigger | Expected Response |
|-------|---------|-------------------|
| `created` | Agent mentioned or delegated | Activity within 10 seconds |
| `prompted` | New user message in session | Process from `agentActivity.body` |

**Critical**: Webhook responses must return within 5 seconds. Sessions marked "unresponsive" if no activity within 10 seconds.

### OAuth & Scopes

Authentication uses OAuth2 with `actor=app` parameter for app installation:

| Scope | Purpose |
|-------|---------|
| `app:assignable` | Can be assigned/delegated issues |
| `app:mentionable` | Can be @mentioned in comments/docs |
| `customer:read/write` | Access customer data |
| `initiative:read/write` | Access initiatives |

---

## 2. How Teams Use Linear with AI Coding Assistants

### Cursor Integration

**Workflow**:
1. Connect Linear workspace via Cursor dashboard
2. Assign issue to `@Cursor` or mention in comment
3. Cursor spins up cloud agent with full issue context
4. Agent works, creates PR, updates Linear
5. Updates stream back to Linear activity timeline

**Configuration Options** (via issue comments or labels):
```
@cursor implement feature [model=claude-3.5-sonnet] [branch=feature-branch]
```
- `[model=X]` - Specify AI model
- `[branch=X]` - Target branch
- `repo` label group - Specify target repository

**Auto-Triage**: Rules can automatically assign issues to Cursor based on properties (team, status, label).

### GitHub Copilot Coding Agent

**Workflow**:
1. Install from GitHub Marketplace (requires org owner + Linear admin)
2. Assign issue to GitHub Copilot
3. Agent runs in ephemeral GitHub Actions environment
4. Creates draft PR, runs tests/linters
5. Streams updates to Linear, requests review when ready

**Best For**: Lightweight tasks - quick bug fixes, small refactors, UI polish.

**Limitation**: Repository must be specified, can be confusing in multi-repo setups.

### Cyrus (Claude Code Powered)

**Architecture**: Runs on user-controlled infrastructure (local or droplet), not cloud.

**Label-Based Routing**:
- `Bug` label: Triggers debugger mode
- `Feature` label: Triggers builder mode
- `Performance` label: Triggers optimization mode

**Results** (reported): 38 issues closed in 3 weeks, 87% first-attempt success rate.

**Use Cases**:
- Bug fixes with clear error messages
- API endpoints
- Database migrations
- Test improvements
- Performance optimizations

### Claude Code + Linear MCP

**MCP Server Endpoints**:
- HTTP (Streamable): `https://mcp.linear.app/mcp` (recommended)
- SSE: `https://mcp.linear.app/sse`

**Setup**:
```bash
claude mcp add --transport sse linear-server https://mcp.linear.app/sse
```

**Capabilities**:
- Create/update issues with natural language
- Manage projects and comments
- Query workspace data
- Update statuses programmatically

**Note**: Reported 34% timeout rate with SSE due to idle timeouts. HTTP transport is more reliable.

---

## 3. Status Transition Automation Patterns

### Default Linear Workflow

```
Backlog -> Todo -> In Progress -> Done -> Canceled
```

### Agent-Triggered Transitions

**On Delegation** (automatic):
- Human remains primary assignee
- Agent added as contributor/delegate
- Issue typically moves to "In Progress"

**Pattern: Sentry Agent Example**:
1. Navigate to issue, select "Assign" -> "Sentry"
2. Task automatically moves to "In Progress"
3. Agent session created
4. Agent checks for/runs Issue Fix
5. On completion, updates issue with results

### Triage Rules for Auto-Assignment

```
Settings -> Teams -> Triage
1. Enable triage
2. Create rule: Delegate -> [Agent Name]
3. Set conditions (label, priority, etc.)
```

New issues matching criteria are automatically assigned to agents.

### Recommended Transition Flow for Nancy

```
┌──────────────────────────────────────────────────────────────┐
│  Status Transitions                                          │
├──────────────────────────────────────────────────────────────┤
│  Backlog  -> Todo       (Human: spec ready)                 │
│  Todo     -> In Progress (Agent: picked up)                 │
│  In Progress -> In Review (Agent: work complete)            │
│  In Review  -> Done      (Human: approved)                  │
│  In Review  -> Todo      (Human: changes needed)            │
└──────────────────────────────────────────────────────────────┘
```

---

## 4. Comment-Based Communication Patterns

### Agent-to-Human Communication

**Progress Updates**:
```markdown
## Progress Update - Session: nancy-ALP-75-iter3

### Completed
- [x] Analyzed existing cost calculation logic
- [x] Created estimation service module

### In Progress
- [ ] Implementing UI components

### Next
- [ ] Integration tests
```

**Completion Announcement**:
```markdown
## Completed - Session: nancy-ALP-75-iter3

### Summary
Implemented cost estimation feature with 3 new endpoints and React components.

### Changes
- `src/services/cost-estimator.ts` (new)
- `src/components/CostBreakdown.tsx` (new)
- `src/api/routes/estimates.ts` (modified)

### PR
- [#142: Add cost estimation feature](github.com/...)
```

**Blockers/Questions**:
```markdown
## Needs Input - Session: nancy-ALP-75-iter3

### Question
The spec mentions "industry standard pricing" but doesn't define which industry.
Should I use:
A) SaaS pricing models (per-seat, usage-based)
B) Enterprise software pricing (license-based)
C) Something else?

Please reply to unblock.
```

### Human-to-Agent Communication

**Via @mentions**:
```
@nancy Please focus on the API endpoints first, UI can come later.
```

**Via Issue Description Updates**: Append to description with clear markers:
```markdown
---
## Additional Context (added 2025-01-22)
Use the pricing data from our partner API at /api/pricing/v2
```

### Slack Integration Pattern

Linear's Slack agent enables:
- `@Linear` in Slack threads creates issues
- Bidirectional comment sync
- Workflow Builder automation
- Keep non-Linear users informed via Slack

---

## 5. Session/Context Tracking Across Iterations

### Linear's Approach

**`promptContext` Field**: Automatically constructed formatted string containing:
- Issue details (title, description, labels, priority)
- Recent comments
- Agent guidance (workspace + team level)
- Related context

**Session Continuity**: When `prompted` event fires (new user message in existing session), agent receives full context in `agentActivity.body`.

### External URL Pattern

Agents can set `externalUrls` on sessions to:
- Link to external dashboards
- Point to GitHub PRs
- Reference Claude Code sessions
- Prevent sessions from being marked unresponsive

### Repository Suggestions API

`issueRepositorySuggestions` API helps agents:
- Match relevant repositories with confidence scores
- Use LLM-based ranking
- Leverage issue context for better matching

### Recommended Pattern for Nancy

**Session ID Format**:
```
nancy-{issue-id}-iter{iteration}
```

**Context Storage**:
```
Linear Issue Comments:
├── Start comment (session ID, configuration)
├── Progress updates (checkpoints)
├── Completion summary (results, links)
└── Human feedback (review notes)

Issue Attachments:
├── Links to PRs/commits
├── Links to external session dashboards
└── Links to related documentation
```

**Cross-Iteration Context**:
1. On start: Fetch all previous comments on issue
2. Parse previous session summaries
3. Include relevant context in worker prompt
4. On complete: Write comprehensive summary for next iteration

---

## 6. Recommendations for Nancy Integration

### Phase 1: MCP Integration (Immediate)

**Use Linear's Official MCP Server**:
```bash
claude mcp add --transport sse linear-server https://mcp.linear.app/sse
```

**Available Operations**:
- `list_issues` - Query issues with filters
- `get_issue` - Fetch issue details
- `create_issue` - Create new issues
- `update_issue` - Update status, assignee, etc.
- `create_comment` - Post progress/completion comments
- `list_comments` - Fetch conversation history

### Phase 2: Worker Integration

**Prompt Template Additions**:
```markdown
# Nancy Worker - {{LINEAR_ISSUE_ID}}

**Session:** `{{SESSION_ID}}`
**Linear Issue:** [{{LINEAR_ISSUE_ID}}]({{LINEAR_ISSUE_URL}})

## Context from Linear
{{ISSUE_DESCRIPTION}}

## Previous Sessions
{{PREVIOUS_SESSION_SUMMARIES}}

## Agent Guidance
{{WORKSPACE_GUIDANCE}}
{{TEAM_GUIDANCE}}
```

**Lifecycle Hooks**:
```bash
# on_worker_start
linear::update_issue "$issue_id" --state "In Progress"
linear::create_comment "$issue_id" "Starting - Session: $session_id"

# on_progress (periodic or milestone)
linear::create_comment "$issue_id" "Progress: $summary"

# on_worker_complete
linear::create_comment "$issue_id" "Complete: $summary [PR: $pr_link]"
linear::update_issue "$issue_id" --state "In Review"
```

### Phase 3: Full Agent Integration (Future)

**Consider Building a Linear Agent** if:
- You want `@nancy` mentions to trigger workers
- You need automatic session management
- You want UI integration in Linear

**Agent SDK Requirements**:
- OAuth app with `actor=app`
- Webhook endpoint for `AgentSessionEvent`
- 10-second response SLA for `created` events
- Activity emission for status updates

### Configuration Recommendations

```yaml
# .nancy/config.yaml
linear:
  enabled: true
  server: "https://mcp.linear.app/mcp"  # HTTP preferred over SSE

  workspace:
    team: "Engineering"
    project: "Product Development"

  task_source:
    state: "Todo"
    order_by: "priority"  # or "createdAt"
    labels: []  # Optional filter

  states:
    picked: "In Progress"
    complete: "In Review"
    approved: "Done"
    rejected: "Todo"

  comments:
    on_start: true
    on_progress: "milestone"  # or "interval:5m" or "never"
    on_complete: true
    include_session_id: true
    include_pr_link: true

  context:
    fetch_previous_sessions: true
    include_workspace_guidance: true
    include_team_guidance: true
```

---

## 7. Key Learnings from Existing Integrations

### What Works Well

1. **Delegation Model**: Human remains responsible, agent assists
2. **Automatic State Tracking**: Linear handles session state based on activities
3. **Context Injection**: `promptContext` provides rich, formatted context
4. **Label-Based Routing**: Simple way to configure agent behavior
5. **External URLs**: Link sessions to external dashboards/PRs

### Common Pitfalls

1. **SSE Timeouts**: Use HTTP transport when possible (34% timeout rate reported with SSE)
2. **Repository Confusion**: Multi-repo setups need explicit configuration
3. **Response SLA**: Must respond within 10 seconds or marked unresponsive
4. **Context Overload**: Be selective about what context to include

### Best Practices from Successful Integrations

1. **Clear Session Identification**: Always include session ID in comments
2. **Structured Progress Updates**: Use consistent markdown format
3. **Completion Summaries**: Include what changed, why, and links
4. **Error Handling**: Post clear error messages with actionable next steps
5. **Human Handoff**: Clear mechanism for escalation/questions

---

## Sources

### Official Linear Documentation
- [Linear for Agents](https://linear.app/agents)
- [AI Agents in Linear](https://linear.app/docs/agents-in-linear)
- [Getting Started - Developers](https://linear.app/developers/agents)
- [Agent Interaction - Developers](https://linear.app/developers/agent-interaction)
- [MCP Server Documentation](https://linear.app/docs/mcp)

### Linear Changelog
- [Linear for Agents Launch (May 2025)](https://linear.app/changelog/2025-05-20-linear-for-agents)
- [Agent Interaction SDK (July 2025)](https://linear.app/changelog/2025-07-30-agent-interaction-guidelines-and-sdk)
- [GitHub Copilot Agent (October 2025)](https://linear.app/changelog/2025-10-28-github-copilot-agent)
- [MCP Server Launch (May 2025)](https://linear.app/changelog/2025-05-01-mcp)

### Integration Guides
- [Cursor Integration](https://linear.app/integrations/cursor)
- [GitHub Copilot Integration](https://linear.app/integrations/github-copilot)
- [Claude Integration](https://linear.app/integrations/claude)
- [Cursor Blog: Bringing Agent to Linear](https://cursor.com/blog/linear)
- [GitHub Docs: Copilot Coding Agent with Linear](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/coding-agent/integrate-coding-agent-with-linear)

### Third-Party Resources
- [Cyrus: Linear + Claude Code](https://www.atcyrus.com/stories/linear-claude-code-integration-guide)
- [Composio: Linear MCP Setup](https://composio.dev/blog/how-to-set-up-linear-mcp-in-claude-code-to-automate-issue-tracking)
- [Anthropic: Claude Code Best Practices](https://www.anthropic.com/engineering/claude-code-best-practices)

### Technical References
- [Linear GraphQL API](https://linear.app/developers/graphql)
- [Linear TypeScript SDK (GitHub)](https://github.com/linear/linear)
- [Weather Bot Demo Agent (GitHub)](https://github.com/linear/weather-bot)
