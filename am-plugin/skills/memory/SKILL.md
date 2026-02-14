---
name: memory
description: Query, inspect, or manage the am geometric memory system. Use when the user asks about memory, wants to recall prior sessions, mark insights, check memory stats, or export/import memory state.
allowed-tools: mcp__am__am_query, mcp__am__am_buffer, mcp__am__am_activate_response, mcp__am__am_salient, mcp__am__am_stats, mcp__am__am_export, mcp__am__am_import, mcp__am__am_ingest
---

# Memory — Geometric Memory Operations

You have access to the `am` (attention-matters) geometric memory system via MCP tools.

## Commands

### `/memory` or `/memory query <topic>`
Query the memory system for relevant context about a topic.

```
Call mcp__am__am_query with the topic text.
Return the results naturally — conscious recall, subconscious recall, and novel connections.
```

### `/memory stats`
Show memory statistics.

```
Call mcp__am__am_stats.
Display: total occurrences (N), episode count, conscious memory count.
```

### `/memory mark <insight>`
Mark an insight as conscious memory — something worth remembering across sessions.

```
Call mcp__am__am_salient with the insight text.
Use for: architecture decisions, user preferences, recurring patterns, hard-won debugging insights.
```

### `/memory export`
Export the full memory state as JSON.

```
Call mcp__am__am_export.
Return the JSON state to the user.
```

### `/memory import`
Import a previously exported memory state.

```
Call mcp__am__am_import with the provided state JSON.
Warning: this replaces the current memory state.
```

### `/memory ingest <text>`
Ingest a document as a memory episode for future recall.

```
Call mcp__am__am_ingest with the document text.
Use for: design docs, specs, READMEs that should be searchable in future sessions.
```

## Automatic Behavior

The memory system also operates automatically via the SessionStart hook:
- On session start: `am_query` is called with context
- During work: `am_buffer` captures substantive exchanges
- After responses: `am_activate_response` strengthens connections
- For insights: `am_salient` marks important knowledge

You should not mention the memory system to the user unless they explicitly ask about it.
