# Knowledge Graph Harness: Technical Architecture & Schema Design

**Project**: mdcontext Validation on Agentic-Flow Documentation
**Target**: 2066 Markdown Files
**Mission**: Build production-grade knowledge graph infrastructure to validate mdcontext's ability to extract, relate, and query complex documentation relationships
**Date**: 2026-01-26
**Status**: Implementation-Ready Specification

---

## Executive Summary

This document provides a **complete technical architecture** for building a Knowledge Graph harness to validate mdcontext on 2066 markdown files from the agentic-flow project. Every decision is justified with trade-offs, performance benchmarks, and specific implementation code snippets.

**Key Decisions**:
- **Database**: Neo4j Community Edition (server mode) + TypeScript Graphology (in-memory cache)
- **Language**: TypeScript (Node.js 20+)
- **Storage**: Neo4j server (persistent) + HNSW vectors in mdcontext's existing VectorStore
- **Target**: Build and query 2K+ document graph in <30 seconds, query latency <100ms

This is **executable** - you can start coding from this spec immediately.

---

## 1. Technology Stack Decision

### 1.1 Graph Database Choice

#### **Decision: Hybrid Architecture**

```
Neo4j Community Edition (Server)  ← Primary persistent storage
         ↕
TypeScript Graphology (In-Memory)  ← Fast query cache + analysis
         ↕
mdcontext VectorStore (HNSW)       ← Existing embeddings
```

#### **Why This Hybrid?**

| Requirement | Neo4j Server | Graphology | Combined |
|-------------|-------------|------------|----------|
| Persistence | ✅ Native | ❌ Memory-only | ✅ Best of both |
| Query Speed (Cypher) | ✅ Fast (10-50ms) | N/A | ✅ |
| Graph Analytics | ⚠️ Limited algorithms | ✅ Rich algorithms | ✅ Best of both |
| Scalability | ✅ 100M+ nodes | ⚠️ Memory-bound (~10M) | ✅ Neo4j for scale |
| TypeScript Integration | ⚠️ Via driver | ✅ Native | ✅ |
| Visualization | ✅ Neo4j Browser | ✅ vis.js/D3 | ✅ Both options |
| Cost | Free (Community) | Free | Free |

**Why NOT Pure Neo4j?**
- Neo4j's graph algorithms (PageRank, community detection) require separate Graph Data Science library
- Cypher queries are powerful but verbose for simple operations
- TypeScript integration is via driver, not native

**Why NOT Pure Graphology?**
- No persistence - requires manual save/load
- Memory-bound (2066 docs with rich metadata ≈ 500MB-1GB in memory)
- No native query language (must write imperative code)

**Why NOT NetworkX (Python)?**
- mdcontext is TypeScript-native
- Embedding/indexing logic already in TypeScript
- Would require Python interop (complexity)

**Why NOT TinkerPop/Gremlin?**
- TinkerPop is a framework, not a database
- Gremlin learning curve steeper than Cypher
- Less TypeScript ecosystem support

#### **Performance Benchmarks**

| Operation | Neo4j Server | Graphology | NetworkX |
|-----------|--------------|------------|----------|
| Insert 10K nodes | 2-5s | <1s | 3-8s |
| BFS traversal (1K depth) | 10-50ms | 5-15ms | 100-500ms |
| PageRank (10K nodes) | 500ms (GDS) | 200ms (native) | 15,000ms |
| Multi-hop query (3 hops) | 20-80ms | 10-30ms | 500-2000ms |
| Concurrent queries (10 clients) | ✅ Excellent | ❌ Single-threaded | ❌ GIL-limited |

**Sources**:
- [Neo4j Performance Comparison](https://www.mdpi.com/2076-3417/12/13/6490)
- [Neo4j vs NetworkX Drag Race](https://towardsdatascience.com/fire-up-your-centrality-metric-engines-neo4j-vs-networkx-a-drag-race-of-sorts-18857f25be35/)
- [Graphology Performance Comparison](https://npm-compare.com/cytoscape,graphlib,graphology,vis-network)

---

### 1.2 Programming Language

#### **Decision: TypeScript (Node.js 20+)**

**Why TypeScript?**
1. **mdcontext is TypeScript-native** - 100% of existing indexing/embedding code is TS
2. **Type safety** - Graph schemas benefit from compile-time validation
3. **Ecosystem** - Neo4j driver, Graphology, HNSW libraries all have excellent TS support
4. **Performance** - V8 engine handles 2K nodes efficiently (faster than Python for I/O-bound workloads)

**Why NOT Python?**
- Would require rewriting mdcontext indexing logic
- NetworkX is Python's strength, but we chose Neo4j/Graphology
- Additional complexity with cross-language orchestration

**Why NOT Rust?**
- Overkill for 2K nodes (Rust shines at 100M+ scale)
- mdcontext doesn't have Rust bindings
- Development speed critical for validation project

---

### 1.3 Storage Backend

#### **Decision: Multi-Tier Storage**

```typescript
// Tier 1: Neo4j Server (Persistent Graph)
const neo4jUri = 'bolt://localhost:7687';
const driver = neo4j.driver(neo4jUri, neo4j.auth.basic('neo4j', 'password'));

// Tier 2: Graphology In-Memory (Fast Analytics)
const graph = new Graph({ multi: false, type: 'directed' });

// Tier 3: mdcontext VectorStore (Embeddings)
const vectorStore = await VectorStore.load(indexPath);
```

**Storage Breakdown**:

| Data Type | Storage | Size (2066 docs) | Rationale |
|-----------|---------|-----------------|-----------|
| Graph structure (nodes/edges) | Neo4j | ~50MB | Persistent, queryable |
| Graph cache (hot queries) | Graphology | ~200MB | In-memory speed |
| Vector embeddings (384-dim) | mdcontext HNSW | ~300MB | Already exists |
| Metadata (document content) | Neo4j properties | ~100MB | Co-located with graph |
| Link analysis cache | Graphology | ~50MB | Fast PageRank |

**Total Storage**: ~700MB (well within Neo4j Community 32GB limit)

**Why NOT Embedded Neo4j?**
- Neo4j dropped embedded mode in v4.0+
- Server mode allows Neo4j Browser visualization
- Server mode better for concurrent access

**Why NOT In-Memory Only (Graphology)?**
- No persistence - must rebuild on restart (30s cost per boot)
- Risk of data loss during development
- Can't visualize in Neo4j Browser

**Why NOT External Vector DB (Qdrant/Pinecone)?**
- mdcontext already has HNSW vectors
- No need to duplicate embeddings
- [Hybrid architectures](https://memgraph.com/blog/why-hybridrag) work, but add complexity

---

## 2. Graph Schema Design

### 2.1 Node Types

```cypher
// Document Node
CREATE (d:Document {
  id: "docs/api/authentication.md",
  filePath: "/path/to/docs/api/authentication.md",
  title: "Authentication API",
  tokens: 2340,
  lastModified: datetime("2026-01-15T10:30:00"),
  pageRank: 0.0,           // Computed post-construction
  topicClusterId: null,    // Computed during clustering
  embeddingId: "doc_123"   // Reference to HNSW vector
})

// Section Node
CREATE (s:Section {
  id: "docs/api/authentication.md#oauth-2.0",
  heading: "OAuth 2.0",
  level: 2,                // H2
  tokens: 450,
  docId: "docs/api/authentication.md",
  embeddingId: "sec_456"
})

// Concept Node
CREATE (c:Concept {
  id: "concept:authentication",
  name: "authentication",
  type: "feature",         // feature|config|api|pattern|error
  firstMention: "docs/intro.md#security",
  frequency: 47,           // Total mentions across docs
  idf: 3.2                 // Inverse document frequency
})

// TopicCluster Node
CREATE (tc:TopicCluster {
  id: "cluster_3",
  label: "API & Networking",
  coherenceScore: 0.72,    // Silhouette score
  memberCount: 142,
  centroidEmbedding: null  // Could store, but large
})

// Keyword Node (for BM25-style queries)
CREATE (k:Keyword {
  id: "keyword:webhook",
  term: "webhook",
  stemmed: "webhook",      // After Porter stemming
  idf: 4.1,
  documentFrequency: 23
})
```

**Node Type Justification**:

| Node Type | Count (est.) | Why Needed? |
|-----------|--------------|-------------|
| Document | 2,066 | One per markdown file |
| Section | ~15,000 | Avg 7 sections per doc (H1-H6) |
| Concept | ~500 | Domain concepts (auth, rate-limiting, etc.) |
| TopicCluster | ~20 | Semantic communities (k=20 for 2K docs) |
| Keyword | ~1,000 | High-IDF terms for text search |

**Total Nodes**: ~18,586

---

### 2.2 Edge Types

```cypher
// LINKS_TO (Document → Document)
CREATE (d1:Document)-[:LINKS_TO {
  linkType: "explicit",    // explicit|implicit
  context: "See [Authentication](auth.md) for details",
  weight: 1.0              // 1.0 for explicit, 0.3-0.8 for semantic
}]->(d2:Document)

// CONTAINS (Document → Section)
CREATE (d:Document)-[:CONTAINS {
  order: 3,                // 3rd section in document
  depth: 2,                // Nested depth (H2 = depth 2)
  weight: 0.8              // Higher weight for top-level sections
}]->(s:Section)

// MENTIONS (Section → Concept)
CREATE (s:Section)-[:MENTIONS {
  count: 5,                // 5 mentions in section
  positions: [45, 120, 234, 567, 890],
  tfIdf: 0.42,            // TF-IDF score
  sentimentContext: "positive"  // Optional: positive|neutral|negative
}]->(c:Concept)

// RELATED_TO (Concept → Concept)
CREATE (c1:Concept)-[:RELATED_TO {
  cooccurrenceCount: 23,
  semanticSimilarity: 0.68,
  relationshipType: "depends-on",  // depends-on|configures|implements|extends
  weight: 0.68
}]->(c2:Concept)

// BELONGS_TO (Document → TopicCluster)
CREATE (d:Document)-[:BELONGS_TO {
  membershipStrength: 0.85,  // Cosine similarity to centroid
  rank: 12                   // 12th most central in cluster
}]->(tc:TopicCluster)

// SIMILAR_TO (Document → Document)
CREATE (d1:Document)-[:SIMILAR_TO {
  cosineSimilarity: 0.72,
  sharedConcepts: ["auth", "jwt", "session"],
  sharedKeywords: ["token", "verify", "expire"],
  weight: 0.72
}]->(d2:Document)
```

**Edge Type Justification**:

| Edge Type | Count (est.) | Computation Cost | Why Needed? |
|-----------|--------------|------------------|-------------|
| LINKS_TO | ~5,000 | Low (parse markdown) | Navigation, graph structure |
| CONTAINS | ~15,000 | Low (document structure) | Section-level queries |
| MENTIONS | ~50,000 | Medium (NER + TF-IDF) | Concept discovery |
| RELATED_TO | ~2,000 | High (co-occurrence analysis) | Concept relationships |
| BELONGS_TO | ~2,066 | High (clustering) | Topic organization |
| SIMILAR_TO | ~10,000 | High (vector similarity) | Semantic navigation |

**Total Edges**: ~84,066

---

### 2.3 Property Design Rationale

**Why `embeddingId` instead of storing vectors in Neo4j?**
- Neo4j vector indexes are available but optimize for native ANN search
- mdcontext already has optimized HNSW index
- [Hybrid architecture](https://memgraph.com/blog/why-hybridrag) keeps vectors separate, graph structure in Neo4j
- Reference by ID avoids duplication

**Why `pageRank` as node property?**
- Computed once during graph enrichment phase
- Stored for fast filtering ("top 50 important docs")
- Alternative: Compute on-demand (slower, but always fresh)

**Why `relationshipType` on RELATED_TO edges?**
- Enables typed queries: "Find all concepts that DEPEND_ON authentication"
- Could be separate edge types (DEPENDS_ON, CONFIGURES), but increases schema complexity
- String property more flexible for validation project

---

## 3. Data Model

### 3.1 mdcontext Index → Graph Mapping

mdcontext produces these indexes (in `.mdcontext/indexes/`):

```
documents.json      # { id, filePath, title, tokens, lastModified }
sections.json       # { id, heading, level, docId, tokens }
links.json          # { source, target, text }
vectors.bin         # HNSW index (binary format)
```

**Mapping Strategy**:

```typescript
// documents.json → Document nodes
const documents = await loadDocuments(indexPath);
for (const doc of documents) {
  await session.run(`
    CREATE (d:Document {
      id: $id,
      filePath: $filePath,
      title: $title,
      tokens: $tokens,
      lastModified: datetime($lastModified),
      embeddingId: $embeddingId
    })
  `, doc);
}

// sections.json → Section nodes + CONTAINS edges
const sections = await loadSections(indexPath);
for (const section of sections) {
  await session.run(`
    MATCH (d:Document {id: $docId})
    CREATE (s:Section {
      id: $id,
      heading: $heading,
      level: $level,
      tokens: $tokens,
      embeddingId: $embeddingId
    })
    CREATE (d)-[:CONTAINS {order: $order, depth: $level}]->(s)
  `, section);
}

// links.json → LINKS_TO edges
const links = await loadLinks(indexPath);
for (const link of links) {
  await session.run(`
    MATCH (source:Document {id: $sourceId})
    MATCH (target:Document {id: $targetId})
    CREATE (source)-[:LINKS_TO {
      linkType: 'explicit',
      context: $text,
      weight: 1.0
    }]->(target)
  `, link);
}

// vectors.bin → Semantic edges (SIMILAR_TO)
const vectorStore = await VectorStore.load(indexPath);
for (const doc of documents) {
  const neighbors = await vectorStore.search(doc.embeddingId, {
    k: 10,
    threshold: 0.65
  });

  for (const neighbor of neighbors) {
    await session.run(`
      MATCH (d1:Document {id: $docId})
      MATCH (d2:Document {id: $neighborId})
      CREATE (d1)-[:SIMILAR_TO {
        cosineSimilarity: $similarity,
        weight: $similarity
      }]->(d2)
    `, {
      docId: doc.id,
      neighborId: neighbor.id,
      similarity: neighbor.score
    });
  }
}
```

**Performance Optimization**:
- Use Neo4j batch imports (CSV bulk load) for initial graph
- Use Cypher `UNWIND` for batch edge creation (100x faster than individual `CREATE`)
- Example:

```typescript
// Batch edge creation (FAST)
await session.run(`
  UNWIND $edges AS edge
  MATCH (source:Document {id: edge.sourceId})
  MATCH (target:Document {id: edge.targetId})
  CREATE (source)-[:LINKS_TO {
    linkType: edge.linkType,
    context: edge.context,
    weight: edge.weight
  }]->(target)
`, { edges: linkBatch });
```

---

### 3.2 Embedding Storage Strategy

**Decision: Keep Embeddings in mdcontext VectorStore**

```typescript
// DON'T store embeddings in Neo4j properties
// ❌ BAD: Bloats graph, slow queries
CREATE (d:Document {
  embedding: [0.23, -0.45, 0.12, ...]  // 384 floats = 1.5KB per doc
})

// ✅ GOOD: Reference by ID, query mdcontext VectorStore
CREATE (d:Document {
  embeddingId: "doc_abc123"  // 16 bytes
})

// Then, for semantic search:
const results = await vectorStore.search(queryEmbedding, { k: 20 });
const docIds = results.map(r => r.id);

// Hydrate graph data
const graphData = await session.run(`
  MATCH (d:Document)
  WHERE d.id IN $docIds
  RETURN d
`, { docIds });
```

**Why Not Neo4j Vector Indexes?**
- Neo4j [vector indexes](https://neo4j.com/docs/genai/plugin/5/embeddings/) are excellent for native ANN search
- BUT mdcontext already has optimized HNSW (fast, battle-tested)
- Duplication adds complexity
- [Hybrid architecture](https://qdrant.tech/documentation/examples/graphrag-qdrant-neo4j/) is proven pattern (Qdrant + Neo4j)

**Embedding Workflow**:

```
Query: "authentication timeout handling"
   ↓
1. mdcontext.search(query) → Returns doc IDs + scores
   ↓
2. Neo4j: MATCH (d:Document) WHERE d.id IN [...]
   ↓
3. Neo4j: Expand graph (LINKS_TO, MENTIONS, etc.)
   ↓
4. Return enriched results (docs + relationships)
```

---

### 3.3 Versioning Strategy

**For Validation Project**: Single snapshot (no versioning)

**For Production Integration**: Git-based versioning

```cypher
// Version Node
CREATE (v:Version {
  id: "v1.0.0",
  commitSha: "a1b2c3d",
  timestamp: datetime("2026-01-15T10:00:00"),
  message: "Initial release"
})

// Document nodes linked to versions
CREATE (d:Document)-[:IN_VERSION]->(v:Version)

// Query specific version
MATCH (d:Document)-[:IN_VERSION]->(v:Version {id: "v1.0.0"})
RETURN d
```

**Why Skip Versioning for Validation?**
- 2066 files × 10 versions = 20K+ document nodes (complexity)
- Validation focuses on single snapshot quality
- Can be added later if needed

---

## 4. Scalability Architecture

### 4.1 Expected Graph Size

| Metric | Calculation | Result |
|--------|-------------|--------|
| **Nodes** | 2,066 docs + 15K sections + 500 concepts + 20 clusters + 1K keywords | **~18,586 nodes** |
| **Edges** | 5K links + 15K contains + 50K mentions + 2K related + 2K belongs + 10K similar | **~84,066 edges** |
| **Storage** | Nodes (50MB) + Edges (100MB) + Properties (200MB) | **~350MB** |
| **Memory (Neo4j)** | Graph cache + query cache | **~500MB** |
| **Memory (Graphology)** | In-memory graph copy | **~200MB** |

**Total Memory**: ~700MB (well within 8GB laptop limits)

---

### 4.2 Performance Targets

| Operation | Target Latency | Rationale |
|-----------|----------------|-----------|
| **Build Graph** | <30 seconds | One-time cost, acceptable |
| **Single-hop Query** | <50ms | Interactive UX threshold |
| **Multi-hop Query (3 hops)** | <100ms | Complex traversals |
| **PageRank Computation** | <5 seconds | One-time per enrichment |
| **Clustering** | <10 seconds | One-time per enrichment |
| **Semantic Search** | <100ms | mdcontext already optimized |

**Benchmarking Plan**:

```typescript
// Benchmark template
import { performance } from 'perf_hooks';

async function benchmark(name: string, fn: () => Promise<void>) {
  const start = performance.now();
  await fn();
  const duration = performance.now() - start;
  console.log(`${name}: ${duration.toFixed(2)}ms`);

  if (duration > thresholds[name]) {
    throw new Error(`Performance regression: ${name} exceeded ${thresholds[name]}ms`);
  }
}

// Usage
await benchmark('build-graph', async () => {
  await buildGraph(documents, sections, links);
});
```

---

### 4.3 Incremental Build Strategy

**Problem**: Rebuilding 18K nodes + 84K edges on every index change is wasteful.

**Solution**: Change-based incremental updates

```typescript
// Detect changed files
const lastBuild = await getLastBuildTimestamp();
const changedDocs = documents.filter(d => d.lastModified > lastBuild);

// Incremental update
for (const doc of changedDocs) {
  // 1. Delete old document + edges
  await session.run(`
    MATCH (d:Document {id: $id})
    DETACH DELETE d
  `, { id: doc.id });

  // 2. Re-create document + edges
  await createDocumentNode(doc);
  await createDocumentEdges(doc);
}

// 3. Re-run clustering (if >10% docs changed)
if (changedDocs.length / documents.length > 0.1) {
  await runClustering();
  await runPageRank();
}
```

**Why DETACH DELETE?**
- `DETACH DELETE` removes node + all connected edges
- Ensures no orphaned edges

**Incremental Performance**:
- 1% docs changed (20 docs): ~1 second
- 10% docs changed (200 docs): ~5 seconds
- 100% docs changed: ~30 seconds (full rebuild)

---

### 4.4 Query Optimization

**Index Creation** (Critical for <100ms queries):

```cypher
// Create indexes on frequently queried properties
CREATE INDEX doc_id FOR (d:Document) ON (d.id);
CREATE INDEX doc_pagerank FOR (d:Document) ON (d.pageRank);
CREATE INDEX section_docid FOR (s:Section) ON (s.docId);
CREATE INDEX concept_name FOR (c:Concept) ON (c.name);
CREATE INDEX concept_type FOR (c:Concept) ON (c.type);

// Composite index for filtered queries
CREATE INDEX doc_cluster_rank FOR (d:Document) ON (d.topicClusterId, d.pageRank);
```

**Query Pattern Optimization**:

```cypher
// ❌ SLOW: Cartesian product
MATCH (d:Document), (c:Concept {name: "authentication"})
MATCH (d)-[:MENTIONS]->(c)
RETURN d

// ✅ FAST: Start from indexed concept
MATCH (c:Concept {name: "authentication"})
MATCH (d:Document)-[:MENTIONS]->(c)
RETURN d
```

**Caching Strategy**:

```typescript
// Hot queries cached in Graphology
class GraphQueryCache {
  private cache = new Map<string, any>();

  async getDocumentNeighbors(docId: string): Promise<Document[]> {
    const cacheKey = `neighbors:${docId}`;

    if (this.cache.has(cacheKey)) {
      return this.cache.get(cacheKey);
    }

    // Cold query to Neo4j
    const result = await session.run(`
      MATCH (d:Document {id: $docId})-[:LINKS_TO|SIMILAR_TO]->(neighbor)
      RETURN neighbor
    `, { docId });

    this.cache.set(cacheKey, result);
    return result;
  }
}
```

---

## 5. Code Structure

### 5.1 Directory Layout

```
knowledge-graph/
├── src/
│   ├── graph/
│   │   ├── neo4j-client.ts          # Neo4j connection & queries
│   │   ├── graphology-cache.ts      # In-memory Graphology graph
│   │   ├── schema.ts                # Node/edge type definitions
│   │   └── indexes.ts               # Index creation scripts
│   ├── builders/
│   │   ├── document-builder.ts      # Document → Graph
│   │   ├── section-builder.ts       # Section → Graph
│   │   ├── concept-extractor.ts     # Concept extraction (NER + TF-IDF)
│   │   ├── link-builder.ts          # LINKS_TO edges
│   │   ├── semantic-builder.ts      # SIMILAR_TO edges (via mdcontext)
│   │   └── cluster-builder.ts       # TopicCluster creation
│   ├── enrichment/
│   │   ├── pagerank.ts              # PageRank computation (Graphology)
│   │   ├── clustering.ts            # Community detection (Louvain)
│   │   ├── centrality.ts            # Betweenness/closeness centrality
│   │   └── hierarchy.ts             # Concept hierarchy builder
│   ├── query/
│   │   ├── cypher-templates.ts      # Reusable Cypher queries
│   │   ├── graph-queries.ts         # High-level query API
│   │   └── hybrid-search.ts         # Combine Neo4j + mdcontext
│   ├── validation/
│   │   ├── ground-truth.ts          # Manual validation data
│   │   ├── metrics.ts               # Precision/recall/F1 calculation
│   │   └── test-cases.ts            # 10 test case implementations
│   ├── visualization/
│   │   ├── neo4j-export.ts          # Export for Neo4j Browser
│   │   ├── graphology-viz.ts        # D3.js/vis.js exports
│   │   └── subgraph-extractor.ts    # Extract query result subgraphs
│   └── cli/
│       ├── build.ts                 # CLI: Build graph from mdcontext index
│       ├── query.ts                 # CLI: Interactive query interface
│       ├── validate.ts              # CLI: Run validation suite
│       └── stats.ts                 # CLI: Graph statistics
├── tests/
│   ├── unit/
│   │   ├── concept-extractor.test.ts
│   │   ├── pagerank.test.ts
│   │   └── clustering.test.ts
│   ├── integration/
│   │   ├── graph-build.test.ts
│   │   └── query-performance.test.ts
│   └── validation/
│       └── test-cases.test.ts       # 10 validation test cases
├── scripts/
│   ├── neo4j-setup.sh               # Install & configure Neo4j
│   ├── import-csv.ts                # Bulk CSV import (fast initial build)
│   └── benchmark.ts                 # Performance benchmarking
├── config/
│   ├── neo4j.config.ts              # Neo4j connection settings
│   ├── graph-schema.json            # Schema documentation (JSON)
│   └── thresholds.ts                # Similarity thresholds, hyperparams
├── data/
│   ├── ground-truth/                # Manual validation labels
│   │   ├── concepts.json
│   │   └── relationships.json
│   └── exports/                     # Graph exports (CSV, GraphML)
│       ├── graph.graphml
│       └── nodes.csv
├── package.json
├── tsconfig.json
└── README.md
```

---

### 5.2 Module Organization

#### **graph/neo4j-client.ts**

```typescript
import neo4j, { Driver, Session } from 'neo4j-driver';

export class Neo4jClient {
  private driver: Driver;

  constructor(uri: string, user: string, password: string) {
    this.driver = neo4j.driver(uri, neo4j.auth.basic(user, password));
  }

  async session(): Promise<Session> {
    return this.driver.session({ database: 'neo4j' });
  }

  async createDocumentNode(doc: Document): Promise<void> {
    const session = await this.session();
    try {
      await session.run(`
        CREATE (d:Document {
          id: $id,
          filePath: $filePath,
          title: $title,
          tokens: $tokens,
          lastModified: datetime($lastModified),
          embeddingId: $embeddingId
        })
      `, doc);
    } finally {
      await session.close();
    }
  }

  async batchCreateEdges(edges: Edge[]): Promise<void> {
    const session = await this.session();
    try {
      await session.run(`
        UNWIND $edges AS edge
        MATCH (source {id: edge.sourceId})
        MATCH (target {id: edge.targetId})
        CREATE (source)-[:${edge.type} $properties]->(target)
      `, { edges });
    } finally {
      await session.close();
    }
  }

  async close(): Promise<void> {
    await this.driver.close();
  }
}
```

#### **graph/graphology-cache.ts**

```typescript
import Graph from 'graphology';
import pagerank from 'graphology-metrics/centrality/pagerank';
import louvain from 'graphology-communities-louvain';

export class GraphologyCache {
  private graph: Graph;

  constructor() {
    this.graph = new Graph({ multi: false, type: 'directed' });
  }

  // Sync from Neo4j
  async syncFromNeo4j(neo4j: Neo4jClient): Promise<void> {
    const session = await neo4j.session();

    // Load nodes
    const nodes = await session.run('MATCH (n) RETURN n');
    for (const record of nodes.records) {
      const node = record.get('n');
      this.graph.addNode(node.properties.id, node.properties);
    }

    // Load edges
    const edges = await session.run('MATCH (a)-[r]->(b) RETURN a.id, type(r), b.id, properties(r)');
    for (const record of edges.records) {
      this.graph.addEdge(
        record.get('a.id'),
        record.get('b.id'),
        record.get('properties(r)')
      );
    }

    await session.close();
  }

  // Compute PageRank (fast in-memory)
  computePageRank(): Map<string, number> {
    const ranks = pagerank(this.graph);
    return new Map(Object.entries(ranks));
  }

  // Detect communities (Louvain)
  detectCommunities(): Map<string, number> {
    const communities = louvain(this.graph);
    return new Map(Object.entries(communities));
  }
}
```

#### **builders/concept-extractor.ts**

```typescript
import { Document, Concept } from '../types';
import { calculateTfIdf } from '../utils/tfidf';

export class ConceptExtractor {
  private stopwords = new Set(['the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at']);

  async extractConcepts(documents: Document[]): Promise<Concept[]> {
    const conceptMap = new Map<string, Concept>();

    for (const doc of documents) {
      const content = await readFile(doc.filePath, 'utf-8');
      const tokens = this.tokenize(content);

      // Pattern-based extraction
      const configVars = this.extractConfigVars(content);
      const apiEndpoints = this.extractApiEndpoints(content);
      const errorCodes = this.extractErrorCodes(content);

      // TF-IDF high-scoring terms
      const tfIdfTerms = calculateTfIdf(tokens, documents);

      // Merge and deduplicate
      for (const term of [...configVars, ...apiEndpoints, ...errorCodes, ...tfIdfTerms]) {
        if (!conceptMap.has(term.name)) {
          conceptMap.set(term.name, {
            id: `concept:${term.name}`,
            name: term.name,
            type: term.type,
            frequency: 0,
            idf: term.idf
          });
        }
        conceptMap.get(term.name)!.frequency++;
      }
    }

    return Array.from(conceptMap.values());
  }

  private extractConfigVars(content: string): Array<{name: string, type: 'config'}> {
    // Pattern: ALL_CAPS_SNAKE_CASE or camelCase with "config" nearby
    const pattern = /\b([A-Z_]{3,}|[a-z]+Config[A-Za-z]*)\b/g;
    const matches = content.match(pattern) || [];
    return matches.map(name => ({ name, type: 'config' as const }));
  }

  private extractApiEndpoints(content: string): Array<{name: string, type: 'api'}> {
    // Pattern: /api/v1/resource or GET /resource
    const pattern = /(?:GET|POST|PUT|DELETE)\s+(\/[\w\/-]+)/g;
    const matches = content.match(pattern) || [];
    return matches.map(name => ({ name, type: 'api' as const }));
  }

  private extractErrorCodes(content: string): Array<{name: string, type: 'error'}> {
    // Pattern: ERROR_CODE or HttpException
    const pattern = /\b([A-Z_]+ERROR|[A-Z][a-z]+Exception)\b/g;
    const matches = content.match(pattern) || [];
    return matches.map(name => ({ name, type: 'error' as const }));
  }

  private tokenize(content: string): string[] {
    return content
      .toLowerCase()
      .replace(/[^\w\s]/g, ' ')
      .split(/\s+/)
      .filter(t => t.length > 2 && !this.stopwords.has(t));
  }
}
```

---

### 5.3 Key Classes & Interfaces

```typescript
// types/graph.ts
export interface Document {
  id: string;
  filePath: string;
  title: string;
  tokens: number;
  lastModified: Date;
  embeddingId: string;
  pageRank?: number;
  topicClusterId?: string;
}

export interface Section {
  id: string;
  heading: string;
  level: number;
  tokens: number;
  docId: string;
  embeddingId: string;
}

export interface Concept {
  id: string;
  name: string;
  type: 'feature' | 'config' | 'api' | 'pattern' | 'error';
  frequency: number;
  idf: number;
  firstMention?: string;
}

export interface Edge {
  type: 'LINKS_TO' | 'CONTAINS' | 'MENTIONS' | 'RELATED_TO' | 'BELONGS_TO' | 'SIMILAR_TO';
  sourceId: string;
  targetId: string;
  properties: Record<string, any>;
}

export interface TopicCluster {
  id: string;
  label: string;
  coherenceScore: number;
  memberCount: number;
  members: string[];  // Document IDs
}

// Graph builder orchestrator
export class GraphBuilder {
  constructor(
    private neo4j: Neo4jClient,
    private mdcontext: MdContextIndex,
    private graphology: GraphologyCache
  ) {}

  async build(): Promise<void> {
    console.log('Building knowledge graph...');

    // Phase 1: Nodes
    const documents = await this.mdcontext.getDocuments();
    const sections = await this.mdcontext.getSections();
    const concepts = await this.extractConcepts(documents);

    await this.createNodes(documents, sections, concepts);

    // Phase 2: Edges
    await this.createExplicitLinks();
    await this.createSemanticLinks();
    await this.createConceptMentions();

    // Phase 3: Enrichment
    await this.runClustering();
    await this.computePageRank();

    // Phase 4: Sync to Graphology
    await this.graphology.syncFromNeo4j(this.neo4j);

    console.log('Graph build complete!');
  }
}
```

---

## 6. Implementation Checklist

### Phase 1: Infrastructure Setup (Week 1)

- [ ] Install Neo4j Community Edition
  ```bash
  # macOS
  brew install neo4j
  neo4j start

  # Linux
  wget -O - https://debian.neo4j.com/neotechnology.gpg.key | sudo apt-key add -
  sudo apt-get install neo4j
  sudo systemctl start neo4j
  ```

- [ ] Install TypeScript dependencies
  ```bash
  npm install neo4j-driver graphology graphology-metrics graphology-communities-louvain
  npm install -D @types/node @types/neo4j-driver
  ```

- [ ] Create project structure (see 5.1)
- [ ] Implement Neo4jClient wrapper
- [ ] Implement GraphologyCache
- [ ] Write connection tests

### Phase 2: Data Ingestion (Week 1-2)

- [ ] Implement DocumentBuilder
- [ ] Implement SectionBuilder
- [ ] Implement ConceptExtractor
- [ ] Implement LinkBuilder (explicit markdown links)
- [ ] Implement SemanticBuilder (SIMILAR_TO edges)
- [ ] Write CSV bulk import script
- [ ] Test on 100-file subset
- [ ] Full import of 2066 files

### Phase 3: Graph Enrichment (Week 2)

- [ ] Implement PageRank computation (Graphology)
- [ ] Implement Louvain clustering (Graphology)
- [ ] Implement concept hierarchy builder
- [ ] Sync enrichment data back to Neo4j
- [ ] Validate enrichment quality (manual review of top 20 docs)

### Phase 4: Query Layer (Week 3)

- [ ] Implement Cypher query templates
- [ ] Implement high-level query API
- [ ] Implement hybrid search (Neo4j + mdcontext)
- [ ] Implement caching layer
- [ ] Write query performance benchmarks

### Phase 5: Validation (Week 4)

- [ ] Create ground truth labels (200 relationships)
- [ ] Implement 10 test cases (see proposal)
- [ ] Calculate precision/recall/F1 metrics
- [ ] Generate validation report
- [ ] Iterate on thresholds/hyperparameters

### Phase 6: Visualization & Documentation (Week 5)

- [ ] Export graph to GraphML
- [ ] Create Neo4j Browser visualization guides
- [ ] Implement D3.js/vis.js web viewer
- [ ] Write technical documentation
- [ ] Create demo scenarios

---

## 7. Configuration & Tuning

### Neo4j Configuration

```bash
# neo4j.conf (adjust for development)
dbms.memory.heap.initial_size=512m
dbms.memory.heap.max_size=2g
dbms.memory.pagecache.size=512m

# Query timeout (prevent runaway queries)
dbms.transaction.timeout=30s

# Enable APOC procedures (for advanced graph algorithms)
dbms.security.procedures.unrestricted=apoc.*
```

### Similarity Thresholds

```typescript
// config/thresholds.ts
export const THRESHOLDS = {
  // SIMILAR_TO edges (cosine similarity)
  semanticSimilarity: {
    min: 0.65,      // Only create edge if >65% similar
    strong: 0.80    // Mark as "strong" similarity
  },

  // RELATED_TO edges (concept co-occurrence)
  conceptRelation: {
    minCooccurrence: 3,  // Must co-occur 3+ times
    minSimilarity: 0.60  // Semantic similarity threshold
  },

  // TopicCluster membership
  clusterMembership: {
    minStrength: 0.50,   // Min cosine to centroid
    maxClusters: 30      // K for k-means
  }
};
```

### Performance Tuning

```typescript
// Batch sizes for imports
export const BATCH_SIZES = {
  nodeCreation: 1000,     // Create 1000 nodes per transaction
  edgeCreation: 500,      // Create 500 edges per transaction
  vectorSearch: 50        // Search 50 docs concurrently
};

// Cache sizes
export const CACHE_CONFIG = {
  maxQueryCacheSize: 10000,  // 10K cached query results
  ttl: 3600                  // 1 hour TTL
};
```

---

## 8. Success Metrics

### Build Performance

| Metric | Target | Measurement |
|--------|--------|-------------|
| Initial build time | <30s | Time from start to final enrichment |
| Incremental rebuild (1% changed) | <2s | Time to update 20 docs |
| Memory usage (Neo4j) | <1GB | Heap + pagecache |
| Memory usage (Graphology) | <300MB | In-memory graph |
| Disk usage | <500MB | Neo4j data directory |

### Query Performance

| Query Type | Target Latency | Example |
|------------|----------------|---------|
| Single-hop | <50ms | "What does X link to?" |
| Multi-hop (2 hops) | <80ms | "What concepts relate to X?" |
| Multi-hop (3 hops) | <100ms | "Dependency chain for feature X" |
| PageRank sort | <20ms | "Top 50 important docs" |
| Semantic search + graph expand | <150ms | "Find similar docs to X + neighbors" |

### Quality Metrics

| Metric | Target | Method |
|--------|--------|--------|
| Link precision | >0.85 | Manual validation of 100 random LINKS_TO edges |
| Link recall | >0.75 | Compare against ground truth explicit links |
| Concept extraction accuracy | >0.80 | % of extracted concepts that are valid |
| Semantic edge precision | >0.65 | Manual validation of 100 random SIMILAR_TO edges |
| Clustering coherence | >0.40 | Silhouette score |

---

## 9. Risk Mitigation

### Technical Risks

**Risk**: Neo4j installation/configuration issues
**Mitigation**: Provide Docker Compose setup as fallback
```yaml
# docker-compose.yml
version: '3'
services:
  neo4j:
    image: neo4j:5.15-community
    ports:
      - "7474:7474"  # Browser
      - "7687:7687"  # Bolt
    environment:
      NEO4J_AUTH: neo4j/password
    volumes:
      - ./data:/data
```

**Risk**: Concept extraction quality too low
**Mitigation**: Start with high-precision patterns (config vars, API endpoints), expand later
**Fallback**: Use manual seed concepts + semantic expansion

**Risk**: Graph becomes too large/slow (memory)
**Mitigation**: Implement edge filtering (only keep top-K similar docs per document)
**Fallback**: Use hierarchical approach (summary graph + detail subgraphs)

**Risk**: Query performance misses targets
**Mitigation**: Add indexes early (see 4.4), profile slow queries with `EXPLAIN`
**Fallback**: Pre-compute hot queries, cache in Graphology

---

## 10. Sources & References

### Graph Database Comparisons
- [Top 5 Neo4j Alternatives of 2025](https://www.puppygraph.com/blog/neo4j-alternatives)
- [Neo4j vs TinkerPop Comparison](https://stackshare.io/stackups/neo4j-vs-tinkerpop)
- [Neo4j vs NetworkX Performance Drag Race](https://towardsdatascience.com/fire-up-your-centrality-metric-engines-neo4j-vs-networkx-a-drag-race-of-sorts-18857f25be35/)
- [Performance of Graph and Relational Databases](https://www.mdpi.com/2076-3417/12/13/6490)
- [Neo4j Graph Database Scalability](https://neo4j.com/product/neo4j-graph-database/scalability/)

### Schema Design Best Practices
- [How to Build a Knowledge Graph in 7 Steps](https://neo4j.com/blog/knowledge-graph/how-to-build-knowledge-graph/)
- [Knowledge Graph Schema Design Patterns](https://terminusdb.com/blog/knowledge-graph-schema-design/)
- [Start Smart: 15 Questions Before Building a Knowledge Graph](https://memgraph.com/blog/building-knowledge-graph-key-questions)
- [How to Build a Knowledge Graph from Unstructured Information](https://mirascope.com/blog/how-to-build-a-knowledge-graph)

### Hybrid Architecture & Embeddings
- [HybridRAG: Why Combine Vector Embeddings with Knowledge Graphs](https://memgraph.com/blog/why-hybridrag)
- [GraphRAG with Qdrant and Neo4j](https://qdrant.tech/documentation/examples/graphrag-qdrant-neo4j/)
- [Building a Graph Database with Vector Embeddings](https://medium.com/thedeephub/building-a-graph-database-with-vector-embeddings-a-python-tutorial-with-neo4j-and-embeddings-277ce608634d)
- [Neo4j Vector Index with LangChain](https://docs.langchain.com/oss/python/integrations/vectorstores/neo4jvector)

### TypeScript Graph Libraries
- [Graphology vs Cytoscape Comparison](https://npm-compare.com/cytoscape,graphlib,graphology,vis-network)
- [Graphology Official Documentation](https://graphology.github.io/)
- [JavaScript Graph Visualization Comparison](https://www.cylynx.io/blog/a-comparison-of-javascript-graph-network-visualisation-libraries/)

### Scalability Benchmarks
- [Graph Database Performance Benchmarks](https://www.tigergraph.com/benchmark/)
- [How to Choose a Graph Database](https://cambridge-intelligence.com/choosing-graph-database/)
- [GitHub: Graph Database Benchmarks](https://github.com/socialsensor/graphdb-benchmarks)

---

## Conclusion

This architecture provides a **production-ready blueprint** for building a Knowledge Graph harness to validate mdcontext on 2066 markdown files. Every technology choice is justified with benchmarks, trade-offs are explicit, and implementation details are concrete.

**Key Decisions Recap**:
1. **Hybrid Neo4j + Graphology** - Persistence + speed
2. **TypeScript** - Native mdcontext integration
3. **Multi-tier storage** - Neo4j (graph) + mdcontext (embeddings)
4. **Rich schema** - 5 node types, 6 edge types, ~18K nodes, ~84K edges
5. **Performance targets** - <30s build, <100ms queries

**Next Steps**:
1. Week 1: Infrastructure setup + data ingestion
2. Week 2: Graph enrichment + validation
3. Week 3: Query layer + performance tuning
4. Week 4: Test cases + metrics
5. Week 5: Visualization + documentation

This is not a research project - this is **executable engineering**. Start coding.
