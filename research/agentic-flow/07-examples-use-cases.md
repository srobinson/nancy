# Agentic-Flow Examples and Use Cases Deep Dive

## Overview

This document provides a comprehensive analysis of the examples and use cases demonstrated in the agentic-flow project. The project has an extensive collection of examples showcasing multi-agent orchestration, distributed systems, specialized applications, and integration patterns.

**Source:** `/Users/alphab/Dev/LLM/DEV/agentic-flow/`

---

## 1. Catalog of Examples

### 1.1 Root Examples Directory (`/examples/`)

| File/Directory | Type | Purpose | Complexity |
|----------------|------|---------|------------|
| `batch-query.js` | Script | Batch vector query operations | Simple |
| `batch-store.js` | Script | Batch memory storage operations | Simple |
| `billing-example.ts` | TypeScript | Complete subscription/billing system | Complex |
| `cached-query.js` | Script | Caching layer for queries | Medium |
| `climate-prediction/` | Project | Full Rust ML prediction system | Enterprise |
| `complex-multi-agent-deployment.ts` | TypeScript | Hierarchical swarm deployment | Complex |
| `connection-pool.js` | Script | Database connection pooling | Medium |
| `deepseek-agent-demo.sh` | Shell | DeepSeek model integration | Medium |
| `deepseek-direct-api.js` | JavaScript | Direct API usage | Simple |
| `deepseek-simple-test.sh` | Shell | Quick model test | Simple |
| `nova-medicina/` | Project | Medical AI triage system | Enterprise |
| `Observer-Agnostic Measurement/` | Research | Quantum computing implementation | Research |
| `optimal-deployment/` | Directory | Deployment configurations | Medium |
| `perf-monitor.js` | Script | Performance monitoring | Medium |
| `quic-server-coordinator.js` | JavaScript | QUIC server for swarm coordination | Complex |
| `quic-swarm-coordination.js` | JavaScript | Distributed swarm with QUIC | Complex |
| `reasoningbank-benchmark.js` | Script | Performance benchmarking | Medium |
| `reasoningbank-learning-demo.js` | Script | Self-learning demo | Medium |
| `reasoningbank-optimize.js` | Script | Optimization patterns | Medium |
| `research-swarm/` | Project | Research coordination swarm | Complex |
| `rights-preserving-platform/` | Directory | Privacy-focused implementation | Complex |
| `verification-example.ts` | TypeScript | Anti-hallucination verification | Complex |

### 1.2 Inner agentic-flow Examples (`/agentic-flow/examples/`)

| File | Type | Purpose |
|------|------|---------|
| `agent-debug-example.ts` | TypeScript | Agent debugging patterns |
| `crispr-cas13-pipeline/` | Project | Bioinformatics pipeline |
| `debug-streaming-example.ts` | TypeScript | Streaming debug outputs |
| `federated-agentdb/` | Directory | Federated database setup |
| `quic-swarm-auto-fallback.ts` | TypeScript | Auto-fallback QUIC patterns |
| `quic-swarm-hierarchical.ts` | TypeScript | Hierarchical topology |
| `quic-swarm-mesh.ts` | TypeScript | Mesh topology |
| `realtime-federation-example.ts` | TypeScript | Real-time agent federation |
| `regression-test.ts` | TypeScript | Test regression patterns |
| `test-claude-code-emulation.ts` | TypeScript | Claude tool emulation |
| `tool-emulation-demo.ts` | TypeScript | Tool emulation for models without native tools |

### 1.3 Package Examples

#### AgentDB (`/packages/agentdb/examples/`)
- `quickstart.js` - Basic initialization
- `cache-performance-demo.ts` - Cache optimization
- `federated-learning-example.ts` - Distributed learning
- `parallel-batch-insert.ts` - High-throughput operations
- `telemetry-integration-*.ts` - OpenTelemetry integrations

#### Agentic-Jujutsu (`/packages/agentic-jujutsu/examples/`)
- `multi-agent-demo.js` - Multi-agent coordination with QuantumDAG
- `quantum_signing_demo.js` - Cryptographic signing

---

## 2. Use Case Analysis

### 2.1 Multi-Agent Coordination

**Files:** `complex-multi-agent-deployment.ts`, `multi-agent-demo.js`, `MULTI-AGENT-DEPLOYMENT.md`

**Use Case:** Deploy and orchestrate multiple specialized AI agents working on shared tasks.

**Key Patterns:**
```typescript
// Hierarchical swarm topology
const agentTypes = [
  { type: 'coordinator', capabilities: ['task-delegation', 'conflict-resolution'] },
  { type: 'analyst', capabilities: ['data-analysis', 'pattern-recognition'] },
  { type: 'coder', capabilities: ['code-generation', 'refactoring'] },
  { type: 'optimizer', capabilities: ['performance-tuning', 'bottleneck-detection'] }
];

// Memory coordination with namespaces
const memoryNamespaces = [
  { namespace: 'swarm-state', key: 'topology', value: 'hierarchical-8-agents', ttl: 3600 },
  { namespace: 'task-queue', key: 'pending-tasks', value: JSON.stringify([]), ttl: 7200 },
  { namespace: 'agent-knowledge', key: 'shared-context', value: '...', ttl: 86400 }
];
```

**Nancy Relevance:** HIGH - Core orchestration patterns directly applicable to Nancy's multi-agent coordination needs.

---

### 2.2 Cost-Efficient Model Usage (DeepSeek)

**Files:** `DEEPSEEK_AGENT_EXAMPLES.md`, `deepseek-agent-demo.sh`, `deepseek-direct-api.js`

**Use Case:** Use DeepSeek models via OpenRouter for 97%+ cost savings over Claude.

**Key Pattern:**
```bash
# Basic usage - 97.8% cost savings
npx claude-flow agent run \
  --agent coder \
  --model "deepseek/deepseek-chat" \
  --task "Create a Python function that validates email addresses" \
  --max-tokens 600
```

**Cost Comparison:**
| Task | DeepSeek | Claude | Savings |
|------|----------|--------|---------|
| Simple Function | $0.000084 | $0.0039 | 97.8% |
| REST API | $0.000280 | $0.0135 | 97.9% |
| Full Workflow | $0.001120 | $0.0522 | 97.9% |

**Nancy Relevance:** MEDIUM - Nancy is already multi-driver, but the proxy pattern and cost tracking could be lifted.

---

### 2.3 Self-Learning Knowledge Systems (ReasoningBank)

**Files:** `SELF_LEARNING_GUIDE.md`, `reasoningbank-learning-demo.js`

**Use Case:** Build semantic learning systems that improve over time.

**Key Patterns:**
```javascript
// Store patterns with confidence scoring
const patterns = [
  { key: 'pattern_sql_injection',
    value: 'Never concatenate user input in SQL queries. Use parameterized queries or ORMs.',
    category: 'security' },
  { key: 'pattern_cache_invalidation',
    value: 'Use cache keys with TTL and versioning. Implement cache-aside pattern.',
    category: 'performance' }
];

// Semantic query (finds related concepts)
memory('query', '"how to prevent attacks"', '--namespace self_learning', '--reasoningbank');
// Returns: SQL injection, error logging patterns
```

**Features:**
- Semantic search (no exact keyword match needed)
- Usage tracking (more used = more trusted)
- Confidence scoring (0-100%)
- Cross-domain learning
- Export/import for team sharing

**Nancy Relevance:** HIGH - Could enhance Nancy's session history and knowledge persistence.

---

### 2.4 QUIC Transport for High-Performance Swarms

**Files:** `quic-swarm-coordination.js`, `quic-server-coordinator.js`

**Use Case:** Distributed code review across 1000 files using QUIC protocol.

**Key Benefits:**
- 0-RTT reconnection (instant task distribution)
- Stream multiplexing (100+ concurrent agents)
- Connection migration (survives network changes)
- Built-in TLS 1.3

**Performance Comparison:**
| Metric | QUIC | TCP | Improvement |
|--------|------|-----|-------------|
| 1000 file review | 3-5 min | 15-20 min | 4x faster |
| Connection overhead | 0 RTT | 3 RTT | Instant |
| Concurrent streams | 100+ | Limited | Better scaling |

**Nancy Relevance:** LOW - Over-engineered for Nancy's current scope, but interesting for future scaling.

---

### 2.5 Anti-Hallucination Verification

**Files:** `verification-example.ts`

**Use Case:** Medical AI with confidence scoring and hallucination detection.

**Key Patterns:**
```typescript
// Confidence scoring system
const score = await scorer.calculateConfidence(
  'ACE inhibitors demonstrate mortality benefit in heart failure',
  citations,
  { sampleSize: 5000, confidenceInterval: [0.15, 0.35] }
);

// Hallucination detection
const badInput = {
  claim: 'This treatment always cures cancer permanently with 150% success rate',
  citations: []
};
const result = await pipeline.preOutputVerification(badInput);
// Returns: verified: false, hallucinations: ['overstated_efficacy', 'missing_citations']
```

**Detection Categories:**
- Circular reasoning detection
- Contradiction detection
- Citation validation
- Confidence thresholds (0.95 required)

**Nancy Relevance:** MEDIUM - Could validate agent outputs in orchestration scenarios.

---

### 2.6 Billing and Subscription Systems

**Files:** `billing-example.ts`

**Use Case:** Full billing system for agent usage with quotas.

**Key Patterns:**
```typescript
const billing = createBillingSystem({
  currency: 'USD',
  enableMetering: true,
  enableCoupons: true
});

// Usage tracking
await billing.recordUsage({
  subscriptionId: subscription.id,
  metric: UsageMetric.AgentHours,
  amount: 100,
  unit: 'hours'
});

// Quota enforcement
const quotaOk = await billing.checkQuota(subscription.id, UsageMetric.AgentHours);
```

**Nancy Relevance:** LOW - Not relevant to Nancy's use case.

---

### 2.7 Tool Emulation for Non-Native Models

**Files:** `tool-emulation-demo.ts`, `TOOL-EMULATION-ARCHITECTURE.md`

**Use Case:** Enable tool use for models that don't support native function calling.

**Key Pattern:**
```typescript
// Detect model capabilities
const cap = detectModelCapabilities('mistralai/mistral-7b-instruct');
// Returns: { supportsNativeTools: false, requiresEmulation: true, emulationStrategy: 'react' }

// Build prompt for non-native model
const reactEmulator = new ToolEmulator(tools, 'react');
const prompt = reactEmulator.buildPrompt('What is 15 + 23?');

// Parse response from model
const mockResponse = `Thought: I should use the calculate tool.
Action: calculate
Action Input: {"expression": "15 + 23"}`;
const parsed = reactEmulator.parseResponse(mockResponse);
```

**Strategies:**
- ReAct pattern (Thought-Action-Observation)
- Prompt-based JSON extraction
- Validation and error recovery

**Nancy Relevance:** HIGH - Could enable Nancy to work with more models/drivers.

---

### 2.8 Federated Learning

**Files:** `federated-learning-example.ts`

**Use Case:** Distributed learning across multiple agents with central coordination.

**Key Pattern:**
```typescript
// Create ephemeral agents
const agent = new EphemeralLearningAgent({
  agentId: 'agent-1',
  minQuality: 0.7,
  qualityFiltering: true
});

// Process tasks locally
await agent.processTask(new Float32Array([0.1, 0.2, 0.3]), 0.85);

// Export state for federation
const state = agent.exportState();

// Coordinator aggregates from multiple agents
const coordinator = new FederatedLearningCoordinator({ maxAgents: 50 });
await coordinator.aggregate(state);
const consolidated = await coordinator.consolidate();
```

**Nancy Relevance:** LOW - Advanced ML feature not currently needed.

---

### 2.9 Complete Application: Nova Medicina

**Files:** `nova-medicina/` (entire subdirectory)

**Use Case:** AI-powered medical triage assistant with safety features.

**Architecture:**
```
User Interface Layer (CLI, Web, MCP)
        |
Symptom Analysis Engine (NLP, Context Building)
        |
Multi-Model AI Consensus (GPT-4, Claude, Gemini, Perplexity)
        |
Anti-Hallucination Verification (95%+ threshold)
        |
Provider Approval Workflow
        |
Response Generation with Citations
        |
Continuous Learning (AgentDB)
```

**Key Features:**
- Multi-model consensus (4+ models validate each claim)
- Citation requirements (peer-reviewed sources)
- Confidence scoring (0.95 threshold)
- Provider approval for critical recommendations
- HIPAA compliance
- MCP integration

**Nancy Relevance:** MEDIUM - The multi-layer verification architecture is instructive.

---

### 2.10 Complete Application: Climate Prediction

**Files:** `climate-prediction/` (entire Rust project)

**Use Case:** Modular ML-based climate prediction system.

**Architecture:**
```
CLI + API (Presentation)
        |
Models + Physics (Domain)
        |
Data Sources (Infrastructure)
        |
Core Types & Traits (Foundation)
```

**Crates:**
- `climate-core` - Foundation types and traits
- `climate-data` - External API ingestion
- `climate-models` - ML inference with Candle
- `climate-physics` - Physics constraints
- `climate-api` - REST API (Axum)
- `climate-cli` - Command-line interface

**Nancy Relevance:** LOW - Different domain (Rust, ML), but clean architecture patterns.

---

## 3. Best Examples to Learn From

### Tier 1: Highly Instructive

| Example | Why Learn From It |
|---------|------------------|
| `complex-multi-agent-deployment.ts` | Complete swarm orchestration with memory coordination |
| `SELF_LEARNING_GUIDE.md` | Semantic learning system design |
| `tool-emulation-demo.ts` | Model abstraction and capability detection |
| `multi-agent-demo.js` | Conflict detection and resolution patterns |
| `verification-example.ts` | Output validation and confidence scoring |

### Tier 2: Good Reference

| Example | Why Reference It |
|---------|-----------------|
| `quic-server-coordinator.js` | Server/coordinator architecture |
| `deepseek-agent-demo.sh` | Shell-based agent orchestration |
| `reasoningbank-learning-demo.js` | Knowledge base patterns |
| `federated-learning-example.ts` | Distributed state management |

### Tier 3: Domain-Specific

| Example | Domain |
|---------|--------|
| `nova-medicina/` | Medical AI, safety-critical |
| `climate-prediction/` | Scientific computing, Rust |
| `research-swarm/` | Academic research |
| `billing-example.ts` | SaaS/subscription |

---

## 4. Lift-and-Ship Candidates

### 4.1 Directly Liftable

| Component | Source | Nancy Target | Effort |
|-----------|--------|--------------|--------|
| **Tool Emulation** | `tool-emulation-demo.ts` | `src/cli/drivers/` | Medium |
| **Self-Learning Patterns** | `reasoningbank-learning-demo.js` | `skills/session-history/` | Medium |
| **Multi-Agent Demo Script** | `deepseek-agent-demo.sh` | `scripts/` | Low |
| **Memory Namespacing** | `complex-multi-agent-deployment.ts` | `src/comms/` | Medium |

### 4.2 Adaptable Patterns

| Pattern | Source | Adaptation Needed |
|---------|--------|-------------------|
| Agent Registry | `quic-server-coordinator.js` | Simplify for local use |
| Conflict Detection | `multi-agent-demo.js` | Adapt for file-based comms |
| Confidence Scoring | `verification-example.ts` | Simplify for orchestration |
| Usage Tracking | `billing-example.ts` | Repurpose for token monitoring |

### 4.3 Not Recommended to Lift

| Component | Reason |
|-----------|--------|
| QUIC Transport | Over-engineered for Nancy's local scope |
| Federated Learning | ML-specific, not needed |
| Medical Triage | Domain-specific |
| Climate Prediction | Different language (Rust) |

---

## 5. Code Pattern Analysis

### 5.1 Swarm Initialization Pattern

```typescript
// Pattern: Hierarchical swarm with specialized agents
const swarmInit = await client.messages.create({
  model: 'claude-sonnet-4-20250514',
  messages: [{
    role: 'user',
    content: 'Initialize hierarchical swarm with maxAgents=8 and strategy=specialized'
  }],
  tools: [{
    name: 'mcp__claude-flow__swarm_init',
    input_schema: {
      properties: {
        topology: { enum: ['hierarchical', 'mesh', 'ring', 'star'] },
        maxAgents: { default: 8 },
        strategy: { default: 'specialized' }
      }
    }
  }]
});
```

### 5.2 Memory Coordination Pattern

```typescript
// Pattern: Namespaced memory with TTL
const memoryNamespaces = [
  { namespace: 'swarm-state', key: 'topology', ttl: 3600 },      // 1 hour
  { namespace: 'task-queue', key: 'pending-tasks', ttl: 7200 }, // 2 hours
  { namespace: 'agent-knowledge', key: 'context', ttl: 86400 }  // 24 hours
];
```

### 5.3 Agent Orchestration Pattern

```typescript
// Pattern: Task orchestration with conflict detection
class AgentOrchestrator {
  async executeWithCoordination(agentId, operation, files) {
    // 1. Check for conflicts
    const conflicts = this.coordination.checkConflicts(operation.id, files);

    // 2. Handle conflicts
    if (conflicts.length > 0) {
      for (const conflict of conflicts) {
        await this.handleConflict(agentId, conflict);
      }
    }

    // 3. Execute operation
    await this.wait(operation.duration);

    // 4. Register completion
    this.coordination.registerOperation(agentId, operation.id, files);
  }
}
```

### 5.4 Tool Emulation Pattern

```typescript
// Pattern: ReAct-style tool emulation for non-native models
class ToolEmulator {
  buildPrompt(userQuery) {
    return `You have access to these tools:
${this.tools.map(t => `- ${t.name}: ${t.description}`).join('\n')}

Use this format:
Thought: [your reasoning]
Action: [tool name]
Action Input: [JSON arguments]

Question: ${userQuery}`;
  }

  parseResponse(response) {
    const actionMatch = response.match(/Action:\s*(\w+)/);
    const inputMatch = response.match(/Action Input:\s*({.*})/s);
    return {
      toolCall: {
        name: actionMatch[1],
        arguments: JSON.parse(inputMatch[1])
      }
    };
  }
}
```

### 5.5 Self-Learning Pattern

```javascript
// Pattern: Semantic learning with confidence tracking
const patterns = [
  {
    key: 'pattern_name',
    value: 'Actionable pattern description with reasoning',
    category: 'domain',
    confidence: 0.8,
    usage: 0
  }
];

// Query semantically (not keyword-based)
memory('query', '"related concepts"', '--reasoningbank');

// System tracks usage and increases confidence over time
```

---

## 6. Recommendations for Nancy

### 6.1 High Priority Lifts

1. **Tool Emulation Layer**
   - Source: `tool-emulation-demo.ts`
   - Target: Enable Nancy to work with more LLM drivers
   - Benefit: Broader model support without code changes

2. **Self-Learning Session History**
   - Source: `SELF_LEARNING_GUIDE.md`, `reasoningbank-learning-demo.js`
   - Target: Enhance `skills/session-history/`
   - Benefit: Semantic search across sessions, pattern recognition

3. **Memory Namespacing**
   - Source: `complex-multi-agent-deployment.ts`
   - Target: `src/comms/comms.sh`
   - Benefit: Organized agent state with TTL

### 6.2 Medium Priority Adaptations

4. **Conflict Detection**
   - Source: `multi-agent-demo.js`
   - Target: Orchestrator skill
   - Benefit: Detect when multiple agents modify same files

5. **Output Verification**
   - Source: `verification-example.ts`
   - Target: Orchestrator oversight
   - Benefit: Validate worker outputs before acceptance

### 6.3 Documentation Patterns to Adopt

6. **Example-Driven Documentation**
   - Agentic-flow has excellent README files with code examples
   - Nancy could benefit from similar `examples/` directory

7. **Cost/Savings Communication**
   - DeepSeek examples clearly show cost comparisons
   - Nancy could document time/cost savings from orchestration

---

## 7. Key Insights

### 7.1 Architecture Insights

1. **Layered Modularity**: Every example follows clean separation (core, domain, presentation)
2. **MCP Integration**: Many examples work as MCP servers, enabling Claude Desktop integration
3. **Observability First**: Telemetry, metrics, and logging are built-in, not afterthoughts

### 7.2 Design Philosophy

1. **Semantic Over Keyword**: ReasoningBank uses semantic search, not exact matching
2. **Confidence Scoring**: All outputs have quality metrics (0-100%)
3. **Graceful Degradation**: QUIC examples show auto-fallback patterns
4. **Human-in-the-Loop**: Medical examples require provider approval for low confidence

### 7.3 Operational Insights

1. **Cost Awareness**: Every operation has cost implications documented
2. **TTL Management**: Memory has explicit expiration for cleanup
3. **Agent Specialization**: Different agent types (coder, reviewer, tester, optimizer)

### 7.4 Gaps Nancy Could Fill

1. **Shell-Native Tooling**: Nancy's bash approach could be lighter than TypeScript
2. **Local-First**: Most agentic-flow examples assume cloud; Nancy is local
3. **Simplicity**: Nancy could be the "just works" option vs enterprise complexity

---

## 8. Appendix: File Quick Reference

```
/examples/
  billing-example.ts             # SaaS billing system
  complex-multi-agent-deployment.ts  # Hierarchical swarm
  DEEPSEEK_AGENT_EXAMPLES.md     # Cost-saving model usage
  MULTI-AGENT-DEPLOYMENT.md      # Multi-agent patterns
  nova-medicina/                  # Medical AI application
  quic-server-coordinator.js     # QUIC server
  quic-swarm-coordination.js     # Distributed swarm
  reasoningbank-learning-demo.js # Self-learning demo
  SELF_LEARNING_GUIDE.md         # Learning system guide
  verification-example.ts        # Anti-hallucination

/agentic-flow/examples/
  tool-emulation-demo.ts         # Tool emulation patterns
  TOOL-EMULATION-ARCHITECTURE.md # Emulation design

/packages/agentdb/examples/
  federated-learning-example.ts  # Distributed learning

/packages/agentic-jujutsu/examples/
  multi-agent-demo.js            # Conflict detection
```

---

## 9. Summary

The agentic-flow examples demonstrate a comprehensive ecosystem for multi-agent AI systems. For Nancy, the most valuable patterns are:

1. **Tool Emulation** - Enable broader model support
2. **Self-Learning** - Semantic knowledge persistence
3. **Memory Namespacing** - Organized agent state
4. **Conflict Detection** - Safe multi-agent coordination

The project's documentation-first approach and example-driven development are also worth emulating.
