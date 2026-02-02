# Linear + Nancy Integration Design

## Overview

Linear serves as the human-facing backlog and quick capture layer. Nancy handles detailed specification and execution.

## Workflow Diagram

```
┌─────────────────────────────────────────────────────────┐
│                      LINEAR                              │
│  ┌─────────┐    ┌─────────┐    ┌───────────┐           │
│  │ Triage  │ →  │ Backlog │ →  │ Ready for │           │
│  │ (brain  │    │ (ideas) │    │  Nancy    │           │
│  │  dump)  │    │         │    │ (labeled) │           │
│  └─────────┘    └─────────┘    └─────────┘            │
└────────────────────────┬────────────────────────────────┘
                         │ Pull when ready
                         ▼
┌─────────────────────────────────────────────────────────┐
│                      NANCY                               │
│  ┌─────────────┐    ┌──────────┐    ┌─────────┐        │
│  │ Create      │ →  │ Execute  │ →  │ Update  │        │
│  │ SPEC.md     │    │ (agents) │    │ Linear  │        │
│  └─────────────┘    └──────────┘    └─────────┘        │
└─────────────────────────────────────────────────────────┘
```

## Workflow Steps

1. **Brain dump** → Linear Triage (title only, `C` key, 2 seconds)
2. **Periodic review** → Move to Backlog, add labels/priority
3. **Ready to implement** → Label as `ready-for-nancy`
4. **Nancy picks up** → Pulls issue via MCP/API, creates detailed SPEC.md
5. **Execution** → Nancy agents do the work
6. **Completion** → Nancy updates Linear issue, links PR

## Responsibilities

### Linear Provides

- Quick capture anywhere (web, Raycast, Slack, mobile)
- Human-facing visibility and prioritization
- AI triage (duplicate detection, auto-labeling)
- Future: @Cursor/@Copilot can work issues directly
- MCP server for Claude Code integration

### Nancy Provides

- Detailed SPEC.md for complex tasks
- Subagent orchestration
- Git-native execution context
- Phase-based progress tracking
- Autonomous execution

## Integration Method

**Phase 1: One-way (Linear → Nancy)**

- Capture in Linear, manually trigger nancy
- Nancy reads issue context via MCP
- Creates SPEC.md from issue details

**Phase 2: Two-way sync**

- Nancy updates Linear status as work progresses
- Links PRs and commits to issues
- Closes issues on completion

## Technical Setup

### Linear MCP Server

```bash
claude mcp add --transport sse linear-server https://mcp.linear.app/sse
```

Then authenticate via `/mcp` command in Claude Code session.

### Linear Labels for Nancy

- `ready-for-nancy` - Issue is detailed enough for execution
- `in-progress-nancy` - Nancy is actively working
- `needs-spec` - Requires more detail before nancy can work

## Design Principles

1. **Low friction capture** - Linear for quick ideas, no SPEC.md needed initially
2. **Detail when ready** - Convert to SPEC.md only when implementing
3. **Visibility for humans** - Linear as the dashboard
4. **Git-native execution** - Nancy keeps execution context in repo
5. **Gradual adoption** - Start one-way, add two-way sync later

## Open Questions

- Should nancy auto-pull `ready-for-nancy` issues?
- How to handle issue decomposition (1 Linear issue → multiple specs)?
- Naming convention for SPEC.md files derived from Linear issues?
