# Agentic-Flow Agent System Design Analysis

**Repository**: `/Users/alphab/Dev/LLM/DEV/agentic-flow`
**Version Analyzed**: v2.0.0-alpha
**Date**: 2025-01-22

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Agent Architecture and Abstractions](#agent-architecture-and-abstractions)
3. [Agent Definition Structure](#agent-definition-structure)
4. [Lifecycle Hooks and Events](#lifecycle-hooks-and-events)
5. [Communication Patterns](#communication-patterns)
6. [Agent Capabilities and Tools](#agent-capabilities-and-tools)
7. [Coordination Systems](#coordination-systems)
8. [Federation and Distributed Agents](#federation-and-distributed-agents)
9. [What Could Be Lifted/Shipped](#what-could-be-liftedshipped)
10. [Recommendations for Nancy](#recommendations-for-nancy)
11. [Strengths and Weaknesses](#strengths-and-weaknesses)

---

## Executive Summary

Agentic-Flow is a production-ready AI agent orchestration platform built on Claude Agent SDK. It features:

- **66 self-learning specialized agents** defined as markdown files with YAML frontmatter
- **213 MCP tools** for coordination, memory, and task orchestration
- **Multiple coordination topologies**: mesh, hierarchical, ring, star
- **Advanced attention mechanisms** for multi-agent consensus
- **Federation system** for distributed agents with QUIC transport
- **ReasoningBank** closed-loop memory system for continuous learning

The architecture separates agent definitions (declarative markdown) from execution (TypeScript runtime), using hooks for lifecycle management and MCP for inter-agent communication.

---

## Agent Architecture and Abstractions

### Core Layered Architecture

```
+----------------------------------------------------------+
|                    User/Task Interface                    |
+----------------------------------------------------------+
            |                        |
            v                        v
+-------------------------+  +-------------------------+
|     CLI/Entry Point     |  |      MCP Tools (213)    |
|   (src/index.ts)        |  | (claudeFlowSdkServer)   |
+-------------------------+  +-------------------------+
            |                        |
            v                        v
+----------------------------------------------------------+
|                   Claude Agent SDK                        |
|           (@anthropic-ai/claude-agent-sdk)               |
+----------------------------------------------------------+
            |
            v
+----------------------------------------------------------+
|                 Agent Execution Layer                     |
|   claudeAgent.ts, claudeFlowAgent.ts, directApiAgent.ts  |
+----------------------------------------------------------+
            |                        |                    |
            v                        v                    v
+------------------+  +-------------------+  +------------------+
|  Agent Loader    |  |   Coordination    |  |   Federation     |
| (.claude/agents) |  |   (Attention,     |  | (QUIC, mTLS,     |
|                  |  |    Swarm)         |  |  Vector Clocks)  |
+------------------+  +-------------------+  +------------------+
            |                        |                    |
            v                        v                    v
+----------------------------------------------------------+
|                      Memory Layer                         |
|    ReasoningBank, AgentDB, HybridBackend, SQLite         |
+----------------------------------------------------------+
```

### Key Abstractions

**1. AgentDefinition** (`src/utils/agentLoader.ts`)
```typescript
interface AgentDefinition {
  name: string;           // Unique agent identifier
  description: string;    // Human-readable description
  systemPrompt: string;   // The markdown body becomes the system prompt
  color?: string;         // UI color for visualization
  tools?: string[];       // Allowed tools
  filePath: string;       // Source file path
}
```

**2. SwarmAgent** (`src/swarm/quic-coordinator.ts`)
```typescript
interface SwarmAgent {
  id: string;
  role: AgentRole;           // 'coordinator' | 'worker' | 'aggregator' | 'validator'
  host: string;
  port: number;
  capabilities: string[];
  metadata?: Record<string, any>;
}
```

**3. AgentOutput** (`src/coordination/attention-coordinator.ts`)
```typescript
interface AgentOutput {
  agentId: string;
  agentType: string;
  embedding: Float32Array;   // Vector representation for attention
  value: any;
  confidence?: number;
  metadata?: Record<string, any>;
}
```

---

## Agent Definition Structure

Agents are defined as markdown files with YAML frontmatter in `.claude/agents/`. This is a clever pattern that makes agents:
- Human-readable and editable
- Version-controllable
- Extensible with hooks

### Example Agent Definition

**File**: `.claude/agents/core/coder.md`

```markdown
---
name: coder
type: developer
color: "#FF6B35"
description: Implementation specialist for writing clean, efficient code
capabilities:
  - code_generation
  - refactoring
  - optimization
  - api_design
  - error_handling
priority: high
hooks:
  pre: |
    echo "Coder agent implementing: $TASK"
    if grep -q "test\|spec" <<< "$TASK"; then
      echo "Remember: Write tests first (TDD)"
    fi
  post: |
    echo "Implementation complete"
    if [ -f "package.json" ]; then
      npm run lint --if-present
    fi
---

# Code Implementation Agent

You are a senior software engineer...
[Full system prompt follows]
```

### Agent Categories (66 Total)

| Category | Agent Types | Key File |
|----------|-------------|----------|
| **Core Development** | coder, reviewer, tester, planner, researcher | `.claude/agents/core/` |
| **Swarm Coordination** | hierarchical-coordinator, mesh-coordinator, adaptive-coordinator | `.claude/agents/swarm/` |
| **Consensus** | byzantine-coordinator, raft-manager, gossip-coordinator, quorum-manager | `.claude/agents/consensus/` |
| **GitHub** | pr-manager, code-review-swarm, issue-tracker, release-manager | `.claude/agents/github/` |
| **SPARC** | specification, pseudocode, architecture, refinement | `.claude/agents/sparc/` |
| **Reasoning** | adaptive-learner, context-synthesizer, pattern-matcher | `.claude/agents/reasoning/` |
| **Hive Mind** | queen-coordinator, scout-explorer, worker-specialist | `.claude/agents/hive-mind/` |

### Agent Loader Mechanism

**File**: `src/utils/agentLoader.ts`

The loader:
1. Scans `.claude/agents/` directories recursively
2. Parses YAML frontmatter for metadata
3. Extracts markdown body as system prompt
4. Supports local agent overrides (project `.claude/agents/` overrides package defaults)

```typescript
// Key function - loads agents with deduplication
function loadAgents(agentsDir?: string): Map<string, AgentDefinition> {
  // 1. Load package agents first
  // 2. Load local agents (override package agents with same relative path)
  // 3. Return deduplicated Map
}
```

---

## Lifecycle Hooks and Events

### Hook Points

Agentic-Flow provides several hook integration points:

**1. Agent-Level Hooks** (defined in frontmatter)
```yaml
hooks:
  pre: |
    # Runs before agent execution
    mcp__claude-flow__memory_usage store "swarm/status" "starting"
  post: |
    # Runs after agent execution
    mcp__claude-flow__performance_report
```

**2. Session Hooks** (`src/hooks/p2p-swarm-hooks.ts`)
```typescript
// SessionStart - Initialize P2P swarm connection
async function onSessionStart(config?: {
  agentId?: string;
  swarmKey?: string;
  enableExecutor?: boolean;
}): Promise<SessionStartResult>

// Stop - Cleanup P2P swarm connection
function onStop(): void

// PreToolUse - Check swarm status before tool execution
async function onPreToolUse(toolName: string, params: Record<string, any>): Promise<{
  allow: boolean;
  swarmConnected: boolean;
  liveMembers: number;
  recommendation?: string;
}>

// PostToolUse - Sync learning data after tool execution
async function onPostToolUse(
  toolName: string,
  params: Record<string, any>,
  result: any
): Promise<{
  synced: boolean;
  syncType?: string;
  messageId?: string;
}>
```

**3. Long-Running Agent Lifecycle** (`src/core/long-running-agent.ts`)
```typescript
class LongRunningAgent {
  async start(): Promise<void>           // Start with checkpointing
  async executeTask<T>(task): Promise<T> // Execute with fallback
  async stop(): Promise<void>            // Cleanup and final checkpoint

  // Automatic checkpointing
  private saveCheckpoint(): void         // Save state periodically
  restoreFromCheckpoint(cp): void        // Resume from checkpoint
}
```

**4. Ephemeral Agent Lifecycle** (`src/federation/EphemeralAgent.ts`)
```typescript
class EphemeralAgent {
  static async spawn(config): Promise<EphemeralAgent>  // Create agent
  async execute<T>(task): Promise<T>                   // Run with sync
  async destroy(): Promise<void>                       // Cleanup (memory persists)

  // Automatic lifecycle management
  // - TTL-based expiration
  // - Periodic federation sync
  // - Final sync on destroy
}
```

### Lifecycle Flow Diagram

```
                    +------------------+
                    |   Agent Spawn    |
                    +--------+---------+
                             |
                    +--------v---------+
                    |  Pre-Task Hook   |
                    | - Check swarm    |
                    | - Load memories  |
                    | - Init resources |
                    +--------+---------+
                             |
                    +--------v---------+
                    |  Task Execution  |
                    | - Claude SDK     |
                    | - Tool calls     |
                    | - Streaming      |
                    +--------+---------+
                             |
          +------------------+------------------+
          |                                     |
+---------v----------+             +-----------v---------+
|  Post-Edit Hook    |             |  Post-Tool Hook     |
| - Memory sync      |             | - Learn patterns    |
| - Publish changes  |             | - Update Q-table    |
+--------------------+             +---------------------+
          |                                     |
          +------------------+------------------+
                             |
                    +--------v---------+
                    |  Post-Task Hook  |
                    | - Store episode  |
                    | - Sync federation|
                    | - Update metrics |
                    +--------+---------+
                             |
                    +--------v---------+
                    |   Checkpoint     |
                    | (if long-running)|
                    +--------+---------+
                             |
                    +--------v---------+
                    |  Agent Destroy   |
                    | - Final sync     |
                    | - Cleanup        |
                    +------------------+
```

---

## Communication Patterns

### 1. Swarm Messaging (QUIC)

**File**: `src/swarm/quic-coordinator.ts`

```typescript
interface SwarmMessage {
  id: string;
  from: string;
  to: string | string[];  // '*' for broadcast
  type: 'task' | 'result' | 'state' | 'heartbeat' | 'sync';
  payload: any;
  timestamp: number;
  ttl?: number;
}
```

**Topology-Aware Routing**:

| Topology | Routing Behavior |
|----------|------------------|
| **Mesh** | Direct routing to all recipients |
| **Hierarchical** | Workers route through coordinator |
| **Ring** | Forward to next agent in ring |
| **Star** | All traffic through central coordinator |

### 2. Memory-Based Coordination (MCP)

Agents coordinate through shared memory namespaces:

```javascript
// Store coordination state
mcp__claude-flow__memory_usage {
  action: "store",
  key: "swarm/hierarchical/status",
  namespace: "coordination",
  value: JSON.stringify({
    agent: "hierarchical-coordinator",
    status: "active",
    workers: ["worker-1", "worker-2"],
    progress: 45
  })
}

// Retrieve other agent's state
mcp__claude-flow__memory_usage {
  action: "retrieve",
  key: "swarm/worker-1/status",
  namespace: "coordination"
}
```

### 3. Attention-Based Consensus

**File**: `src/coordination/attention-coordinator.ts`

```typescript
// Multi-agent coordination using attention mechanisms
async coordinateAgents(
  agentOutputs: AgentOutput[],
  mechanism: 'flash' | 'multi-head' | 'linear' | 'hyperbolic' | 'moe' | 'graph-rope'
): Promise<CoordinationResult>

// Expert routing using Mixture-of-Experts
async routeToExperts(
  task: Task,
  agents: SpecializedAgent[],
  topK: number
): Promise<ExpertRoutingResult>

// Topology-aware coordination
async topologyAwareCoordination(
  agentOutputs: AgentOutput[],
  topology: SwarmTopology,
  graphStructure?: GraphContext
): Promise<CoordinationResult>
```

### 4. Federation Sync (Vector Clocks)

**File**: `src/federation/FederationHub.ts`

```typescript
interface SyncMessage {
  type: 'push' | 'pull' | 'ack';
  agentId: string;
  tenantId: string;
  vectorClock: Record<string, number>;  // Conflict detection
  data?: any[];
  timestamp: number;
}
```

Conflict resolution uses vector clocks:
- Two updates conflict if neither vector clock dominates
- Last-write-wins (CRDT) resolution by default

### 5. P2P Swarm (Pub/Sub)

**File**: `src/hooks/p2p-swarm-hooks.ts`

```typescript
// Topic-based pub/sub
subscribeToTopic(topic: string, callback: (data, from) => void)
publishToTopic(topic: string, payload: any): Promise<string | null>

// Predefined topics
// - file_changes: File edit notifications
// - commands: Bash command executions
// - learning: Q-table and memory sync
```

---

## Agent Capabilities and Tools

### Built-in Tools (Claude SDK)

From `claudeAgent.ts`:
```typescript
allowedTools: [
  'Read',        // File reading
  'Write',       // File writing
  'Edit',        // File editing
  'Bash',        // Command execution
  'Glob',        // File pattern matching
  'Grep',        // Content search
  'WebFetch',    // HTTP requests
  'WebSearch',   // Web search
  'NotebookEdit',// Jupyter notebooks
  'TodoWrite'    // Task tracking
]
```

### MCP Tools (213 Total)

**Categories**:

**1. Memory Tools**
```typescript
tool('memory_store', ...)    // Store to persistent memory
tool('memory_retrieve', ...) // Get from memory
tool('memory_search', ...)   // Pattern search
```

**2. Swarm Tools**
```typescript
tool('swarm_init', ...)      // Initialize swarm topology
tool('agent_spawn', ...)     // Create new agent
tool('task_orchestrate', ...)// Coordinate complex tasks
tool('swarm_status', ...)    // Get swarm metrics
```

**3. Agent Booster (WASM)**
```typescript
tool('agent_booster_edit_file', ...)   // 352x faster code editing
tool('agent_booster_batch_edit', ...)  // Parallel multi-file edits
```

### Capability Declaration

Agents declare capabilities in frontmatter:
```yaml
capabilities:
  - code_generation
  - refactoring
  - optimization
  - api_design
  - error_handling
```

These are used for:
1. Task routing (matching tasks to capable agents)
2. Expert selection (MoE attention routing)
3. Load balancing (distribute by capability)

---

## Coordination Systems

### 1. QuicCoordinator

**File**: `src/swarm/quic-coordinator.ts`

Low-latency QUIC-based coordination:
- Connection pooling
- Heartbeat monitoring (default: 10s)
- State synchronization (default: 5s)
- Per-agent statistics tracking

```typescript
class QuicCoordinator {
  async registerAgent(agent: SwarmAgent): Promise<void>
  async sendMessage(message: SwarmMessage): Promise<void>
  async broadcast(message: SwarmMessage): Promise<void>
  async syncState(): Promise<void>
}
```

### 2. AttentionCoordinator

**File**: `src/coordination/attention-coordinator.ts`

Neural attention for intelligent consensus:

| Mechanism | Use Case | Performance |
|-----------|----------|-------------|
| **Flash** | Default, fast | 2.49x-7.47x speedup |
| **Multi-Head** | Complex decisions | <0.1ms latency |
| **Linear** | Long sequences | O(n) complexity |
| **Hyperbolic** | Hierarchies | Queen-worker swarms |
| **MoE** | Expert routing | Sparse activation |
| **GraphRoPE** | Topology-aware | Graph structure |

### 3. Hierarchical Swarm

Queen-worker model:
```
       Queen (Coordinator)
      /   |   |   \
   W1    W2   W3   W4

- Queen: Strategic planning, task decomposition
- Workers: Execution, specialized capabilities
```

### 4. Mesh/Ring/Star Topologies

Configurable via swarm_init:
```typescript
await initSwarm({
  swarmId: 'my-swarm',
  topology: 'mesh' | 'hierarchical' | 'ring' | 'star',
  transport: 'quic' | 'http2' | 'auto',
  maxAgents: 10
});
```

---

## Federation and Distributed Agents

### FederationHub

**File**: `src/federation/FederationHub.ts`

QUIC-based synchronization for distributed agents:

```typescript
class FederationHub {
  async connect(): Promise<void>
  async sync(db: AgentDB): Promise<void>
  async disconnect(): Promise<void>

  // Features:
  // - mTLS transport security
  // - Vector clocks for conflict detection
  // - Push/pull synchronization
  // - Tenant isolation (JWT auth)
}
```

### EphemeralAgent

**File**: `src/federation/EphemeralAgent.ts`

Short-lived agents with persistent memory:

```typescript
class EphemeralAgent {
  static async spawn(config: {
    tenantId: string;
    lifetime?: number;       // TTL in seconds (default: 300)
    hubEndpoint?: string;    // Federation hub URL
    syncInterval?: number;   // Sync period (default: 5000ms)
  }): Promise<EphemeralAgent>

  async execute<T>(task): Promise<T>  // Auto-sync before/after
  async queryMemories(task, k): Promise<any[]>
  async storeEpisode(episode): Promise<void>
  async destroy(): Promise<void>      // Memory persists
}
```

### Long-Running Agent

**File**: `src/core/long-running-agent.ts`

Agents that run for hours/days with resilience:

```typescript
class LongRunningAgent {
  // Budget management
  costBudget?: number;        // Max USD
  maxRuntime?: number;        // Max milliseconds

  // Provider fallback
  fallbackStrategy: FallbackStrategy;

  // Checkpointing
  checkpointInterval?: number;
  restoreFromCheckpoint(checkpoint): void;
}
```

---

## What Could Be Lifted/Shipped

### High-Value Patterns for Nancy

**1. Agent Definition Format**
```markdown
---
name: agent-name
type: category
capabilities: [...]
hooks:
  pre: |
    # Pre-execution hook
  post: |
    # Post-execution hook
---

# System Prompt Body
```

**Why**: Clean separation of metadata and behavior, version-controllable, human-editable.

**2. Hook System Architecture**
```typescript
interface HookSystem {
  onSessionStart(config): Promise<Result>
  onPreToolUse(tool, params): Promise<{allow, recommendation}>
  onPostToolUse(tool, params, result): Promise<{synced}>
  onStop(): void
}
```

**Why**: Extensible lifecycle management without modifying core code.

**3. Memory-Based Coordination**
```typescript
// Namespace-based shared state
memory_store("swarm/agent-1/status", {...}, "coordination")
memory_retrieve("swarm/shared/config", "coordination")
```

**Why**: Decoupled communication, works with existing file-based storage.

**4. Topology Routing Patterns**
```typescript
function applyTopologyRouting(sender, recipients, topology) {
  switch (topology) {
    case 'mesh': return recipients;  // Direct
    case 'hierarchical': return routeThroughCoordinator(sender, recipients);
    case 'ring': return [nextInRing(sender)];
    case 'star': return [centralCoordinator];
  }
}
```

**Why**: Reusable for Nancy's orchestrator/worker model.

**5. Checkpoint/Resume Pattern**
```typescript
interface AgentCheckpoint {
  timestamp: Date;
  taskProgress: number;
  currentProvider: string;
  totalCost: number;
  state: Record<string, any>;
}

class LongRunningAgent {
  saveCheckpoint(): void
  restoreFromCheckpoint(checkpoint): void
}
```

**Why**: Essential for Nancy's autonomous execution.

### Components NOT to Lift

1. **QUIC Transport** - Overkill for CLI tool, Nancy uses filesystem
2. **AgentDB Vector Search** - Complex dependency, Nancy has simpler needs
3. **Attention Mechanisms** - Requires vector embeddings, too heavy
4. **Federation Hub** - Network-based, Nancy is local-first

---

## Recommendations for Nancy

### 1. Adopt Markdown Agent Definitions

Instead of just skill markdown files, create agent definition format:

```markdown
---
name: executor
type: worker
capabilities: [code, bash, files]
priority: high
hooks:
  pre: |
    nancy check-directives
  post: |
    nancy send-message --type progress
---

# Worker Agent Instructions

You are an autonomous execution agent...
```

### 2. Implement Session Hooks

Add hook points to Nancy's worker:

```bash
# In skill execution
_run_pre_hook() {
  if [[ -f ".nancy/hooks/pre-task.sh" ]]; then
    source ".nancy/hooks/pre-task.sh" "$@"
  fi
}

_run_post_hook() {
  if [[ -f ".nancy/hooks/post-task.sh" ]]; then
    source ".nancy/hooks/post-task.sh" "$@"
  fi
}
```

### 3. Structured Agent Communication

Formalize the message types:

```bash
# Message types
MSG_TYPE_PROGRESS="progress"
MSG_TYPE_BLOCKER="blocker"
MSG_TYPE_COMPLETE="complete"
MSG_TYPE_DIRECTIVE="directive"

# Message format
send_structured_message() {
  local type="$1"
  local content="$2"
  local metadata="${3:-{}}"

  jq -n \
    --arg type "$type" \
    --arg content "$content" \
    --argjson meta "$metadata" \
    '{type: $type, content: $content, metadata: $meta, timestamp: now}'
}
```

### 4. Checkpoint/Resume for Workers

Add state persistence to worker sessions:

```bash
save_worker_checkpoint() {
  local checkpoint_file="$STATE_DIR/checkpoint.json"
  jq -n \
    --arg phase "$CURRENT_PHASE" \
    --arg task "$CURRENT_TASK" \
    --argjson progress "$PROGRESS" \
    '{phase: $phase, task: $task, progress: $progress, timestamp: now}' \
    > "$checkpoint_file"
}

restore_from_checkpoint() {
  local checkpoint_file="$STATE_DIR/checkpoint.json"
  if [[ -f "$checkpoint_file" ]]; then
    CURRENT_PHASE=$(jq -r '.phase' "$checkpoint_file")
    CURRENT_TASK=$(jq -r '.task' "$checkpoint_file")
    PROGRESS=$(jq '.progress' "$checkpoint_file")
  fi
}
```

### 5. Hierarchical Coordination Pattern

For orchestrator-worker model:

```
Orchestrator (Queen)
├── Sends directives via outbox
├── Monitors worker state
├── Handles escalations
└── Coordinates checkpoints

Worker (Drone)
├── Polls inbox for directives
├── Reports progress
├── Requests review when uncertain
└── Handles state persistence
```

---

## Strengths and Weaknesses

### Strengths

**1. Clean Agent Abstraction**
- Markdown files are human-friendly and version-controllable
- Frontmatter provides structured metadata
- System prompt is the markdown body (natural)

**2. Flexible Coordination**
- Multiple topologies (mesh, hierarchical, ring, star)
- Attention-based consensus is sophisticated
- Memory-based communication is decoupled

**3. Production Features**
- Provider fallback for resilience
- Checkpointing for long-running tasks
- Cost and budget tracking
- Federation for distributed agents

**4. Extensible Hooks**
- Pre/post hooks at multiple levels
- Tool-level hooks for learning
- Session hooks for coordination

**5. Learning Integration**
- ReasoningBank for closed-loop learning
- Q-table synchronization across swarm
- Pattern storage and retrieval

### Weaknesses

**1. Complexity Overhead**
- 213 MCP tools is overwhelming
- Multiple coordination systems (QUIC, attention, P2P, federation)
- Heavy dependencies (AgentDB, ONNX, WASM)

**2. Unclear Execution Model**
- Agents defined in markdown but executed by Claude SDK
- Hook shells vs TypeScript mixing is confusing
- Not clear when to use which coordination pattern

**3. Incomplete Implementations**
- Federation is partially stubbed ("placeholder" comments)
- QUIC transport requires external quiche library
- Some agents have identical patterns (copy-paste)

**4. Documentation vs Reality Gap**
- Claims 84.8% SWE-Bench but no reproducible benchmark
- Performance numbers without test methodology
- Many "v2.0.0-alpha" features not fully implemented

**5. Provider Lock-in**
- Heavily tied to Claude Agent SDK
- Proxy workarounds for other providers are fragile
- MCP tool calls via shell exec (npx claude-flow) is slow

### Lessons for Nancy

**DO**:
- Use markdown for agent/skill definitions
- Implement clear lifecycle hooks
- Support checkpoint/resume
- Keep communication decoupled (file-based)

**DON'T**:
- Over-engineer coordination (KISS)
- Add complex neural features early
- Create 200+ tools before proving value
- Mix shell and TypeScript execution models

---

## Summary

Agentic-Flow provides a sophisticated agent system with strong abstractions for agent definition, lifecycle management, and multi-agent coordination. The markdown-based agent definition format, hook system, and checkpoint/resume patterns are particularly valuable for Nancy to adopt.

However, the system suffers from complexity creep - too many coordination mechanisms, unclear execution boundaries, and incomplete implementations. Nancy should focus on lifting the clean patterns (agent definitions, hooks, checkpoints) while avoiding the complexity trap of neural attention mechanisms and distributed federation systems.

**Key files to study**:
- `/Users/alphab/Dev/LLM/DEV/agentic-flow/.claude/agents/core/coder.md` - Agent definition example
- `/Users/alphab/Dev/LLM/DEV/agentic-flow/agentic-flow/src/utils/agentLoader.ts` - Agent loading
- `/Users/alphab/Dev/LLM/DEV/agentic-flow/agentic-flow/src/hooks/p2p-swarm-hooks.ts` - Hook patterns
- `/Users/alphab/Dev/LLM/DEV/agentic-flow/agentic-flow/src/core/long-running-agent.ts` - Checkpointing
- `/Users/alphab/Dev/LLM/DEV/agentic-flow/agentic-flow/src/coordination/attention-coordinator.ts` - Coordination
