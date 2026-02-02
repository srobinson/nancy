# Agentic-Flow Deep Dive: State & Persistence

**Date:** 2026-01-22
**Focus Area:** AgentDB Database Schema, State Management, Persistence Mechanisms
**Status:** Comprehensive Analysis

---

## Executive Summary

Agentic-Flow implements a sophisticated state management and persistence layer called **AgentDB**, a purpose-built vector database designed for autonomous AI agents. This system combines SQLite for structured data with HNSW-based vector backends (RuVector or HNSWLib) for semantic search capabilities. The architecture supports episodic memory, skill libraries, reasoning patterns, causal graphs, and reinforcement learning experiences.

**Key Insights:**
- **Hybrid Storage**: SQLite for relational data + Vector backends for embeddings
- **5 Memory Patterns**: Reflexion, Skills, Mixed Memory, Episodic Segmentation, Graph-Aware Recall
- **WAL Mode**: Write-Ahead Logging for crash safety and concurrent reads
- **Multi-Backend**: Auto-detection with graceful fallback (RuVector -> HNSWLib)
- **GNN Learning**: Optional Graph Neural Network for query enhancement

---

## 1. Database Schema and Design

### 1.1 Core Schema Architecture

AgentDB uses two SQL schema files that implement five cutting-edge memory patterns:

**File:** `packages/agentdb/src/schemas/schema.sql`

```
Pattern 1: Reflexion-Style Episodic Replay
Pattern 2: Skill Library from Trajectories
Pattern 3: Structured Mixed Memory (Facts + Summaries)
Pattern 4: Episodic Segmentation and Consolidation
Pattern 5: Graph-Aware Recall (Lightweight GraphRAG)
```

### 1.2 Main Tables

#### Episodes (Reflexion Memory)
```sql
CREATE TABLE IF NOT EXISTS episodes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ts INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
  session_id TEXT NOT NULL,
  task TEXT NOT NULL,
  input TEXT,
  output TEXT,
  critique TEXT,          -- Self-critique for reflexion
  reward REAL DEFAULT 0.0,
  success BOOLEAN DEFAULT 0,
  latency_ms INTEGER,
  tokens_used INTEGER,
  tags TEXT,              -- JSON array
  metadata JSON,
  created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
);
```

**Purpose:** Store agent interactions with self-critique and outcomes. Enables retrieval of similar past failures/successes before new attempts.

#### Skills (Trajectory Extraction)
```sql
CREATE TABLE IF NOT EXISTS skills (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT UNIQUE NOT NULL,
  description TEXT,
  signature JSON NOT NULL,  -- {inputs: {...}, outputs: {...}}
  code TEXT,                -- Tool call manifest or template
  success_rate REAL DEFAULT 0.0,
  uses INTEGER DEFAULT 0,
  avg_reward REAL DEFAULT 0.0,
  avg_latency_ms INTEGER DEFAULT 0,
  created_from_episode INTEGER,
  ...
);
```

**Purpose:** Promote high-reward traces into reusable "skills" with typed I/O.

#### Skill Relationships
```sql
CREATE TABLE IF NOT EXISTS skill_links (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  parent_skill_id INTEGER NOT NULL,
  child_skill_id INTEGER NOT NULL,
  relationship TEXT NOT NULL,  -- 'prerequisite', 'alternative', 'refinement', 'composition'
  weight REAL DEFAULT 1.0,
  ...
);
```

**Purpose:** Graph relationships between skills for composition and planning.

#### Facts (Triple Store)
```sql
CREATE TABLE IF NOT EXISTS facts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  subject TEXT NOT NULL,
  predicate TEXT NOT NULL,
  object TEXT NOT NULL,
  source_type TEXT,  -- 'episode', 'skill', 'external', 'inferred'
  source_id INTEGER,
  confidence REAL DEFAULT 1.0,
  expires_at INTEGER,  -- TTL for temporal facts
  ...
);
```

**Purpose:** Atomic facts as subject-predicate-object triples for knowledge representation.

#### Experience Graph (GraphRAG Overlay)
```sql
CREATE TABLE IF NOT EXISTS exp_nodes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  kind TEXT NOT NULL,  -- 'task', 'skill', 'concept', 'tool', 'outcome'
  label TEXT NOT NULL,
  payload JSON,
  centrality REAL DEFAULT 0.0,
  ...
);

CREATE TABLE IF NOT EXISTS exp_edges (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  src_node_id INTEGER NOT NULL,
  dst_node_id INTEGER NOT NULL,
  relationship TEXT NOT NULL,  -- 'requires', 'produces', 'similar_to', 'refines', 'part_of'
  weight REAL DEFAULT 1.0,
  ...
);
```

**Purpose:** Lightweight GraphRAG for experience-based retrieval.

### 1.3 Frontier Schema (Advanced Features)

**File:** `packages/agentdb/src/schemas/frontier-schema.sql`

#### Causal Memory Graph
```sql
CREATE TABLE IF NOT EXISTS causal_edges (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  from_memory_id INTEGER NOT NULL,
  from_memory_type TEXT NOT NULL,
  to_memory_id INTEGER NOT NULL,
  to_memory_type TEXT NOT NULL,
  similarity REAL NOT NULL DEFAULT 0.0,
  uplift REAL,              -- E[y|do(x)] - E[y] (causal effect)
  confidence REAL DEFAULT 0.5,
  sample_size INTEGER,
  evidence_ids TEXT,        -- JSON array of proof IDs
  confounder_score REAL,
  mechanism TEXT,           -- Hypothesized causal mechanism
  ...
);
```

**Purpose:** Store causal relationships with intervention effects, not just similarity.

#### Explainable Recall Certificates
```sql
CREATE TABLE IF NOT EXISTS recall_certificates (
  id TEXT PRIMARY KEY,
  query_id TEXT NOT NULL,
  query_text TEXT NOT NULL,
  chunk_ids TEXT NOT NULL,       -- JSON array
  minimal_why TEXT,              -- Justification chunks
  redundancy_ratio REAL,
  completeness_score REAL,
  merkle_root TEXT NOT NULL,     -- Provenance chain
  source_hashes TEXT,
  proof_chain TEXT,              -- JSON Merkle proof
  policy_proof TEXT,
  access_level TEXT,
  ...
);
```

**Purpose:** Provenance tracking and justification for RAG retrieval.

#### Reinforcement Learning Experiences
```sql
CREATE TABLE IF NOT EXISTS learning_experiences (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id TEXT NOT NULL,
  state TEXT NOT NULL,
  action TEXT NOT NULL,
  reward REAL NOT NULL,
  next_state TEXT,
  success INTEGER NOT NULL DEFAULT 0,
  timestamp INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
  metadata JSON
);
```

**Purpose:** Store RL trajectories for agent training.

### 1.4 Embedding Storage

Embeddings are stored in paired tables using BLOB format:

```sql
CREATE TABLE IF NOT EXISTS episode_embeddings (
  episode_id INTEGER PRIMARY KEY,
  embedding BLOB NOT NULL,  -- Float32Array as BLOB
  embedding_model TEXT DEFAULT 'all-MiniLM-L6-v2',
  FOREIGN KEY(episode_id) REFERENCES episodes(id) ON DELETE CASCADE
);
```

**Serialization:**
```typescript
private serializeEmbedding(embedding: Float32Array): Buffer {
  return Buffer.from(embedding.buffer);
}

private deserializeEmbedding(buffer: Buffer): Float32Array {
  return new Float32Array(buffer.buffer, buffer.byteOffset, buffer.length / 4);
}
```

---

## 2. State Management Approaches

### 2.1 Controller Architecture

AgentDB uses a controller-based architecture where each memory pattern has a dedicated controller:

```
AgentDB (Main Class)
  |
  +-- ReflexionMemory     # Episodic replay
  +-- SkillLibrary        # Skill management
  +-- ReasoningBank       # Pattern storage
  +-- CausalMemoryGraph   # Causal relationships
  +-- EmbeddingService    # Vector generation
```

**Controller Initialization:**
```typescript
export class AgentDB {
  private db: Database.Database;
  private reflexion!: ReflexionMemory;
  private skills!: SkillLibrary;
  private causalGraph!: CausalMemoryGraph;
  private embedder!: EmbeddingService;
  public vectorBackend!: VectorBackend;

  async initialize(): Promise<void> {
    // Load SQL schemas
    this.db.exec(schema);
    this.db.exec(frontierSchema);

    // Initialize embedder
    this.embedder = new EmbeddingService({
      model: 'Xenova/all-MiniLM-L6-v2',
      dimension: 384,
      provider: 'transformers'
    });

    // Initialize vector backend (auto-detect)
    this.vectorBackend = await createBackend('auto', {
      dimensions: 384,
      metric: 'cosine'
    });

    // Initialize controllers
    this.reflexion = new ReflexionMemory(this.db, this.embedder);
    this.skills = new SkillLibrary(this.db, this.embedder);
    this.causalGraph = new CausalMemoryGraph(this.db);
  }
}
```

### 2.2 Hybrid v1/v2 State Management

Controllers support both legacy (SQLite-only) and modern (VectorBackend) modes:

```typescript
export class ReasoningBank {
  private db: IDatabaseConnection;
  private embedder: EmbeddingService;
  private vectorBackend?: VectorBackend;  // Optional v2 backend

  async storePattern(pattern: ReasoningPattern): Promise<number> {
    // Always store metadata in SQLite
    const result = stmt.run(...);
    const patternId = normalizeRowId(result.lastInsertRowid);

    if (this.vectorBackend) {
      // v2: Use VectorBackend (8x faster search)
      this.vectorBackend.insert(vectorId, embedding, metadata);
    } else {
      // v1: Store in SQLite (backward compatible)
      this.storePatternEmbedding(patternId, embedding);
    }

    return patternId;
  }
}
```

### 2.3 Query Caching (LRU)

```typescript
export class QueryCache {
  private config: { maxSize: 1000, defaultTTL: 300000 };  // 5 minutes
  private cache: Map<string, CacheEntry>;
  private accessOrder: string[];  // LRU tracking

  get<T>(key: string): T | undefined {
    const entry = this.cache.get(key);
    if (!entry) { this.stats.misses++; return undefined; }

    // Check expiration
    if (Date.now() - entry.timestamp > entry.ttl) {
      this.cache.delete(key);
      return undefined;
    }

    this.updateAccessOrder(key);
    this.stats.hits++;
    return entry.value;
  }

  invalidateCategory(category: string): number {
    // Invalidate all keys starting with category
  }
}
```

**Cache Performance:** 20-40% speedup on repeated queries.

### 2.4 ID Mapping Strategy

The system uses string IDs externally but maintains internal mappings:

```typescript
export class ReasoningBank {
  private idMapping: Map<number, string> = new Map();
  private nextVectorId = 0;

  async storePattern(pattern): Promise<number> {
    const patternId = /* SQLite insert */;

    if (this.vectorBackend) {
      const vectorId = `pattern_${this.nextVectorId++}`;
      this.idMapping.set(patternId, vectorId);
      this.vectorBackend.insert(vectorId, embedding, { patternId });
    }

    return patternId;
  }
}
```

---

## 3. Persistence Mechanisms

### 3.1 SQLite Configuration

```typescript
export class AgentDB {
  constructor(config: AgentDBConfig = {}) {
    const dbPath = config.dbPath || ':memory:';
    this.db = new Database(dbPath);
    this.db.pragma('journal_mode = WAL');  // Write-Ahead Logging
  }
}
```

**WAL Mode Benefits:**
- Concurrent readers during writes
- Crash recovery without data loss
- Better write performance
- Checkpoint control

### 3.2 Vector Backend Persistence

**VectorBackend Interface:**
```typescript
export interface VectorBackend {
  save(path: string): Promise<void>;
  load(path: string): Promise<void>;
  close(): void;
}
```

**Usage:**
```typescript
// Save index and metadata
await backend.save('./agentdb/index');

// Load on restart
await backend.load('./agentdb/index');
```

### 3.3 Embedding Persistence Patterns

**Direct BLOB Storage (v1):**
```typescript
private storeEmbedding(episodeId: number, embedding: Float32Array): void {
  const stmt = this.db.prepare(`
    INSERT INTO episode_embeddings (episode_id, embedding)
    VALUES (?, ?)
  `);
  stmt.run(episodeId, Buffer.from(embedding.buffer));
}
```

**Vector Backend Storage (v2):**
```typescript
// Metadata in SQLite, vectors in backend
this.vectorBackend.insert(id.toString(), embedding, {
  type: 'episode',
  sessionId: episode.sessionId,
});
```

### 3.4 Session Persistence

The ReflexionMemory controller maintains session-based data:

```typescript
async getRecentEpisodes(sessionId: string, limit: number = 10): Promise<Episode[]> {
  const stmt = this.db.prepare(`
    SELECT * FROM episodes
    WHERE session_id = ?
    ORDER BY ts DESC
    LIMIT ?
  `);
  return stmt.all(sessionId, limit);
}
```

### 3.5 Database Integrity

**Schema Validation:**
```typescript
it('should verify database schema integrity', () => {
  const tables = db.prepare(`
    SELECT name FROM sqlite_master
    WHERE type='table'
  `).all();

  expect(tableNames).toContain('reasoning_patterns');
  expect(tableNames).toContain('pattern_embeddings');
  expect(tableNames).toContain('skills');
  expect(tableNames).toContain('episodes');
});
```

**Checkpoint Operations:**
```typescript
// Force checkpoint for WAL mode
db.pragma('wal_checkpoint(FULL)');
```

---

## 4. Data Models

### 4.1 Episode Model

```typescript
export interface Episode {
  id?: number;
  ts?: number;
  sessionId: string;
  task: string;
  input?: string;
  output?: string;
  critique?: string;
  reward: number;
  success: boolean;
  latencyMs?: number;
  tokensUsed?: number;
  tags?: string[];
  metadata?: Record<string, any>;
}

export interface EpisodeWithEmbedding extends Episode {
  embedding?: Float32Array;
  similarity?: number;
}
```

### 4.2 Skill Model

```typescript
export interface Skill {
  id?: number;
  name: string;
  description: string;
  signature: { inputs: Record<string, any>; outputs: Record<string, any> };
  code?: string;
  successRate: number;
  uses: number;
  avgReward: number;
  avgLatencyMs: number;
  createdFromEpisode?: number;
  metadata?: Record<string, any>;
}
```

### 4.3 Reasoning Pattern Model

```typescript
export interface ReasoningPattern {
  id?: number;
  taskType: string;
  approach: string;
  successRate: number;
  embedding?: Float32Array;
  uses?: number;
  avgReward?: number;
  tags?: string[];
  metadata?: Record<string, any>;
  createdAt?: number;
  similarity?: number;
}
```

### 4.4 Vector Search Result Model

```typescript
export interface SearchResult {
  id: string;
  distance: number;
  similarity: number;  // Normalized 0-1
  metadata?: Record<string, any>;
}

export interface VectorSearchOptions {
  threshold?: number;
  efSearch?: number;
  filter?: Record<string, any>;
}
```

### 4.5 Learning Sample Model

```typescript
export interface TrainingSample {
  embedding: Float32Array;
  label: number;
  weight?: number;
  context?: Record<string, any>;
}

export interface TrainingResult {
  epochs: number;
  finalLoss: number;
  improvement: number;
  duration: number;
  metrics?: Record<string, number>;
}
```

---

## 5. Backend Abstraction Layer

### 5.1 Auto-Detection System

```typescript
export async function detectBackends(): Promise<BackendDetection> {
  const result: BackendDetection = {
    available: 'none',
    ruvector: { core: false, gnn: false, graph: false, native: false },
    hnswlib: false
  };

  try {
    const ruvector = await import('ruvector');
    result.ruvector.core = true;
    result.ruvector.native = ruvector.isNative?.() ?? false;
    result.available = 'ruvector';
  } catch {
    // Fallback to hnswlib-node
    try {
      await import('hnswlib-node');
      result.hnswlib = true;
      result.available = 'hnswlib';
    } catch {}
  }

  return result;
}
```

### 5.2 Backend Factory

```typescript
export async function createBackend(
  type: BackendType,
  config: VectorConfig
): Promise<VectorBackend> {
  const detection = await detectBackends();

  if (type === 'auto') {
    if (detection.ruvector.core) {
      return new RuVectorBackend(config);
    } else if (detection.hnswlib) {
      return new HNSWLibBackend(config);
    }
  }

  throw new Error('No vector backend available');
}
```

### 5.3 Performance Comparison

| Backend | Platform | 1k Vectors | 10k Vectors | 100k Vectors |
|---------|----------|------------|-------------|--------------|
| RuVector | Native | 0.5ms | 1.2ms | 2.5ms |
| RuVector | WASM | 5ms | 10ms | 20ms |
| HNSWLib | Node.js | 1.2ms | 2.5ms | 5.0ms |

**CLI vs Direct API:**
```
CLI: ~2,350ms per operation
Direct API: ~10-50ms per operation
Speedup: 50-200x faster
```

---

## 6. What Could Be Lifted/Shipped for Nancy

### 6.1 Immediately Adoptable Patterns

#### 1. **WAL Mode SQLite Pattern**
```bash
# Nancy could adopt this for session state
sqlite3 sessions.db "PRAGMA journal_mode = WAL"
```

#### 2. **Episode-Based Session Tracking**
The `episodes` table structure maps well to Nancy's session concept:
```sql
CREATE TABLE IF NOT EXISTS nancy_sessions (
  id INTEGER PRIMARY KEY,
  session_id TEXT NOT NULL,
  task TEXT NOT NULL,
  status TEXT,
  outcome TEXT,
  reward REAL,
  created_at INTEGER DEFAULT (strftime('%s', 'now'))
);
```

#### 3. **BLOB Embedding Storage**
For future semantic search in Nancy:
```bash
# Store embeddings as binary blobs
sqlite3 nancy.db "CREATE TABLE embeddings (id TEXT, embedding BLOB)"
```

#### 4. **LRU Cache Pattern**
```bash
# Implement in bash with file-based caching
declare -A CACHE
cache_get() { echo "${CACHE[$1]:-}"; }
cache_set() { CACHE[$1]="$2"; }
```

### 6.2 Higher-Lift Opportunities

#### 1. **Skill Library Concept**
Nancy could track successful command patterns:
```sql
CREATE TABLE IF NOT EXISTS nancy_skills (
  name TEXT PRIMARY KEY,
  command_pattern TEXT,
  success_rate REAL,
  uses INTEGER DEFAULT 0,
  avg_duration_ms INTEGER
);
```

#### 2. **Causal Edge Tracking**
Track what leads to successful outcomes:
```sql
CREATE TABLE IF NOT EXISTS task_causality (
  from_task TEXT,
  to_task TEXT,
  correlation REAL,
  sample_count INTEGER
);
```

### 6.3 Portable Utilities

**ID Generation:**
```typescript
private generateId(prefix: string): string {
  return `${prefix}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
}
```

**Bash equivalent:**
```bash
generate_id() {
  local prefix="$1"
  echo "${prefix}_$(date +%s)_$(openssl rand -hex 4)"
}
```

---

## 7. Recommendations for Nancy

### 7.1 Short-Term (Phase 1)

1. **Adopt WAL Mode for SQLite**
   - Enable concurrent reads during writes
   - Better crash recovery
   - Add to any SQLite usage in Nancy

2. **Session State Schema**
   - Create `sessions` table mirroring AgentDB episodes
   - Track task, outcome, duration, tokens

3. **File-Based Vector Cache**
   - Cache embeddings to disk for session continuity
   - Use JSON or MessagePack format

### 7.2 Medium-Term (Phase 2)

1. **Skill/Pattern Library**
   - Track successful task completions
   - Build success rates over time
   - Suggest proven approaches

2. **Query Caching**
   - LRU cache for repeated operations
   - File-based persistence
   - TTL-based expiration

3. **Metrics Collection**
   - Latency, token usage, success rates
   - Export to SQLite for analysis

### 7.3 Long-Term (Phase 3)

1. **Vector Search Integration**
   - Consider embedding-based task matching
   - Semantic similarity for skill suggestions
   - Use lightweight backend (sqlite-vec)

2. **Causal Learning**
   - Track what configurations lead to success
   - A/B test different approaches
   - Automatic optimization

---

## 8. Strengths and Weaknesses

### 8.1 Strengths

1. **Comprehensive Memory Architecture**
   - 5 distinct memory patterns for different use cases
   - Episodic, semantic, causal, and graph-based retrieval
   - Well-documented research foundations (Reflexion paper)

2. **Backend Abstraction**
   - Auto-detection with graceful fallback
   - RuVector for performance, HNSWLib for compatibility
   - Clean interface for future backends

3. **Hybrid Storage Strategy**
   - SQLite for metadata and relational queries
   - Vector backends for semantic search
   - Embeddings stored in both for redundancy

4. **Production-Ready Features**
   - WAL mode for crash safety
   - LRU caching for performance
   - Batch operations for throughput
   - Comprehensive indexing

5. **Learning Capabilities**
   - GNN-based query enhancement
   - Self-improving pattern recognition
   - Causal inference support

6. **Backward Compatibility**
   - v1/v2 dual-mode operation
   - Smooth migration path
   - No breaking changes

### 8.2 Weaknesses

1. **Complexity Overhead**
   - Significant TypeScript infrastructure
   - Multiple dependencies (better-sqlite3, transformers)
   - Overkill for simple use cases

2. **CLI Performance**
   - 2.3s overhead per CLI operation
   - Transformers.js initialization cost
   - Requires process pooling for speed

3. **Memory Footprint**
   - HNSW indices consume significant RAM
   - 384-dim embeddings = ~1.5KB per vector
   - Not suitable for constrained environments

4. **Optional Feature Discovery**
   - GNN requires separate @ruvector/gnn package
   - Graph requires @ruvector/graph-node
   - Feature availability varies by environment

5. **Persistence Coupling**
   - Vector indices separate from SQLite
   - Two paths for save/load
   - Potential consistency issues

6. **Testing Complexity**
   - Multiple backends to test
   - Mock embeddings for unit tests
   - Integration tests require full stack

---

## 9. Key Code Patterns

### 9.1 Prepared Statement Pattern
```typescript
// Prepare ONCE, execute MANY (better-sqlite3 best practice)
const stmt = this.db.prepare(`
  SELECT * FROM reasoning_patterns WHERE id = ?
`);

// Execute for each result
return results.map(result => stmt.get(result.metadata?.patternId));
```

### 9.2 Cosine Similarity
```typescript
private cosineSimilarity(a: Float32Array, b: Float32Array): number {
  let dotProduct = 0, normA = 0, normB = 0;
  for (let i = 0; i < a.length; i++) {
    dotProduct += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  return dotProduct / (Math.sqrt(normA) * Math.sqrt(normB));
}
```

### 9.3 Row ID Normalization
```typescript
function normalizeRowId(rowid: number | bigint): number {
  return typeof rowid === 'bigint' ? Number(rowid) : rowid;
}
```

### 9.4 Automatic Triggers
```sql
CREATE TRIGGER IF NOT EXISTS update_skill_last_used
AFTER UPDATE OF uses ON skills
BEGIN
  UPDATE skills SET last_used_at = strftime('%s', 'now') WHERE id = NEW.id;
END;
```

---

## 10. Summary

AgentDB represents a sophisticated approach to agent memory and state management, combining:

- **SQLite** for structured, relational data
- **HNSW vectors** for semantic similarity search
- **Controllers** for domain-specific operations
- **Caching** for performance optimization
- **GNN** for adaptive query enhancement

For Nancy, the most valuable concepts to adopt are:
1. WAL-mode SQLite for safe concurrent access
2. Episode-based session tracking
3. LRU caching patterns
4. Skill/pattern success tracking
5. BLOB-based embedding storage (future)

The architecture provides a solid foundation for building persistent, learning-capable agent systems while maintaining backward compatibility and operational flexibility.

---

**References:**
- AgentDB Source: `/Users/alphab/Dev/LLM/DEV/agentic-flow/packages/agentdb/`
- Schema Files: `src/schemas/schema.sql`, `src/schemas/frontier-schema.sql`
- Controllers: `src/controllers/ReasoningBank.ts`, `src/controllers/ReflexionMemory.ts`
- Backend Abstraction: `src/backends/VectorBackend.ts`, `src/backends/factory.ts`
- Reflexion Paper: https://arxiv.org/abs/2303.11366
