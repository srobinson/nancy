# Linear + AI Agent Workflows Research

## Overview

Research into how teams integrate Linear with AI coding agents (Claude Code, Cursor, etc.) and successful patterns for automated development workflows.

## Key Findings

### Official Linear MCP Server

Linear launched their [official MCP server](https://linear.app/docs/mcp) providing native integration with Claude and other MCP clients.

**Capabilities:**
- Find, create, update issues, projects, comments
- OAuth 2.1 with dynamic client registration
- Supports direct Bearer token auth for automation scenarios
- Two transport options: Streamable HTTP (`https://mcp.linear.app/mcp`) and SSE (`https://mcp.linear.app/sse`)

### Linear for Agents (May 2025)

Linear formalized their agent system with the "Linear for Agents" release:
- Agent Interaction Guidelines & SDK (July 2025)
- Controlled automation for tagging, nudging stale PRs, escalating SLAs
- Human remains responsible, agent is auditable
- Follows "Issues → cycles → projects → initiatives" workflow

### Community MCP Implementations

1. **[jerhadf/linear-mcp-server](https://github.com/jerhadf/linear-mcp-server)** - Now recommends official Linear MCP
2. **[tacticlaunch/mcp-linear](https://github.com/tacticlaunch/mcp-linear)** - Natural language interface for Linear operations

## Key Patterns Identified

### 1. State Machine Orchestration

Best practice is explicit state machines with:
- Defined states and transitions
- Retry/timeout handling
- Human-in-the-loop (HITL) pauses
- Observable/auditable execution

### 2. Plan-Do-Check-Act Loop

Agents in 2025 "autonomously plan multi-step workflows, execute each stage sequentially, review outcomes, and adjust as needed."

### 3. Comment-Based Progress Updates

Pattern: Agent posts status comments to Linear issues during execution:
```
🤖 Starting work on this issue
Session: nancy-task-iter3

Progress:
- [x] Analyzed codebase
- [x] Implemented feature
- [ ] Running tests
```

### 4. Status Transitions

Typical flow:
```
Backlog → Todo → In Progress → In Review → Done
         ↑                        │
         └────── (rejected) ──────┘
```

Worker picks highest priority from "Todo", moves to "In Progress", completes work, moves to "In Review".

## Orchestration Frameworks

### mcp-agent (lastmile-ai)

[mcp-agent](https://github.com/lastmile-ai/mcp-agent) provides:
- **Orchestrator-Workers pattern**: Central planning with distributed execution
- **Temporal backend**: Durable state, pause/resume, failure recovery
- **Server-of-servers**: Aggregate multiple MCP servers

### claude-flow

[claude-flow](https://github.com/ruvnet/claude-flow) offers:
- Multi-agent swarm orchestration
- Native Claude Code support via MCP
- Distributed execution patterns

## Recommendations for Nancy Integration

### Phase 1: Linear as Source of Truth
1. Worker picks highest priority issue from "Todo" state
2. Moves issue to "In Progress" on start
3. Posts session ID and progress comments
4. Moves to "In Review" on completion

### Phase 2: Bidirectional Sync
1. `nancy init` from Linear issue (pull description into SPEC.md)
2. Comments sync bidirectionally
3. Completion updates issue and closes

### Phase 3: Full Orchestration
1. Linear cycles drive sprint planning
2. Orchestrator assigns issues based on priority/dependencies
3. Review workflow triggers human approval via Linear
4. Metrics/analytics from Linear insights

## Sources

- [Linear MCP Server Docs](https://linear.app/docs/mcp)
- [Linear Claude Integration](https://linear.app/integrations/claude)
- [Composio: Linear MCP Setup Guide](https://composio.dev/blog/how-to-set-up-linear-mcp-in-claude-code-to-automate-issue-tracking)
- [jerhadf/linear-mcp-server](https://github.com/jerhadf/linear-mcp-server)
- [tacticlaunch/mcp-linear](https://github.com/tacticlaunch/mcp-linear)
- [lastmile-ai/mcp-agent](https://github.com/lastmile-ai/mcp-agent)
- [ruvnet/claude-flow](https://github.com/ruvnet/claude-flow)
