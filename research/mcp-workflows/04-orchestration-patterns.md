# Orchestration Patterns for Parallel AI Agent Development

## Overview

This document explores orchestration patterns for managing multiple AI coding agents working in parallel on the same codebase. As AI-assisted development evolves from single-agent workflows to multi-agent swarms, the challenge shifts from "how to prompt effectively" to "how to coordinate effectively."

> "Developers became orchestrators of AI agents - a role that demands the same technical judgment, critical thinking, and adaptability they've always had." - Zach Lloyd, Warp CEO

## Part 1: The Coordination Problem

### Why Parallel Agents?

**Performance gains are significant:**
- Single-agent workflow (outline -> draft -> fact-check -> polish): ~6:10 average
- Parallel workflow (draft + sources + examples, then merge): ~3:56 average (36% improvement)
- Teams report shipping quarterly roadmaps in 3-4 weeks with multi-agent systems
- 5-8x productivity gains when done correctly

**The fundamental challenge:**
Parallel development has two hard problems that prompt-chains don't solve:
1. **Safe concurrency** - Two agents writing to the same file is not "parallelism", it's a race condition
2. **Stop conditions** - How do you know the result is shippable, not just "it ran"?

### Core Conflicts in Multi-Agent Systems

| Conflict Type | Description | Impact |
|---------------|-------------|--------|
| **File collisions** | Multiple agents modify same file | Merge conflicts, lost work |
| **Port conflicts** | Parallel processes competing for ports | Startup failures |
| **State inconsistency** | Agents operate on stale views | Logic errors, regressions |
| **Resource contention** | Competing for memory, API limits | Throttling, crashes |
| **Semantic conflicts** | Incompatible assumptions about architecture | Integration failures |

---

## Part 2: Isolation Strategies

### 2.1 Git Worktrees - The Foundation

Git worktrees are the foundational technology for parallel AI agent development:

```bash
# Create isolated workspace for each agent
git worktree add ../feature-auth -b feature/auth
git worktree add ../feature-api -b feature/api
git worktree add ../feature-tests -b feature/tests
```

**Why worktrees work:**
- Complete filesystem isolation - agents can't clobber each other
- Shared Git history - all worktrees see same commits
- Space efficient - single `.git` directory shared across all
- Fast creation - seconds, not minutes like full clones
- Clean merges - standard Git merge/rebase operations

**Best practices:**
- Organized naming: `{project}-{feature}-{agent-id}`
- Limit active worktrees (3-5 for solo developer, scale with team)
- Regular cleanup: `git worktree prune`
- Explicit boundary instructions to agents: "Work only within this directory"

### 2.2 Task Decomposition Strategies

**File-Level Isolation:**
```
Task: Implement user authentication
├── Agent A: src/auth/login.ts (exclusive)
├── Agent B: src/auth/register.ts (exclusive)
├── Agent C: tests/auth/*.test.ts (exclusive)
└── SHARED: src/auth/types.ts (locked/read-only during parallel phase)
```

**Feature-Level Isolation:**
```
Epic: Payment System
├── Track A: Stripe Integration (payment-stripe branch)
├── Track B: PayPal Integration (payment-paypal branch)
├── Track C: Invoice Generation (payment-invoices branch)
└── Merge Point: Integration tests in main
```

**Risk-Based Decomposition:**
- High-risk changes: Single agent, extra review
- Medium-risk: File-level isolation with locks
- Low-risk (tests, docs): Parallel without locks

**Guidelines:**
- 3-5 agents usually beats 8-10 - beyond that, merge complexity eats the gains
- Start with 2 agents on well-isolated features
- Master the coordination workflow before scaling
- Budget time for integration (parallel execution is only half the battle)

### 2.3 Port and Resource Isolation

Critical for agents running dev servers or tests:

```yaml
# Port allocation per worktree
worktree-auth:
  dev_server: 3001
  test_runner: 9001

worktree-api:
  dev_server: 3002
  test_runner: 9002
```

Microsoft Aspire provides an isolation layer that automatically allocates unique ports for each worktree, solving the "all worktrees fight for same ports" problem.

---

## Part 3: Coordination Patterns

### 3.1 File Locking

**Hierarchical Lock Management (Swarm-IOSM approach):**

Treat files as shared memory regions. Agents are threads; files are memory.

```
Lock Hierarchy:
├── Exclusive Write Lock - One agent owns the file
├── Shared Read Lock - Multiple agents can read
└── Directory Lock - Lock entire subdirectory tree
```

**Lock acquisition protocol:**
1. Agent requests lock on target files
2. Coordinator checks for conflicts
3. If clear: Grant lock, record ownership
4. If conflict: Queue agent or assign alternate task
5. On completion: Release locks

**Implementation approaches:**
- Database-backed locks (SQLite, Redis)
- File-based locks (.lock files in worktree)
- In-memory coordinator tracking

### 3.2 Optimistic Concurrency

For lower-conflict scenarios, optimistic concurrency avoids lock overhead:

**How it works:**
1. **Begin:** Record timestamp/version when reading
2. **Modify:** Make changes locally (no locks held)
3. **Validate:** Before commit, verify no conflicting changes
4. **Commit/Rollback:** If validation passes, commit. Otherwise, retry.

**When to use:**
- Low conflict probability (agents in different parts of codebase)
- Cost of locks exceeds cost of occasional retries
- High read volume, low write volume

**When to avoid:**
- Hot files that multiple agents frequently modify
- Critical sections where retry cost is high
- Scenarios where conflicts are expected to be frequent

### 3.3 Queue-Based Dispatch

**Continuous Dispatch Scheduling:**
```
States: backlog -> ready -> running -> done

Loop:
  - Scan backlog for tasks with satisfied dependencies
  - Move satisfied tasks to "ready"
  - Dispatch ready tasks to available agents
  - No artificial "wave boundaries" - dispatch immediately
```

**Benefits:**
- No waiting for wave completion
- Better agent utilization
- Natural handling of varying task durations

### 3.4 Shared Memory / Knowledge

**Pattern: Shared Context Document**
```markdown
# shared-context.md (agents append, orchestrator reads)

## Discovered Patterns
- Auth uses JWT with 24h expiry
- Database connections pooled via pg-pool

## Decisions Made
- Agent A: Using React Query for data fetching
- Agent B: Confirmed with PostgreSQL not MySQL

## Blockers
- Need clarification on payment gateway choice
```

**Pattern: Vector-Backed Retrieval**
Claude-flow and similar tools use RAG integration so agents can query shared knowledge without consuming extra tokens.

---

## Part 4: Orchestration Frameworks

### 4.1 Claude-Flow

**Repository:** [github.com/ruvnet/claude-flow](https://github.com/ruvnet/claude-flow)

**Key features:**
- Production-ready multi-agent orchestration for Claude Code
- 54+ specialized agents in coordinated swarms
- Self-learning capabilities - learns from task execution
- Smart cost optimization - routes to cheapest capable model
- Hive Mind system - queen-led hierarchical coordination

**Architecture:**
```
Queen Agent (strategic decisions)
├── Worker Swarm A (feature development)
├── Worker Swarm B (testing)
└── Worker Swarm C (documentation)
```

**Workflow orchestration features:**
- Parallel execution with dependency management
- Stream-JSON chaining for real-time agent-to-agent communication
- Local model support (can run fully offline)
- Background workers using vector-backed retrieval

**v3 highlights:**
- Full rebuild with ~500,000 downloads
- Agents decompose work across domains
- Reuse proven patterns instead of recomputing

### 4.2 mcp-agent

**Repository:** [github.com/lastmile-ai/mcp-agent](https://github.com/lastmile-ai/mcp-agent)

**Philosophy:** Pairs Anthropic's "Building Effective Agents" patterns with batteries-included MCP runtime.

**Why teams pick it:**
- **Composable** - Every pattern ships as reusable workflow
- **MCP-native** - Any MCP server connects without custom adapters
- **Production ready** - Temporal-backed durability, structured logging, token accounting
- **Pythonic** - Decorators and context managers wire everything together

**Key patterns implemented:**
- Fan-out specialists, fan-in aggregated reports
- Route requests to best agent/server/function
- Bucket user input into intents
- Generate plans and coordinate worker agents
- Multi-agent handoffs (compatible with OpenAI Swarm)

**Programmatic control flow:**
```python
# Just write code, not graphs
if condition:
    result = await agent_a.execute(task)
else:
    result = await agent_b.execute(task)

while not evaluator.approves(result):
    result = await agent_c.improve(result)
```

### 4.3 ccswarm

**Repository:** [github.com/nwiizo/ccswarm](https://github.com/nwiizo/ccswarm)

High-performance Rust-native multi-agent orchestration:
- Zero-cost abstractions and type-state patterns
- Channel-based communication
- Specialized AI agents for collaborative development
- Git worktree isolation built-in
- Claude Code via ACP (Agent Client Protocol)

### 4.4 Swarm-IOSM

**Repository:** [github.com/rokoss21/swarm-iosm](https://github.com/rokoss21/swarm-iosm)

Claude Code Skill for parallel orchestration with quality gates:

**Core components:**
- **Continuous Dispatch Loop** - No artificial wave barriers
- **File Lock Management** - Hierarchical conflict detection
- **PRD-Driven Planning** - Requirements -> decomposition -> execution
- **IOSM Quality Gates** - Automated code quality, performance, modularity checks
- **Auto-Spawn Protocol** - Agents discover new work during execution

**IOSM methodology:** Improve -> Optimize -> Shrink -> Modularize

**Philosophy:** "Parallel development requires conflict prevention, not conflict resolution."

### 4.5 OVADARE

**Repository:** [github.com/nospecs/ovadare](https://github.com/nospecs/ovadare)

Conflict resolution framework that works alongside existing orchestration tools:
- Works with AutoGen, CrewAI
- Detects and classifies agent-level conflicts
- Customizable resolution policies
- Learning system that improves over time
- Analyzes past conflicts to adjust detection sensitivity

**Use case:** Bolt-on conflict handling for existing multi-agent setups.

### 4.6 General-Purpose Frameworks

**AutoGen (Microsoft):**
- Conversational multi-agent pattern
- Agents can be chained, supervised, reflected, composed into group chat
- Sequential, concurrent, and group chat patterns
- Good for code-heavy tasks, automated debugging

**CrewAI:**
- Role-playing, autonomous AI agents
- Two-layer architecture: Crews (dynamic collaboration) + Flows (deterministic orchestration)
- Sequential and hierarchical execution patterns
- Fast, production-ready team coordination

**LangGraph:**
- Graph-based orchestration with cycles (not just DAGs)
- Explicit state management - shared data structure across all nodes
- Send API for dynamic worker node creation
- Conditional edges based on agent confidence, system status
- Strong human-in-the-loop support

---

## Part 5: Merge Strategies

### 5.1 Git-Based Merging

**Standard merge workflow:**
```bash
# Each agent worked in isolated worktree/branch
git checkout main
git merge --no-ff feature/auth      # Agent A's work
git merge --no-ff feature/api       # Agent B's work
git merge --no-ff feature/tests     # Agent C's work
```

**Rebase for linear history:**
```bash
git checkout feature/auth
git rebase main
# Resolve conflicts
git checkout main
git merge --ff-only feature/auth
```

### 5.2 Orchestrator-Mediated Merge

**Pattern: Sequential Parallel Agent (from Google ADK):**
```
1. ParallelAgent runs all workers (populates shared state)
2. MergerAgent synthesizes results into final output
3. Sequential orchestration ensures proper ordering
```

**Pattern: Human-in-the-Loop Merge:**
```
Workers complete -> PRs created -> Human review -> Merge approval
```

### 5.3 Conflict Resolution Strategies

**Prevention first:**
- Clear file ownership
- Strict task boundaries
- Lock shared resources

**When conflicts occur:**
- Prioritization (later changes win, or earlier)
- Backoff and retry (optimistic approach)
- Token-based control (one agent holds merge token)
- Voting systems or priority rules
- Escalate to human orchestrator

**Intent modeling:**
```
Agent A intent: Add authentication middleware
Agent B intent: Refactor middleware pipeline
Conflict: Both touch middleware.ts
Resolution: Sequence A then B, or merge intents
```

---

## Part 6: Quality Gates

### 6.1 IOSM Methodology

**Improve -> Optimize -> Shrink -> Modularize**

Each agent's output passes through quality gates:
1. **Improve:** Does it work? Tests pass?
2. **Optimize:** Performance acceptable?
3. **Shrink:** No unnecessary code?
4. **Modularize:** Clean interfaces? Reusable?

### 6.2 Automated Checks

```yaml
quality_gates:
  - lint: eslint --fix
  - typecheck: tsc --noEmit
  - test: npm test
  - coverage: >80%
  - bundle_size: <500KB
```

### 6.3 Integration Testing

Before merge:
- Run full test suite
- Check for import conflicts
- Verify API contracts
- Performance regression tests

---

## Part 7: Recommendations for Nancy

### Immediate Opportunities

**1. Git Worktree Integration**
```bash
# nancy start --parallel
# Creates: .nancy/worktrees/task-{id}/
#   - Isolated filesystem for worker
#   - Own branch: nancy-{task}-{session}
#   - Standard merge back to main
```

**2. File Lock Manager**
```yaml
# .nancy/locks.yaml
src/auth/middleware.ts:
  owner: nancy-auth-iter3
  acquired: 2025-01-22T10:30:00Z
  type: exclusive
```

**3. Task Decomposition in Specs**
```markdown
# SPEC.md additions

## Parallel Tracks
- Track A: API endpoints (files: src/api/*)
- Track B: Database models (files: src/models/*)
- Track C: Tests (files: tests/*)

## Shared Resources (locked during parallel phase)
- src/types/index.ts
- src/config/database.ts
```

### Medium-Term Architecture

**Orchestrator Enhancements:**
```
Current: Human orchestrator -> Single worker
Future:  Human orchestrator -> Worker coordinator -> Multiple workers
```

**Worker Coordinator responsibilities:**
- Decompose spec into parallel tracks
- Assign tracks to workers (worktrees)
- Monitor for conflicts
- Coordinate merge sequence
- Run integration tests

**Communication:**
```
comms/
├── orchestrator-to-coordinator.md
├── coordinator-to-worker-a.md
├── coordinator-to-worker-b.md
└── shared-context.md
```

### Long-Term Vision

**Swarm-Compatible Nancy:**
```yaml
# .nancy/config.yaml
parallel:
  enabled: true
  max_workers: 4
  isolation: worktree  # or container, or remote

  coordination:
    locks: file-based
    merge_strategy: sequential-then-human-review

  quality_gates:
    - tests
    - lint
    - typecheck
```

**Integration with Linear:**
```
Linear Issue (Epic) -> Nancy decomposes into tracks
  -> Track A -> Worker A (Linear sub-issue)
  -> Track B -> Worker B (Linear sub-issue)
  -> Merge -> Human review -> Done
```

---

## Summary

### Key Principles

1. **Isolation is non-negotiable** - Git worktrees provide the foundation
2. **Prevention beats resolution** - File locks and clear boundaries reduce conflicts
3. **Start small** - 2-3 agents, master workflow, then scale
4. **Budget for integration** - Parallel execution is only half the battle
5. **Quality gates enforce standards** - IOSM or similar methodology

### Framework Selection Guide

| Framework | Best For | Complexity |
|-----------|----------|------------|
| mcp-agent | MCP-native workflows, Temporal durability | Medium |
| claude-flow | Claude Code swarms, self-learning systems | High |
| Swarm-IOSM | Claude Code skills, quality gates | Medium |
| ccswarm | Rust performance, type-safe coordination | High |
| OVADARE | Bolt-on conflict resolution | Low |
| LangGraph | Complex state management, conditional flows | High |
| CrewAI | Quick team-based coordination | Low |

### Implementation Priority for Nancy

1. **Now:** Document worktree-based parallel workflow
2. **Next:** Add file lock tracking to orchestrator
3. **Later:** Build worker coordinator for automated decomposition
4. **Future:** Full swarm compatibility with quality gates

---

## Sources

### Orchestration Frameworks
- [Claude-Flow](https://github.com/ruvnet/claude-flow) - Multi-agent swarm orchestration for Claude
- [mcp-agent](https://github.com/lastmile-ai/mcp-agent) - MCP-native workflow patterns
- [ccswarm](https://github.com/nwiizo/ccswarm) - Rust-native multi-agent orchestration
- [Swarm-IOSM](https://dev.to/rokoss21/swarm-iosm-orchestrating-parallel-ai-agents-with-quality-gates-8fk) - Quality gates for parallel agents
- [OVADARE](https://github.com/nospecs/ovadare) - Conflict resolution framework
- [AutoGen](https://github.com/microsoft/autogen) - Microsoft's multi-agent framework
- [CrewAI](https://github.com/crewAIInc/crewAI) - Role-playing autonomous agents
- [LangGraph](https://www.langchain.com/langgraph) - Graph-based agent orchestration

### Parallel Development Patterns
- [Git Worktrees for AI Agents](https://medium.com/@mabd.dev/git-worktrees-the-secret-weapon-for-running-multiple-ai-coding-agents-in-parallel-e9046451eb96)
- [Parallel AI Coding with Git Worktrees](https://docs.agentinterviews.com/blog/parallel-ai-coding-with-gitworktrees/)
- [Multi-Agent Coding: Parallel Development Guide](https://www.digitalapplied.com/blog/multi-agent-coding-parallel-development)
- [Parallelizing AI Coding Agents](https://ainativedev.io/news/how-to-parallelize-ai-coding-agents)
- [Programming by Parallel AI Agents](https://blog.pragmaticengineer.com/new-trend-programming-by-kicking-off-parallel-ai-agents/)

### Conflict Resolution
- [Scaling AI Agents with Aspire Isolation](https://devblogs.microsoft.com/aspire/scaling-ai-agents-with-aspire-isolation/)
- [Parallel Agents - Shipping Without Chaos](https://dev.to/rokoss21/parallel-agents-are-easy-shipping-without-chaos-isnt-1kek)
- [Conflict Resolution for Multi-Agents](https://www.theunwindai.com/p/conflict-resolution-for-multi-agents)
- [Agent-MCP Framework](https://github.com/rinadelph/Agent-MCP)

### Task Decomposition
- [Task Decomposition Strategies](https://apxml.com/courses/agentic-llm-memory-architectures/chapter-4-complex-planning-tool-integration/task-decomposition-strategies)
- [Building Agentic Task Decomposition](https://python.plainenglish.io/building-agentic-task-decomposition-how-we-made-ai-break-down-complex-problems-de8824caf080)
- [TDAG: Dynamic Task Decomposition](https://www.sciencedirect.com/science/article/abs/pii/S0893608025000796)

### Industry Perspectives
- [AI Engineering Trends 2025](https://thenewstack.io/ai-engineering-trends-in-2025-agents-mcp-and-vibe-coding/)
- [VS Code Multi-Agent Orchestration](https://visualstudiomagazine.com/articles/2025/12/12/vs-code-1-107-november-2025-update-expands-multi-agent-orchestration-model-management.aspx)
- [GitHub: Orchestrating Agents with Mission Control](https://github.blog/ai-and-ml/github-copilot/how-to-orchestrate-agents-using-mission-control/)
- [Cursor Multi-Agent System](https://www.digitalapplied.com/blog/multi-agent-coding-parallel-development)
