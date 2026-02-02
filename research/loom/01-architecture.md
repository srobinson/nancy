# Loom Architecture Research

## Executive Summary

**Loom** is a sophisticated AI-powered coding agent platform with:

- **95 crates** organized into coherent domains
- **672 Rust files** implementing 2 main entry points (CLI + Server)
- Production-grade architecture with security, extensibility, and modularity as core principles

## Key Architectural Insights

### 1. Layered Modular Design

```
Applications (loom-cli, loom-server)
  |
Domain Services (18 crates: auth, analytics, crons, etc.)
  |
Infrastructure (13 crates: db, jobs, llm-service, audit)
  |
Core Abstractions (4 crates: common-core, config, secret, version)
```

### 2. Plugin Architecture for LLM Providers

- Each provider is a separate crate (Anthropic, OpenAI, Vertex, ZAI)
- New providers added via trait implementation
- Server-side proxy pattern keeps API keys secure

### 3. Repository Pattern for Data Access

- Every domain (users, orgs, threads, sessions) has:
  - **Trait**: `{Domain}Store` interface
  - **Struct**: `{Domain}Repository` implementation
- Enables testing, mocking, and multiple implementations

### 4. Event-Driven Agent State Machine

- Agent returns `AgentAction` enum, not side effects
- Allows testing without LLM calls
- Supports post-tool hooks (auto-commit, notifications)

### 5. ABAC Authorization Over RBAC

- Fine-grained control based on attributes (who, what, why)
- Avoids role explosion as permissions grow
- Context-aware (ownership, visibility matter)

## Critical Crates to Understand

| Crate                     | Role                                                |
| ------------------------- | --------------------------------------------------- |
| `loom-common-core`        | Base traits: `LlmClient`, `Agent`, `ToolDefinition` |
| `loom-server`             | HTTP server + job scheduler                         |
| `loom-cli`                | REPL interface with MCP support                     |
| `loom-server-db`          | Repository pattern implementation                   |
| `loom-server-auth`        | Authentication + ABAC                               |
| `loom-server-llm-service` | LLM provider abstraction                            |
| `loom-server-api`         | REST routes                                         |
| `loom-server-audit`       | Audit event pipeline                                |

## Recommendations for Nancy

1. **Adopt Workspace Architecture** - Organize Nancy's shell scripts as Rust crates by domain
2. **Trait-Based Extensibility** - Use traits for skills, task handlers, commands
3. **Repository Pattern** - Abstract state management (sessions, tokens)
4. **Event-Driven Design** - Agent returns actions, not side effects
5. **Structured Logging** - Use tracing with redaction for sensitive data
6. **Background Job Scheduling** - Implement token refresh, session cleanup, etc.
7. **API Documentation** - Use utoipa for automatic OpenAPI generation

## Document Contents

This architecture research document covers:

1. **Overview** - What Loom is and core principles
2. **Crate Map** - All 95 crates organized by domain (11 categories)
3. **Dependency Graph** - Layered architecture and integration points
4. **Core Abstractions** - Key traits and types (LlmClient, Agent, Repository pattern, ABAC)
5. **Entry Points** - How server and CLI start up
6. **Observations** - Architectural patterns (plugin, trait-based, repository, event-driven)
7. **Clever Decisions** - Server-side proxy, ABAC, streaming, redaction engine, build optimization
8. **Nancy Recommendations** - 8 architectural patterns Nancy could adopt + 3 Nancy-specific opportunities
9. **Statistics** - Codebase metrics and build optimizations
10. **Summary** - Key takeaways and integration opportunities
