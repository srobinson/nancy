# Knowledge Graph Harness - Quick Setup Guide
## From Zero to Running Knowledge Graph in 4 Weeks

**Generated:** 2026-01-26
**Status:** Production-Ready Implementation Guide
**Corpus:** 2,066 markdown files from agentic-flow

---

## 🎯 What You'll Build

A complete **Knowledge Graph system** that:
- Ingests 2,066 markdown files from agentic-flow
- Constructs 18,586 nodes and 84,066 edges
- Provides CLI query interface (`kg search`, `kg expand`, `kg path`)
- Generates interactive visualizations
- Validates with 90%+ precision on ground truth

**Proof of mdcontext's value:** Structure-aware parsing + relationship discovery at scale

---

## 📚 Implementation Documents

| # | Document | Focus | Size | Agent |
|---|----------|-------|------|-------|
| 01 | [Architecture](01-architecture.md) | Tech stack, schema, scalability | 38 KB | a305784 |
| 02 | [Extraction](02-extraction.md) | Data pipeline, entity extraction | 41 KB | a914324 |
| 03 | [Construction](03-construction.md) | Graph building, deduplication | 68 KB | adf51d6 |
| 04 | [Query Interface](04-query-interface.md) | CLI, API, visualization | 56 KB | add0121 |
| 05 | [Validation](05-validation.md) | Testing, metrics, quality | 83 KB | a708fa4 |

**Total:** 286 KB of executable implementation guidance

---

## ⚡ Quick Start (30 Minutes)

### Step 1: Environment Setup (5 min)

```bash
# Create project directory
mkdir kg-harness && cd kg-harness

# Initialize project
npm init -y
npm install typescript @types/node tsx --save-dev

# Install Neo4j (Docker approach)
docker run \
  --name kg-neo4j \
  -p 7474:7474 -p 7687:7687 \
  -e NEO4J_AUTH=neo4j/mdcontext123 \
  -d neo4j:5.15-community

# Verify Neo4j running
open http://localhost:7474
# Login: neo4j / mdcontext123
```

### Step 2: Install Dependencies (5 min)

```bash
# Core dependencies
npm install neo4j-driver graphology graphology-layout-forceatlas2

# mdcontext integration
npm install effect @effect/schema

# CLI & visualization
npm install typer d3 commander

# Testing & validation
npm install --save-dev vitest @vitest/coverage-v8

# TypeScript config
npx tsc --init
```

### Step 3: Directory Structure (5 min)

```bash
mkdir -p src/{graph,builders,enrichment,query,validation}
mkdir -p config data tests

# Create skeleton files
touch src/graph/neo4j-client.ts
touch src/builders/graph-builder.ts
touch src/query/cli.ts
touch config/thresholds.ts
```

### Step 4: Configure (5 min)

Create `config/thresholds.ts`:
```typescript
export const config = {
  neo4j: {
    uri: 'bolt://localhost:7687',
    user: 'neo4j',
    password: 'mdcontext123'
  },
  similarity: {
    semanticThreshold: 0.75,
    fuzzyThreshold: 0.85,
    cooccurrenceMin: 3
  },
  extraction: {
    batchSize: 100,
    maxConcurrency: 4
  }
};
```

### Step 5: First Implementation (10 min)

Copy the extraction pipeline from `02-extraction.md`:

```typescript
// src/builders/extractor.ts
import { Parser } from '@mdcontext/parser';

async function extractKnowledgeGraph(rootPath: string) {
  const parser = Parser.create();
  const docs = await parser.parseDirectory(rootPath);

  // See 02-extraction.md for full implementation
  console.log(`Extracted ${docs.length} documents`);
  return docs;
}

extractKnowledgeGraph('/Users/alphab/Dev/LLM/DEV/agentic-flow/agentic-flow');
```

Run it:
```bash
npx tsx src/builders/extractor.ts
```

---

## 🏗️ Full Implementation Roadmap

### Week 1: Foundation (Architecture + Extraction)

**Days 1-3: Infrastructure**
- [ ] Neo4j setup and configuration
- [ ] TypeScript project structure
- [ ] Core client classes (`Neo4jClient`, `GraphologyCache`)
- [ ] Connection testing and health checks

**Days 4-5: Extraction Pipeline**
- [ ] Implement `extractKnowledgeGraph()` from 02-extraction.md
- [ ] Test on 10 sample files
- [ ] Batch processing for 2,066 files
- [ ] Error handling and logging

**Day 6-7: Concept Extraction**
- [ ] Heading-based extraction
- [ ] Code block extraction
- [ ] TF-IDF keyword extraction
- [ ] Validation on sample docs

**Deliverable:** Extract all entities from 2,066 files → JSON output

---

### Week 2: Graph Construction

**Days 1-2: Node Creation**
- [ ] Document nodes with metadata
- [ ] Section nodes with content
- [ ] Concept nodes with normalization
- [ ] Test incremental updates

**Days 3-4: Edge Creation**
- [ ] Explicit links (LINKS_TO)
- [ ] Semantic similarity (SIMILAR_TO)
- [ ] Concept mentions (MENTIONS)
- [ ] Containment (CONTAINS)

**Days 5-7: Deduplication & Enrichment**
- [ ] Concept normalization pipeline
- [ ] Entity resolution (exact → fuzzy → semantic)
- [ ] PageRank computation
- [ ] Community detection (Leiden)

**Deliverable:** Complete graph in Neo4j with 18K nodes, 84K edges

---

### Week 3: Query Interface & Visualization

**Days 1-3: CLI Implementation**
- [ ] `kg search` command
- [ ] `kg expand` command
- [ ] `kg path` command
- [ ] `kg stats` command
- [ ] Help text and examples

**Days 4-5: Programmatic API**
- [ ] TypeScript API classes
- [ ] Async query methods
- [ ] Type-safe return types
- [ ] Error handling

**Days 6-7: Visualization**
- [ ] D3.js force-directed graph
- [ ] Interactive exploration (click, drag, zoom)
- [ ] Export to SVG/PNG
- [ ] Graphviz hierarchical layouts

**Deliverable:** Working CLI + API + visualizations

---

### Week 4: Validation & Metrics

**Days 1-2: Ground Truth**
- [ ] Sample 50 documents stratified
- [ ] Manual annotation guidelines
- [ ] Annotate nodes and edges
- [ ] Calculate IAA (Inter-Annotator Agreement)

**Days 3-4: Extraction Quality**
- [ ] Calculate precision/recall for nodes
- [ ] Calculate precision/recall for edges
- [ ] False positive/negative analysis
- [ ] Edge weight correlation

**Days 5-6: Graph Quality**
- [ ] Completeness metrics
- [ ] Connectivity analysis
- [ ] Centrality distribution
- [ ] Clustering coherence

**Day 7: Reporting**
- [ ] Metrics dashboard (HTML)
- [ ] Success criteria evaluation
- [ ] Documentation of results
- [ ] Prepare demo

**Deliverable:** Validated graph with quality report

---

## 🎯 Critical Path (Minimum Viable)

If you have **limited time**, follow this minimal path:

### Day 1: Setup Neo4j
```bash
docker run --name kg-neo4j -p 7474:7474 -p 7687:7687 \
  -e NEO4J_AUTH=neo4j/mdcontext123 -d neo4j:5.15-community
```

### Day 2-3: Extract Data
- Implement extraction pipeline from `02-extraction.md`
- Run on full 2,066 files
- Output: `data/extracted-graph.json`

### Day 4-5: Build Graph
- Implement graph builder from `03-construction.md`
- Load into Neo4j
- Verify with basic queries

### Day 6-7: Query Interface
- Implement basic CLI from `04-query-interface.md`
- Test 3 core commands: search, expand, path
- Generate one visualization

**Result:** Working knowledge graph in 7 days

---

## 📊 Success Metrics

### Extraction Quality (Week 2)
- ✅ 2,066 documents processed
- ✅ ~450 concepts extracted
- ✅ ~1,200 similarity edges created
- ✅ <2 minutes processing time

### Graph Quality (Week 3)
- ✅ 18,586 nodes created
- ✅ 84,066 edges created
- ✅ Connectivity >85%
- ✅ Clustering coefficient >0.30

### Validation Quality (Week 4)
- ✅ Node precision >0.90
- ✅ Edge precision >0.85
- ✅ Query accuracy >85%
- ✅ False positive rate <5%

### Performance (All Weeks)
- ✅ Build time <10 minutes
- ✅ Query latency P95 <100ms
- ✅ Memory usage <1GB peak
- ✅ Visualization render <2s

---

## 🔧 Key Implementation Classes

### 1. Neo4jClient (`src/graph/neo4j-client.ts`)
```typescript
export class Neo4jClient {
  constructor(uri: string, user: string, password: string);
  async createNode(type: string, props: any): Promise<string>;
  async createEdge(from: string, to: string, type: string, weight?: number): Promise<void>;
  async batchCreateNodes(nodes: any[]): Promise<void>;
  async batchCreateEdges(edges: any[]): Promise<void>;
  async query(cypher: string, params: any): Promise<any>;
  async close(): Promise<void>;
}
```

**See:** `01-architecture.md` Section 5.3 for full implementation

### 2. GraphBuilder (`src/builders/graph-builder.ts`)
```typescript
export class GraphBuilder {
  async buildFromExtractedData(data: ExtractedData): Promise<void>;
  async addDocument(doc: Document): Promise<void>;
  async addSection(section: Section): Promise<void>;
  async addConcept(concept: Concept): Promise<void>;
  async linkRelatedConcepts(threshold: number): Promise<void>;
}
```

**See:** `03-construction.md` Section 1 for full implementation

### 3. CLI (`src/query/cli.ts`)
```typescript
export class KnowledgeGraphCLI {
  async search(query: string, options: SearchOptions): Promise<void>;
  async expand(nodeId: string, depth: number): Promise<void>;
  async findPath(from: string, to: string): Promise<void>;
  async stats(): Promise<void>;
  async visualize(focus: string, output: string): Promise<void>;
}
```

**See:** `04-query-interface.md` Section 7 for full implementation

### 4. Validator (`src/validation/validator.ts`)
```typescript
export class GraphValidator {
  async calculatePrecisionRecall(groundTruth: any): Promise<Metrics>;
  async checkGraphQuality(): Promise<QualityReport>;
  async validateQueries(testCases: TestCase[]): Promise<QueryResults>;
  async generateReport(): Promise<string>;
}
```

**See:** `05-validation.md` Section 9 for full implementation

---

## 🚀 Quick Commands Reference

Once implemented, here's what you can do:

```bash
# Search for concepts
kg search "authentication"
kg search "vector search" --type concept

# Explore relationships
kg expand docs/api/auth.md --depth 2
kg expand "checkpoint system" --type concept

# Find connection paths
kg path docs/setup.md docs/api/advanced.md
kg path "authentication" "database"

# Graph statistics
kg stats
kg stats --top 10

# Generate visualizations
kg visualize "authentication" --output auth-graph.html
kg visualize --all --layout hierarchical --output full-graph.svg

# Find documentation gaps
kg gaps orphans
kg gaps concepts --min-mentions 10
```

---

## 📖 Documentation Structure

```
implementation/
├── SETUP-GUIDE.md (this file)        # Quick start guide
├── 01-architecture.md                 # Technical decisions
├── 02-extraction.md                   # Data pipeline
├── 03-construction.md                 # Graph building
├── 04-query-interface.md              # CLI & API design
└── 05-validation.md                   # Testing & metrics

src/
├── graph/                             # Neo4j client, Graphology
├── builders/                          # Extraction & construction
├── enrichment/                        # PageRank, communities
├── query/                             # CLI & API
└── validation/                        # Testing & metrics

tests/
├── unit/                              # Component tests
├── integration/                       # Pipeline tests
├── validation/                        # Ground truth tests
└── performance/                       # Benchmarks

data/
├── extracted/                         # JSON intermediates
├── ground-truth/                      # Manual annotations
└── exports/                           # Visualizations
```

---

## 🎓 Learning Resources

### Essential Reading (in order)
1. **Start here:** `01-architecture.md` - Understand the tech stack
2. **Then:** `02-extraction.md` - See how data flows
3. **Next:** `03-construction.md` - Learn graph building
4. **After:** `04-query-interface.md` - Understand usage
5. **Finally:** `05-validation.md` - Ensure quality

### Code Examples
- Extract 10 files: See `02-extraction.md` Section 6
- Build graph: See `03-construction.md` Section 8
- Run CLI: See `04-query-interface.md` Section 7
- Validate: See `05-validation.md` Section 9

### External Resources
- [Neo4j Documentation](https://neo4j.com/docs/)
- [Graphology Guide](https://graphology.github.io/)
- [Knowledge Graph Best Practices](https://www.w3.org/TR/swbp-vocab-pub/)
- [Graph Visualization with D3](https://d3js.org/)

---

## 🐛 Troubleshooting

### "Neo4j connection failed"
```bash
# Check if Docker container is running
docker ps | grep neo4j

# Restart if needed
docker restart kg-neo4j

# Check logs
docker logs kg-neo4j
```

### "Out of memory during graph build"
```typescript
// Reduce batch size in config/thresholds.ts
export const config = {
  extraction: {
    batchSize: 50,  // Was 100
    maxConcurrency: 2  // Was 4
  }
};
```

### "Extraction too slow"
```typescript
// Enable parallel processing
const results = await Promise.all(
  batches.map(batch => extractBatch(batch))
);
```

### "Query results not relevant"
```typescript
// Tune similarity threshold
export const config = {
  similarity: {
    semanticThreshold: 0.80,  // Was 0.75 (stricter)
  }
};
```

---

## 💡 Pro Tips

1. **Start Small:** Test on 10 files before processing all 2,066
2. **Use Checkpoints:** Save intermediate results to resume interrupted builds
3. **Monitor Memory:** Watch `htop` during graph construction
4. **Index First:** Create Neo4j indexes before bulk import (100x faster)
5. **Visualize Early:** Generate graphs frequently to validate structure
6. **Version Control:** Commit after each working phase
7. **Document Decisions:** Note why you chose thresholds, algorithms
8. **Measure Everything:** Track metrics from day 1

---

## 🎯 Next Actions (Right Now)

### Option 1: Jump In (Recommended)
```bash
cd /Users/alphab/Dev/LLM/DEV/TMP/nancy/research/pudding
mkdir kg-harness
cd kg-harness

# Follow Quick Start above (30 minutes)
```

### Option 2: Read First
```bash
# Open in your editor
code /Users/alphab/Dev/LLM/DEV/TMP/nancy/research/pudding/implementation/

# Read in order:
# 1. 01-architecture.md
# 2. 02-extraction.md
# 3. This file again (you'll understand it better)
```

### Option 3: Create Linear Issues
I can create 4 Linear issues for Nancy:
1. **KG-001**: Infrastructure setup (Neo4j, TypeScript, dependencies)
2. **KG-002**: Extraction pipeline implementation
3. **KG-003**: Graph construction and enrichment
4. **KG-004**: Query interface and validation

Each issue would have:
- Full spec from implementation docs
- Acceptance criteria
- Code examples
- Timeline estimate

**Want me to create the Linear issues?**

---

## 🚢 Deployment (Future)

Once validated locally, you can deploy:

### Docker Compose (Recommended)
```yaml
version: '3.8'
services:
  neo4j:
    image: neo4j:5.15-community
    ports:
      - "7474:7474"
      - "7687:7687"
    environment:
      NEO4J_AUTH: neo4j/production_password
    volumes:
      - neo4j-data:/data

  kg-api:
    build: .
    ports:
      - "3000:3000"
    depends_on:
      - neo4j
    environment:
      NEO4J_URI: bolt://neo4j:7687

volumes:
  neo4j-data:
```

### Production Checklist
- [ ] Secure Neo4j with strong password
- [ ] Enable authentication on API
- [ ] Set up monitoring (Prometheus + Grafana)
- [ ] Configure backups
- [ ] SSL/TLS for connections
- [ ] Rate limiting on API
- [ ] CORS configuration
- [ ] Logging and alerting

---

## 🎉 Success Criteria

You'll know you've succeeded when:

✅ **Week 1:** 2,066 files extracted → 18K+ entities in JSON
✅ **Week 2:** Graph built in Neo4j → Browse at http://localhost:7474
✅ **Week 3:** CLI works → `kg search "auth"` returns results
✅ **Week 4:** Validation passes → Precision >0.90, Recall >0.85

**Ultimate test:** Show someone unfamiliar with agentic-flow. Can they discover relationships? Find relevant docs? Understand the codebase faster?

**If yes, mdcontext's value is proven.** 🎯

---

## 📞 Support

If you get stuck:
1. Check the specific implementation doc (01-05)
2. Review code examples in that doc
3. Search Neo4j/Graphology documentation
4. Ask the swarm for clarification (spawn another agent focused on your blocker)

---

**Ready to build?** Start with the Quick Start above or dive into `01-architecture.md` for the full technical specification.

The harness awaits. Let's prove mdcontext's worth. 🚀
