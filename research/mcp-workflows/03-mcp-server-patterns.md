# MCP Server Patterns Research

## Overview

Research into Model Context Protocol implementations, session handling, and state modification patterns.

## MCP Ecosystem Overview

### What is MCP?

Model Context Protocol (MCP) is an open standard from Anthropic enabling secure, two-way connections between data sources and AI tools.

Key components:
- **MCP Servers**: Expose tools, resources, prompts
- **MCP Clients**: Claude Desktop, Claude Code, Cursor, etc.
- **Transport**: stdio, HTTP, SSE

### Linear MCP Implementation

Official server at `https://mcp.linear.app/mcp`:
- **Tools**: Issue CRUD, project management, comments
- **Auth**: OAuth 2.1 or direct Bearer token
- **Transport**: Streamable HTTP (recommended) or SSE

## Session & Context Patterns

### Session ID Propagation

Pattern for tracking work across iterations:
```
Session ID: nancy-{task}-iter{n}

Passed via:
1. PROMPT template variable: {{SESSION_ID}}
2. Environment variable: NANCY_SESSION_ID
3. Linear comment metadata
```

Benefits:
- Traceable execution history
- Resume capability
- Debugging/auditing

### Context Preservation

**Pattern: Comment-Based Context**
```markdown
## Session: nancy-feature-x-iter3

### Context from Previous Iteration:
- Completed: API endpoint implementation
- Blocked: Database migration needs review
- Next: Write integration tests

### Current Progress:
- [ ] Write tests
- [ ] Update documentation
```

**Pattern: Linked Sessions**
```
Parent Session: nancy-epic-iter1
  └── Child: nancy-subtask-a-iter1
  └── Child: nancy-subtask-b-iter2
```

## State Modification Best Practices

### Idempotency

MCP tools that modify state should be idempotent where possible:
- `update_issue` with same state = no-op
- Creating duplicate comments = check for existing
- Use unique identifiers (session ID) for deduplication

### Atomic Operations

Group related changes:
```
# Bad: Multiple separate calls
update_issue(state="In Progress")
create_comment("Starting work")
update_issue(assignee="agent")

# Better: Minimize race conditions
update_issue(state="In Progress", assignee="agent")
create_comment("Starting work - Session: {session_id}")
```

### Error Recovery

```python
try:
    update_issue(id, state="In Progress")
    do_work()
    update_issue(id, state="In Review")
except WorkError as e:
    create_comment(id, f"❌ Failed: {e}")
    # Don't change state - leave In Progress for retry
except Exception as e:
    create_comment(id, f"⚠️ Unexpected error: {e}")
    update_issue(id, state="Todo")  # Reset for manual review
```

## Orchestration Patterns

### mcp-agent Patterns

From [lastmile-ai/mcp-agent](https://github.com/lastmile-ai/mcp-agent):

**Orchestrator-Workers**:
```
Orchestrator (planning)
    ├── Worker A (MCP Server 1)
    ├── Worker B (MCP Server 2)
    └── Worker C (MCP Server 3)
```

**Temporal Integration**:
- Durable execution across failures
- Pause/resume workflows
- CLI: `mcp-agent cloud workflows resume --payload '{"content": "approve"}'`

### Server-of-Servers Pattern

Aggregate multiple MCP servers into unified interface:
```python
aggregator = MCPAggregator([
    linear_server,
    github_server,
    filesystem_server
])

# Single interface to all tools
result = await aggregator.call_tool("linear_create_issue", {...})
```

## Integration Architecture for Nancy

### Proposed Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     Nancy Framework                      │
├─────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐ │
│  │ Orchestrator │  │   Worker    │  │ Linear Bridge   │ │
│  │  (human)     │──│  (claude)   │──│ (MCP client)    │ │
│  └─────────────┘  └─────────────┘  └────────┬────────┘ │
└────────────────────────────────────────────────┼────────┘
                                                 │
                                    ┌────────────┴────────────┐
                                    │   Linear MCP Server     │
                                    │  (mcp.linear.app/mcp)   │
                                    └─────────────────────────┘
```

### Integration Points

1. **Worker Start Hook**
   - Query Linear for highest priority Todo
   - Update issue state to In Progress
   - Post session start comment

2. **Progress Updates**
   - Periodic comments with progress
   - Skill: `/send-message` posts to Linear

3. **Completion Hook**
   - Post summary comment
   - Update issue state to In Review
   - Trigger review workflow

4. **Session Context**
   - Session ID in all Linear comments
   - Link to session transcript location
   - Enable continuation across iterations

### Configuration

```yaml
# .nancy/config.yaml
linear:
  enabled: true
  project: "Nancy"
  team: "Alphabio"

  workflow:
    pick_from: "Todo"
    working_state: "In Progress"
    complete_state: "In Review"

  comments:
    on_start: true
    on_progress: true  # Periodic updates
    on_complete: true
    include_session_id: true
```

## Sources

- [Anthropic MCP Announcement](https://www.anthropic.com/news/model-context-protocol)
- [Linear MCP Docs](https://linear.app/docs/mcp)
- [lastmile-ai/mcp-agent](https://github.com/lastmile-ai/mcp-agent)
- [mcp-agent Workflows](https://github.com/lastmile-ai/mcp-agent)
