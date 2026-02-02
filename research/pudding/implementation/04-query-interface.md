# Query Interface & User Experience: Knowledge Graph Harness

## Executive Summary

This document defines the query interface and user experience for the Knowledge Graph harness, enabling developers to explore documentation relationships through both CLI commands and programmatic APIs. The design emphasizes **user-friendliness**, **progressive disclosure** (simple queries for common tasks, power features for complex needs), and **visual understanding** through interactive graph exploration.

**Key Design Decisions:**
- **Query Language**: Custom DSL built on Cypher foundations (best of both worlds: familiar syntax, domain-specific shortcuts)
- **CLI Framework**: Typer (Python type hints, automatic validation, excellent UX)
- **Visualization**: D3.js force-directed graphs + static Graphviz exports
- **API**: Async Python with TypeScript bindings for cross-language support
- **Output Formats**: JSON (programmatic), Markdown (reports), SVG/PNG (visualization), CSV (data export)

---

## 1. Query Language Choice

### Decision: Hybrid Custom DSL + Cypher

**Rationale**: Build a domain-specific language that:
1. Uses Cypher-like syntax for familiarity (if users know Neo4j, they're 80% there)
2. Adds documentation-specific shortcuts (common patterns as first-class commands)
3. Compiles to Cypher/Gremlin under the hood (portability across graph databases)

### Why Not Pure Cypher/Gremlin/SPARQL?

| Language | Pros | Cons | Decision |
|----------|------|------|----------|
| **Cypher** | Readable ASCII-art syntax `(doc)-[:LINKS_TO]->(other)`, widely known, excellent for pattern matching | Neo4j-specific (vendor lock-in), verbose for simple queries | Use as foundation, but add shortcuts |
| **Gremlin** | True "write once, run anywhere" (TinkerPop standard), functional style, language-agnostic | Steep learning curve, chaining syntax hard to read: `g.V().hasLabel('doc').out('links')` | Too complex for doc queries |
| **SPARQL** | W3C standard for RDF/semantic web, powerful for ontologies | Heavy semantics overhead, RDF triple model mismatch for property graphs | Wrong abstraction level |
| **Custom DSL** | Tailored to documentation domain, simple syntax for common tasks, extensible | Requires custom parser, learning curve for new syntax | Best fit with Cypher foundations |

### Custom DSL Design

**Philosophy**: Natural language-inspired queries that compile to efficient graph traversals.

#### Basic Syntax Patterns

```python
# Pattern 1: Simple search (keyword → nodes)
search "authentication"
→ Finds all nodes (docs, concepts) containing "authentication"

# Pattern 2: Relationship traversal (node → edges → nodes)
expand "docs/auth.md"
→ Shows all nodes connected to auth.md (1-hop neighbors)

# Pattern 3: Path finding (node → path → node)
path "auth.md" to "database.md"
→ Shortest path between two documents

# Pattern 4: Concept queries (semantic relationships)
concept "retry strategy" related-to "error handling"
→ Finds concept relationships with context

# Pattern 5: Structural queries (graph topology)
orphans concepts
→ Concepts mentioned frequently but never defined

# Pattern 6: Stats & analysis
stats cluster "authentication"
→ Graph metrics for auth-related subgraph
```

#### Cypher Translation Examples

```cypher
// DSL: search "authentication"
MATCH (n)
WHERE n.content CONTAINS "authentication"
   OR n.title CONTAINS "authentication"
RETURN n
ORDER BY n.pagerank DESC
LIMIT 20

// DSL: expand "docs/auth.md"
MATCH (doc:Document {path: "docs/auth.md"})-[r]-(related)
RETURN doc, r, related

// DSL: path "auth.md" to "database.md"
MATCH path = shortestPath(
  (start:Document {path: "auth.md"})-[*..5]-(end:Document {path: "database.md"})
)
RETURN path

// DSL: orphans concepts
MATCH (c:Concept)
WHERE c.mentionCount > 10
  AND NOT EXISTS {
    MATCH (c)<-[:DEFINES]-(section:Section)
  }
RETURN c.name, c.mentionCount
ORDER BY c.mentionCount DESC
```

### Query Complexity Levels

**Level 1: Simple Searches** (80% of use cases)
- Keyword search: `search "keyword"`
- Direct expansion: `expand "file.md"`
- Stats: `stats`

**Level 2: Relationship Queries** (15% of use cases)
- Path finding: `path "A" to "B"`
- Concept relations: `concept "X" related-to "Y"`
- Cluster exploration: `cluster "topic"`

**Level 3: Advanced Cypher** (5% of use cases - power users)
- Raw Cypher passthrough: `cypher "MATCH (n:Doc)..."`
- Custom algorithms: `pagerank --damping 0.85`
- Temporal queries: `changed-after "2025-01-01"`

---

## 2. CLI Commands: The `kg` Tool

### Installation & Setup

```bash
# Install knowledge graph CLI
pip install mdcontext-kg  # or bundle with mdcontext

# Initialize graph from mdcontext index
kg init --from-mdcontext ~/.mdcontext/indexes/my-project

# Or build from scratch
kg build ./docs --output ./kg-data
```

### Command Reference

#### `kg search` - Search nodes

**Purpose**: Find documents, concepts, or sections matching keywords.

```bash
# Basic keyword search
kg search "authentication"

# Search specific node types
kg search "authentication" --type concept
kg search "auth" --type document

# Search with context (show surrounding text)
kg search "retry" --context 2  # 2 lines before/after

# Output formats
kg search "auth" --format json
kg search "auth" --format markdown > results.md
```

**Example Output**:
```
🔍 Search Results for "authentication" (12 matches)

Documents (5):
  1. docs/auth/overview.md (PageRank: 0.042)
     "Authentication system provides OAuth, JWT, and session-based login..."

  2. docs/security/patterns.md (PageRank: 0.031)
     "Authentication middleware validates tokens before route handling..."

Concepts (7):
  1. OAuth 2.0 (mentioned in 8 docs)
  2. JWT Token (mentioned in 6 docs)
  3. Session Management (mentioned in 12 docs)
  ...
```

#### `kg expand` - Show related documents

**Purpose**: Explore relationships from a starting node (1-hop or multi-hop neighbors).

```bash
# Show immediate connections
kg expand "docs/auth.md"

# Multi-hop expansion (2 levels deep)
kg expand "docs/auth.md" --depth 2

# Filter by relationship type
kg expand "docs/auth.md" --rels LINKS_TO,SIMILAR_TO

# Visualize expansion
kg expand "docs/auth.md" --visualize
```

**Example Output**:
```
📄 Expanding docs/auth.md

Direct Links (LINKS_TO):
  → docs/security/patterns.md (explicit markdown link)
  → docs/api/auth-endpoints.md (explicit markdown link)

Similar Documents (SIMILAR_TO):
  → docs/auth/oauth.md (similarity: 0.82)
  → docs/auth/jwt.md (similarity: 0.76)

Shared Concepts (via MENTIONS):
  → "session management" (also in 3 other docs)
  → "token validation" (also in 5 other docs)

Backlinks (incoming LINKS_TO):
  ← docs/getting-started.md
  ← docs/deployment/security.md
```

#### `kg path` - Find connection paths

**Purpose**: Discover how two documents/concepts are related.

```bash
# Shortest path between documents
kg path "auth.md" "database.md"

# All paths up to length N
kg path "auth.md" "database.md" --max-length 4 --all-paths

# Weighted shortest path (by semantic similarity)
kg path "auth.md" "database.md" --weighted

# Show path with context
kg path "auth.md" "database.md" --show-context
```

**Example Output**:
```
🛤️  Path from auth.md → database.md (3 hops)

auth.md
  ├─[MENTIONS]→ "session management"
  │             └─[MENTIONED_IN]→ session-store.md
  │                               └─[LINKS_TO]→ database.md

Alternative Path (4 hops):
auth.md
  ├─[SIMILAR_TO]→ oauth.md
  │               └─[BELONGS_TO]→ Cluster: Security
  │                                └─[CONTAINS]→ database-security.md
  │                                               └─[LINKS_TO]→ database.md

💡 Insight: Both paths converge through security-related topics.
    Consider adding explicit link from auth.md → database.md.
```

#### `kg stats` - Graph statistics

**Purpose**: Understand graph structure and health.

```bash
# Overall graph stats
kg stats

# Cluster-specific stats
kg stats --cluster "authentication"

# Node importance ranking
kg stats --pagerank --top 20

# Community detection
kg stats --communities
```

**Example Output**:
```
📊 Knowledge Graph Statistics

Graph Scale:
  Nodes:     2,147 total
    Documents:     2,012
    Concepts:        435
    Sections:        ... (inferred)
    Clusters:         23

  Edges:    12,394 total
    LINKS_TO:       1,847 (explicit)
    SIMILAR_TO:     3,201 (semantic)
    MENTIONS:       6,112 (concept refs)
    BELONGS_TO:     2,012 (clustering)

Graph Health:
  ✅ Connectivity:        97.3% in main component
  ✅ Clustering Coeff:     0.42 (good community structure)
  ⚠️  Orphan Concepts:     12 (concepts with no definitions)
  ⚠️  Isolated Docs:       8 (no incoming/outgoing links)

  Average Path Length:   3.2 hops
  Graph Diameter:       11 hops
  Modularity (Louvain): 0.51

Top 5 Documents by PageRank:
  1. docs/README.md               (0.089)
  2. docs/architecture/overview.md (0.067)
  3. docs/auth/overview.md        (0.042)
  4. docs/api/reference.md        (0.038)
  5. docs/deployment/guide.md     (0.033)

Top 5 Concepts by Centrality:
  1. authentication    (betweenness: 0.234)
  2. configuration     (betweenness: 0.198)
  3. error handling    (betweenness: 0.156)
  4. API endpoint      (betweenness: 0.142)
  5. database          (betweenness: 0.128)
```

#### `kg visualize` - Generate graph visualizations

**Purpose**: Create visual representations of graph structure.

```bash
# Visualize entire graph (web-based interactive)
kg visualize --interactive

# Visualize subgraph around a concept
kg visualize "authentication" --radius 2

# Export static image
kg visualize "authentication" --output auth-graph.svg --format svg

# Export for external tools (Neo4j, Gephi)
kg visualize --export neo4j --output graph.cypher
kg visualize --export gephi --output graph.gexf
```

**Visualization Types**:
1. **Force-directed graph** (D3.js): Interactive exploration, drag nodes, click for details
2. **Hierarchical layout** (Graphviz): Document → section → concept tree
3. **Cluster view**: Color-coded communities with topic labels
4. **Heatmap**: Document similarity matrix (lighter = more similar)

#### `kg query` - Custom Cypher queries

**Purpose**: Power users can write raw Cypher for complex queries.

```bash
# Execute Cypher directly
kg query "MATCH (d:Document)-[:SIMILAR_TO]->(other) RETURN d, other LIMIT 10"

# Save query as named template
kg query --save find-orphans "MATCH (c:Concept)..."

# Run saved query
kg query --template find-orphans
```

#### `kg gaps` - Find documentation gaps

**Purpose**: Automatically identify missing documentation.

```bash
# Find orphan concepts (mentioned but not defined)
kg gaps orphans

# Find broken links
kg gaps broken-links

# Find stale documents (neighbors updated, but doc is old)
kg gaps stale --threshold 90days

# Find missing relationships (high similarity, no link)
kg gaps missing-links --threshold 0.75
```

**Example Output**:
```
🔍 Documentation Gaps Analysis

Orphan Concepts (mentioned but never defined):
  ⚠️  "rate limiting"        (mentioned in 8 docs, no definition)
  ⚠️  "webhook signature"    (mentioned in 5 docs, no definition)
  ⚠️  "circuit breaker"      (mentioned in 4 docs, no definition)

Missing Cross-References (high similarity, no link):
  📄 docs/auth/oauth.md ↔ docs/security/tokens.md (similarity: 0.84)
     💡 Suggestion: Add link from oauth.md → tokens.md

  📄 docs/api/rest.md ↔ docs/api/webhooks.md (similarity: 0.78)
     💡 Suggestion: Consider linking these related API docs

Stale Documents (not updated while neighbors were):
  ⏰ docs/deployment/kubernetes.md (180 days old)
     Related docs updated recently:
       - docs/deployment/docker.md (updated 15 days ago)
       - docs/deployment/scaling.md (updated 22 days ago)
```

### CLI Design Best Practices Applied

Following [Command Line Interface Guidelines](https://clig.dev/) and [BetterCLI.org](https://bettercli.org/):

1. **Human-first design**: Commands read like English (`kg search`, `kg expand`, `kg path`)
2. **Sensible defaults**: Most flags optional, reasonable defaults for limits/thresholds
3. **Progressive disclosure**: Simple commands for common tasks, `--help` for advanced options
4. **Rich output**: Colors, icons, progress bars for long operations
5. **Composability**: JSON output for piping (`kg search X | jq '.nodes[]'`)
6. **Consistency**: Uniform flag naming (`--format`, `--output`, `--limit`)
7. **Error messages**: Descriptive, actionable (not "Error 500", but "Graph database not initialized. Run `kg init` first.")

---

## 3. Programmatic API

### Python API

**Design Philosophy**: Async-first, type-safe, chainable queries.

#### Installation & Initialization

```python
from mdcontext_kg import KnowledgeGraph

# Initialize from existing graph
kg = KnowledgeGraph.load("./kg-data")

# Or build from mdcontext index
kg = await KnowledgeGraph.from_mdcontext("~/.mdcontext/indexes/my-project")
```

#### Core API Methods

##### Search API

```python
from mdcontext_kg import NodeType, SearchOptions

# Basic search
results = await kg.search("authentication")

# Type-filtered search
docs = await kg.search("authentication", node_type=NodeType.DOCUMENT)
concepts = await kg.search("auth", node_type=NodeType.CONCEPT)

# Advanced search with options
results = await kg.search(
    "retry",
    node_type=NodeType.CONCEPT,
    limit=10,
    include_context=True,
    min_score=0.5
)

# Iterate results
for node in results:
    print(f"{node.type}: {node.name} (score: {node.score})")
```

##### Expansion API

```python
# Single-hop expansion
neighbors = await kg.expand("docs/auth.md")

# Multi-hop with relationship filtering
neighbors = await kg.expand(
    "docs/auth.md",
    depth=2,
    relationships=["LINKS_TO", "SIMILAR_TO"],
    min_weight=0.65
)

# Get subgraph (nodes + edges)
subgraph = await kg.get_subgraph("docs/auth.md", radius=2)
print(f"Nodes: {len(subgraph.nodes)}, Edges: {len(subgraph.edges)}")
```

##### Path Finding API

```python
# Shortest path
path = await kg.find_path("auth.md", "database.md")

# All paths
paths = await kg.find_all_paths(
    "auth.md",
    "database.md",
    max_length=5,
    limit=10  # Return top 10 paths
)

# Weighted shortest path (by semantic similarity)
path = await kg.find_path(
    "auth.md",
    "database.md",
    weighted=True,
    weight_property="similarity"
)

# Path with context
path = await kg.find_path("auth.md", "database.md")
for hop in path.hops:
    print(f"{hop.source.name} --[{hop.relation}]--> {hop.target.name}")
    print(f"  Context: {hop.context}")
```

##### Traversal API

```python
# Custom graph traversals
traverser = kg.traverse("docs/auth.md")

# Fluent API (chainable)
results = await (
    traverser
    .out("LINKS_TO")           # Follow outgoing LINKS_TO edges
    .has("type", "Document")   # Filter to Document nodes
    .order_by("pagerank")      # Sort by PageRank
    .limit(10)                 # Top 10 results
    .execute()
)

# Complex traversals (Cypher-like)
query = kg.query()
results = await (
    query
    .match("(doc:Document)-[:MENTIONS]->(c:Concept)")
    .where("c.name", "contains", "auth")
    .return_("doc", "c")
    .execute()
)
```

##### Analysis API

```python
# Graph statistics
stats = await kg.stats()
print(f"Total nodes: {stats.node_count}")
print(f"Average path length: {stats.avg_path_length}")
print(f"Clustering coefficient: {stats.clustering_coeff}")

# PageRank
top_docs = await kg.pagerank(node_type=NodeType.DOCUMENT, top_k=20)
for doc, score in top_docs:
    print(f"{doc.path}: {score:.4f}")

# Community detection
communities = await kg.detect_communities(algorithm="louvain")
for community in communities:
    print(f"Cluster {community.id}: {len(community.members)} docs")
    print(f"  Label: {community.label}")
    print(f"  Top concepts: {community.top_concepts[:5]}")

# Gap analysis
gaps = await kg.find_gaps()
print(f"Orphan concepts: {gaps.orphan_concepts}")
print(f"Missing links: {gaps.missing_links}")
print(f"Stale documents: {gaps.stale_documents}")
```

##### Visualization API

```python
# Generate interactive visualization
viz = await kg.visualize(
    center="authentication",
    radius=2,
    layout="force-directed"
)
viz.save_html("auth-graph.html")
viz.serve(port=8080)  # Launch web server

# Export static image
viz.save_image("auth-graph.svg", format="svg")
viz.save_image("auth-graph.png", format="png", dpi=300)

# Export for external tools
await kg.export_neo4j("graph.cypher")
await kg.export_gephi("graph.gexf")
```

#### Return Types

```python
from dataclasses import dataclass
from typing import List, Dict, Optional

@dataclass
class Node:
    id: str
    type: NodeType  # DOCUMENT, CONCEPT, SECTION, CLUSTER
    name: str
    properties: Dict[str, Any]
    score: Optional[float] = None  # For search results

@dataclass
class Edge:
    source: str  # Node ID
    target: str  # Node ID
    type: str    # LINKS_TO, SIMILAR_TO, MENTIONS, etc.
    weight: float
    properties: Dict[str, Any]

@dataclass
class Path:
    length: int
    hops: List[PathHop]
    total_weight: float

@dataclass
class PathHop:
    source: Node
    target: Node
    relation: str
    weight: float
    context: Optional[str] = None

@dataclass
class Subgraph:
    nodes: List[Node]
    edges: List[Edge]
    center: Node

    def to_networkx(self):
        """Convert to NetworkX graph for analysis"""
        ...

    def to_json(self) -> Dict:
        """Export as JSON for web visualization"""
        ...

@dataclass
class GraphStats:
    node_count: int
    edge_count: int
    avg_path_length: float
    clustering_coeff: float
    modularity: float
    communities: int
    orphan_concepts: int
    isolated_documents: int
```

#### Async Context Manager

```python
# Proper resource management
async with KnowledgeGraph.load("./kg-data") as kg:
    results = await kg.search("authentication")
    path = await kg.find_path("auth.md", "db.md")
    # Automatically closed/cleaned up
```

### TypeScript/JavaScript API

**Design**: Mirrors Python API, uses Promises instead of async/await style.

```typescript
import { KnowledgeGraph, NodeType } from '@mdcontext/kg';

// Initialize
const kg = await KnowledgeGraph.load('./kg-data');

// Search
const results = await kg.search('authentication', {
  nodeType: NodeType.DOCUMENT,
  limit: 10,
  includeContext: true
});

// Expand
const neighbors = await kg.expand('docs/auth.md', {
  depth: 2,
  relationships: ['LINKS_TO', 'SIMILAR_TO']
});

// Path finding
const path = await kg.findPath('auth.md', 'database.md');

// Visualization (returns D3.js-compatible structure)
const viz = await kg.visualize({
  center: 'authentication',
  radius: 2,
  layout: 'force-directed'
});

// Export to JSON for web rendering
const graphData = viz.toJSON();
// → { nodes: [...], links: [...] }

// Close connection
await kg.close();
```

---

## 4. Query Examples from Original Proposal

Here's how each query from the knowledge graph proposal maps to our interface.

### Example 1: "Show me all dependencies of the checkpoint system"

**CLI**:
```bash
kg expand "checkpoint-system" --depth 2 --rels DEPENDS_ON,USES
```

**Python API**:
```python
deps = await kg.expand(
    "checkpoint-system",
    depth=2,
    relationships=["DEPENDS_ON", "USES", "MENTIONS"]
)

# Or more specific traversal
deps = await (
    kg.traverse("checkpoint-system")
    .out("DEPENDS_ON")
    .out("USES")
    .execute()
)
```

**Custom DSL**:
```
expand "checkpoint-system" following DEPENDS_ON, USES
```

**Output**:
```
Checkpoint System Dependencies:

Direct Dependencies (DEPENDS_ON):
  → session-management
  → state-persistence
  → error-recovery

Indirect Dependencies (via session-management):
  → database-connection
  → cache-layer

Components Used (USES):
  → serialization-library
  → timestamp-service
```

### Example 2: "What documents are orphaned?"

**CLI**:
```bash
kg gaps orphans --type document
```

**Python API**:
```python
orphans = await kg.find_orphaned_documents()

for doc in orphans:
    print(f"{doc.path} - no incoming/outgoing links")
```

**Custom DSL**:
```
orphans documents
```

**Cypher (raw)**:
```cypher
MATCH (d:Document)
WHERE NOT EXISTS {
  MATCH (d)-[:LINKS_TO|SIMILAR_TO]-()
}
RETURN d.path, d.title
```

### Example 3: "Find concepts that appear in >10 docs but have no definition"

**CLI**:
```bash
kg gaps orphans --type concept --min-mentions 10
```

**Python API**:
```python
undefined_concepts = await kg.find_undefined_concepts(
    min_mentions=10
)

for concept in undefined_concepts:
    print(f"{concept.name} - mentioned in {concept.mention_count} docs")
    print(f"  Appears in: {concept.document_list[:3]}...")
```

**Custom DSL**:
```
orphans concepts where mentions > 10
```

**Cypher (raw)**:
```cypher
MATCH (c:Concept)
WHERE c.mentionCount > 10
  AND NOT EXISTS {
    MATCH (c)<-[:DEFINES]-(section:Section)
  }
RETURN c.name, c.mentionCount,
       [(c)<-[:MENTIONS]-(s:Section) | s.docPath] as mentionedIn
ORDER BY c.mentionCount DESC
```

### Example 4: Complex Multi-Hop Query

**Scenario**: "If database timeout occurs, which systems are affected and in what order?"

**CLI**:
```bash
# Find concept, then trace impact
kg expand "database-timeout" --depth 3 --rels AFFECTS,TRIGGERS,CAUSES

# Or specific path query
kg query "
  MATCH path = (timeout:Concept {name: 'database timeout'})
               -[:MENTIONED_IN]->(:Section)
               -[:PART_OF]->(doc:Document)
               -[:LINKS_TO*1..3]->(affected:Document)
  RETURN path, affected
  ORDER BY length(path)
"
```

**Python API**:
```python
# Start from concept
timeout = await kg.find_concept("database timeout")

# Traverse to affected systems
impact = await (
    kg.traverse(timeout.id)
    .out("MENTIONED_IN")    # Sections discussing timeout
    .out("PART_OF")         # Parent documents
    .out("LINKS_TO", max_depth=3)  # Follow links to affected docs
    .execute()
)

# Build impact tree
for level, docs in enumerate(impact.by_depth()):
    print(f"Level {level}: {[d.name for d in docs]}")
```

**Output**:
```
Impact Analysis: Database Timeout

Immediate Impact (Level 1):
  • auth-service (session validation fails)
  • user-profile-service (profile load timeout)

Cascading Impact (Level 2):
  • api-gateway (503 errors on /login, /profile)
  • cache-service (fallback to stale cache)

Downstream Impact (Level 3):
  • frontend-app (login button stuck)
  • mobile-app (offline mode triggered)
  • monitoring (timeout alerts fired)

Suggested Mitigations:
  → See: docs/error-handling/database-resilience.md
  → See: docs/deployment/circuit-breakers.md
```

---

## 5. Visualization Strategy

### Tool Selection: D3.js + Graphviz

**Primary**: **D3.js** for interactive web visualization
- Force-directed layout for exploration
- Click to expand nodes, drag to rearrange
- Hover for context, click for full document
- Zoom/pan for large graphs
- Filter by node type, relationship type, clusters

**Secondary**: **Graphviz** for static exports and hierarchical layouts
- Dot layout for document → section → concept trees
- SVG/PNG export for documentation
- Fast rendering for large graphs (1000+ nodes)

**Why not vis.js?**: Deprecated and slower. D3.js has better performance and active development.

**Why not Neo4j Browser?**: Requires Neo4j installation. We want standalone visualization that works with any graph backend.

### Visualization Types

#### 1. Force-Directed Graph (D3.js)

**Use Case**: Exploration, discovering clusters, understanding relationships.

**Implementation**:
```typescript
import * as d3 from 'd3';

// Load graph data from KG API
const graphData = await kg.visualize({
  center: 'authentication',
  radius: 2
}).toJSON();

// → { nodes: [{id, type, name, ...}], links: [{source, target, type, weight}] }

// D3 force simulation
const simulation = d3.forceSimulation(graphData.nodes)
  .force('link', d3.forceLink(graphData.links)
    .id(d => d.id)
    .distance(d => 100 / d.weight)  // Stronger links = shorter distance
  )
  .force('charge', d3.forceManyBody().strength(-300))
  .force('center', d3.forceCenter(width / 2, height / 2));

// Color by node type
const colorScale = d3.scaleOrdinal()
  .domain(['DOCUMENT', 'CONCEPT', 'SECTION'])
  .range(['#3498db', '#e74c3c', '#2ecc71']);

// Draw nodes
const node = svg.selectAll('circle')
  .data(graphData.nodes)
  .enter().append('circle')
    .attr('r', d => 5 + d.pagerank * 50)  // Size by importance
    .attr('fill', d => colorScale(d.type))
    .call(drag(simulation));

// Draw links
const link = svg.selectAll('line')
  .data(graphData.links)
  .enter().append('line')
    .attr('stroke-width', d => d.weight * 3)
    .attr('stroke', d => linkColor(d.type));

// Update positions on tick
simulation.on('tick', () => {
  link
    .attr('x1', d => d.source.x)
    .attr('y1', d => d.source.y)
    .attr('x2', d => d.target.x)
    .attr('y2', d => d.target.y);

  node
    .attr('cx', d => d.x)
    .attr('cy', d => d.y);
});

// Interactivity
node.on('click', (event, d) => {
  // Expand node to show neighbors
  expandNode(d.id);
});

node.on('mouseover', (event, d) => {
  // Show tooltip with node details
  showTooltip(d);
});
```

**Features**:
- **Color coding**: Node types (docs=blue, concepts=red, sections=green)
- **Size coding**: Node size = PageRank (importance)
- **Edge thickness**: Link weight (semantic similarity or mention count)
- **Clustering**: Nodes naturally cluster by community
- **Interactive expansion**: Click node → load neighbors → add to graph
- **Search highlight**: Search for keyword → highlight matching nodes

#### 2. Hierarchical Tree (Graphviz)

**Use Case**: Understanding document structure, concept taxonomy.

**Implementation**:
```python
import graphviz

# Build Graphviz DOT from KG
dot = graphviz.Digraph(comment='Document Hierarchy')
dot.attr(rankdir='TB')  # Top to bottom

# Add document nodes
doc = await kg.get_document("auth.md")
dot.node(doc.id, doc.title, shape='box', style='filled', fillcolor='lightblue')

# Add section nodes
for section in doc.sections:
    dot.node(section.id, section.heading, shape='ellipse')
    dot.edge(doc.id, section.id, label='CONTAINS')

    # Add concept mentions
    for concept in section.concepts:
        dot.node(concept.id, concept.name, shape='diamond', fillcolor='lightcoral')
        dot.edge(section.id, concept.id, label=f'MENTIONS ({concept.count}x)')

# Render
dot.render('doc-structure.svg', format='svg')
```

**Example Output**: (visualization)
```
┌─────────────────┐
│  auth.md        │
└────────┬────────┘
         │
    ┌────┴─────┬──────────┐
    │          │          │
┌───▼───┐  ┌───▼───┐  ┌───▼───┐
│OAuth  │  │JWT    │  │Session│
└───┬───┘  └───┬───┘  └───┬───┘
    │          │          │
    ▼          ▼          ▼
 (concepts mentioned in each section)
```

#### 3. Cluster Map (Community Detection)

**Use Case**: Understanding topic organization, finding related content.

**Implementation**:
```python
# Detect communities
communities = await kg.detect_communities(algorithm='louvain')

# Create subgraph for each community
for community in communities:
    subgraph = await kg.get_subgraph(
        nodes=community.members,
        include_internal_edges=True
    )

    # Visualize with D3.js, color by cluster
    viz = subgraph.visualize(
        layout='force-directed',
        color=community.color,
        label=community.label
    )
    viz.save_html(f'cluster-{community.id}.html')
```

**Features**:
- Each cluster gets a unique color
- Cluster labels (auto-generated from top concepts)
- Inter-cluster links shown as dashed lines
- Intra-cluster links as solid lines

#### 4. Heatmap (Document Similarity Matrix)

**Use Case**: Finding similar documents at a glance.

**Implementation**:
```python
import seaborn as sns
import matplotlib.pyplot as plt

# Get similarity matrix
docs = await kg.get_all_documents()
similarity_matrix = await kg.compute_similarity_matrix(docs)

# Plot heatmap
plt.figure(figsize=(20, 20))
sns.heatmap(
    similarity_matrix,
    xticklabels=[d.title for d in docs],
    yticklabels=[d.title for d in docs],
    cmap='YlOrRd',
    vmin=0,
    vmax=1
)
plt.title('Document Similarity Matrix')
plt.savefig('similarity-heatmap.png', dpi=300)
```

### Layout Algorithms

| Algorithm | Use Case | Pros | Cons |
|-----------|----------|------|------|
| **Force-Directed** | General exploration | Natural clustering, interactive | Slow for >1000 nodes, non-deterministic |
| **Hierarchical (Tree)** | Document structure | Clear parent-child, deterministic | Only works for trees, no cross-links |
| **Circular** | Communities | Shows groups clearly | Confusing for dense graphs |
| **Grid** | Heatmap, matrix | Easy to read, compact | No relationship info |

### Interactive Features

1. **Click to Expand**: Click node → load 1-hop neighbors → add to graph
2. **Hover Tooltip**: Show node properties (title, type, PageRank, concepts)
3. **Search Highlight**: Search box → highlight matching nodes
4. **Filter Panel**: Toggle node types, edge types, clusters
5. **Zoom/Pan**: Scroll to zoom, drag background to pan
6. **Export**: Button to save current view as SVG/PNG
7. **Path Highlight**: Click two nodes → highlight shortest path
8. **Time Slider**: (If temporal data) Slide through doc versions

### Performance Optimization

**Large Graphs (>1000 nodes)**:
1. **Lazy Loading**: Start with center node + 1-hop, load more on demand
2. **Level-of-Detail**: Hide labels when zoomed out, show when zoomed in
3. **WebGL Rendering**: Use three.js or deck.gl for 10,000+ nodes
4. **Clustering**: Show clusters as single nodes, expand on click
5. **Filtering**: Pre-filter by importance (PageRank threshold)

---

## 6. Output Formats

### JSON (Programmatic Use)

**Use Case**: API responses, data exchange, web visualization.

```json
{
  "query": "search authentication",
  "results": {
    "nodes": [
      {
        "id": "doc_auth_md",
        "type": "DOCUMENT",
        "name": "docs/auth.md",
        "properties": {
          "title": "Authentication Overview",
          "path": "docs/auth.md",
          "tokens": 1247,
          "pagerank": 0.042,
          "lastModified": "2026-01-15T10:30:00Z"
        },
        "score": 0.89
      },
      {
        "id": "concept_oauth",
        "type": "CONCEPT",
        "name": "OAuth 2.0",
        "properties": {
          "mentionCount": 8,
          "firstMention": "docs/auth/oauth.md",
          "centrality": 0.234
        },
        "score": 0.76
      }
    ],
    "edges": [
      {
        "source": "doc_auth_md",
        "target": "concept_oauth",
        "type": "MENTIONS",
        "weight": 0.85,
        "properties": {
          "count": 12,
          "context": "OAuth 2.0 provides secure authorization..."
        }
      }
    ],
    "metadata": {
      "total_results": 12,
      "returned": 10,
      "query_time_ms": 23
    }
  }
}
```

**Schema** (TypeScript):
```typescript
interface QueryResult {
  query: string;
  results: {
    nodes: Node[];
    edges: Edge[];
    metadata: {
      total_results: number;
      returned: number;
      query_time_ms: number;
    };
  };
}

interface Node {
  id: string;
  type: 'DOCUMENT' | 'CONCEPT' | 'SECTION' | 'CLUSTER';
  name: string;
  properties: Record<string, any>;
  score?: number;  // Search relevance score
}

interface Edge {
  source: string;  // Node ID
  target: string;
  type: string;    // LINKS_TO, SIMILAR_TO, MENTIONS, etc.
  weight: number;  // 0-1 scale
  properties: Record<string, any>;
}
```

### Markdown (Reports)

**Use Case**: Documentation, reports, sharing with stakeholders.

**Example**: Graph statistics report

```markdown
# Knowledge Graph Report: Authentication Cluster

Generated: 2026-01-26 14:30:00

## Overview

This report analyzes the "authentication" topic cluster in the documentation knowledge graph.

### Cluster Statistics

- **Documents**: 23
- **Concepts**: 47
- **Avg Similarity**: 0.72 (strong cohesion)
- **External Links**: 156 (well-connected to other topics)

### Key Documents (by PageRank)

1. **docs/auth/overview.md** (PageRank: 0.042)
   - Central hub for authentication topics
   - Links to: OAuth, JWT, Session, API Keys
   - Backlinks from: Getting Started, Security, Deployment

2. **docs/auth/oauth.md** (PageRank: 0.031)
   - Detailed OAuth 2.0 implementation
   - Links to: Token Validation, Scopes, Client Registration

3. **docs/security/patterns.md** (PageRank: 0.028)
   - Cross-cutting security patterns
   - Mentions: Authentication, Authorization, Encryption

### Important Concepts

| Concept | Mentions | Centrality | Definition Doc |
|---------|----------|------------|----------------|
| OAuth 2.0 | 8 | 0.234 | docs/auth/oauth.md |
| JWT Token | 6 | 0.189 | docs/auth/jwt.md |
| Session Management | 12 | 0.156 | docs/auth/session.md |
| API Keys | 5 | 0.142 | docs/auth/api-keys.md |

### Documentation Gaps

⚠️ **Missing Definitions**:
- "refresh token" (mentioned 4x, no dedicated section)
- "token rotation" (mentioned 3x, no explanation)

⚠️ **Weak Links**:
- docs/auth/oauth.md ↔ docs/api/rest.md (similarity: 0.78, no link)
  - Recommendation: Add section on "OAuth in REST APIs"

### Recommendations

1. **Create definition**: Add "Token Lifecycle" doc covering refresh tokens, rotation
2. **Add cross-reference**: Link OAuth guide from REST API docs
3. **Update stale doc**: docs/auth/deprecated-methods.md (180 days old, neighbors updated)
```

### SVG/PNG (Visualization Exports)

**Use Case**: Embedding in docs, presentations, reports.

**Generation**:
```python
# Export force-directed graph as SVG
viz = await kg.visualize("authentication", radius=2)
viz.save_image("auth-graph.svg", format="svg")

# High-res PNG for presentations
viz.save_image("auth-graph.png", format="png", dpi=300, width=1920, height=1080)

# Graphviz hierarchical layout
viz_tree = await kg.visualize_hierarchy("docs/auth.md")
viz_tree.save_image("auth-tree.svg", format="svg")
```

**Features**:
- **SVG**: Vector format, scalable, can embed in web pages
- **PNG**: Raster format, good for presentations/Word docs
- **Options**: Width, height, DPI, background color, label size

### CSV (Data Export)

**Use Case**: Excel analysis, data science, external processing.

**Node Export**:
```csv
id,type,name,pagerank,mention_count,cluster_id
doc_auth_md,DOCUMENT,docs/auth.md,0.042,,cluster_security
concept_oauth,CONCEPT,OAuth 2.0,,8,
concept_jwt,CONCEPT,JWT Token,,6,
doc_oauth_md,DOCUMENT,docs/auth/oauth.md,0.031,,cluster_security
```

**Edge Export**:
```csv
source,target,type,weight,context
doc_auth_md,doc_oauth_md,LINKS_TO,1.0,"See OAuth 2.0 guide for details"
doc_auth_md,concept_oauth,MENTIONS,0.85,"OAuth 2.0 provides secure authorization"
doc_oauth_md,concept_jwt,MENTIONS,0.72,"OAuth uses JWT tokens for access"
```

**Generation**:
```python
# Export nodes
await kg.export_nodes("nodes.csv", format="csv")

# Export edges
await kg.export_edges("edges.csv", format="csv")

# Export full graph (nodes + edges in separate files)
await kg.export_graph("./graph-export/", format="csv")
```

### Neo4j Cypher (Database Import)

**Use Case**: Import into Neo4j for advanced querying/visualization.

**Generation**:
```python
await kg.export_neo4j("graph.cypher")
```

**Output**:
```cypher
// Create document nodes
CREATE (:Document {id: 'doc_auth_md', path: 'docs/auth.md', title: 'Authentication Overview', pagerank: 0.042});
CREATE (:Document {id: 'doc_oauth_md', path: 'docs/auth/oauth.md', title: 'OAuth 2.0 Guide', pagerank: 0.031});

// Create concept nodes
CREATE (:Concept {id: 'concept_oauth', name: 'OAuth 2.0', mentionCount: 8, centrality: 0.234});

// Create relationships
MATCH (a:Document {id: 'doc_auth_md'}), (b:Document {id: 'doc_oauth_md'})
CREATE (a)-[:LINKS_TO {weight: 1.0, context: 'See OAuth 2.0 guide'}]->(b);

MATCH (d:Document {id: 'doc_auth_md'}), (c:Concept {id: 'concept_oauth'})
CREATE (d)-[:MENTIONS {weight: 0.85, count: 12}]->(c);
```

**Usage**:
```bash
# Import into Neo4j
cat graph.cypher | cypher-shell -u neo4j -p password

# Or via Neo4j Browser
# Open Neo4j Browser → paste Cypher → run
```

### Gephi GEXF (Network Analysis)

**Use Case**: Advanced network analysis, custom layouts, publication-quality visualizations.

**Generation**:
```python
await kg.export_gephi("graph.gexf")
```

**Output**: XML format compatible with Gephi

**Usage**:
1. Open Gephi
2. File → Open → select graph.gexf
3. Run layout algorithms (ForceAtlas2, Fruchterman-Reingold)
4. Apply community detection (modularity)
5. Export publication-ready SVG/PDF

---

## 7. Code Examples

### Example 1: CLI Implementation (Python + Typer)

```python
import typer
from typing import Optional, List
from mdcontext_kg import KnowledgeGraph, NodeType

app = typer.Typer()

# Global graph instance (loaded once)
kg: Optional[KnowledgeGraph] = None

@app.callback()
def load_graph(
    graph_path: str = typer.Option("./kg-data", help="Path to knowledge graph data")
):
    """Knowledge Graph CLI - Query and explore documentation relationships"""
    global kg
    kg = KnowledgeGraph.load(graph_path)
    typer.echo(f"✅ Loaded knowledge graph from {graph_path}")

@app.command()
def search(
    query: str = typer.Argument(..., help="Search query"),
    type: Optional[NodeType] = typer.Option(None, help="Node type filter"),
    limit: int = typer.Option(20, help="Max results"),
    format: str = typer.Option("text", help="Output format (text|json|markdown)")
):
    """Search for documents, concepts, or sections"""

    results = kg.search(query, node_type=type, limit=limit)

    if format == "json":
        import json
        typer.echo(json.dumps(results.to_dict(), indent=2))
    elif format == "markdown":
        typer.echo(f"# Search Results: {query}\n")
        for node in results:
            typer.echo(f"## {node.name}")
            typer.echo(f"Type: {node.type}, Score: {node.score:.3f}\n")
    else:  # text
        typer.echo(f"🔍 Search Results for '{query}' ({len(results)} matches)\n")
        for i, node in enumerate(results, 1):
            typer.echo(f"{i}. {node.name} (type: {node.type}, score: {node.score:.3f})")

@app.command()
def expand(
    node: str = typer.Argument(..., help="Node to expand from"),
    depth: int = typer.Option(1, help="Expansion depth"),
    rels: Optional[List[str]] = typer.Option(None, help="Relationship types to follow"),
    visualize: bool = typer.Option(False, help="Generate visualization")
):
    """Show nodes related to a given document or concept"""

    neighbors = kg.expand(node, depth=depth, relationships=rels)

    typer.echo(f"📄 Expanding {node} (depth: {depth})\n")

    # Group by relationship type
    by_rel = {}
    for edge in neighbors.edges:
        by_rel.setdefault(edge.type, []).append(edge)

    for rel_type, edges in by_rel.items():
        typer.echo(f"\n{rel_type} ({len(edges)} connections):")
        for edge in edges[:10]:  # Show top 10
            target = neighbors.get_node(edge.target)
            typer.echo(f"  → {target.name} (weight: {edge.weight:.3f})")

    if visualize:
        typer.echo("\n🎨 Generating visualization...")
        viz = kg.visualize_subgraph(neighbors)
        output_path = f"{node.replace('/', '_')}_graph.html"
        viz.save_html(output_path)
        typer.echo(f"✅ Saved to {output_path}")
        typer.launch(output_path)  # Open in browser

@app.command()
def path(
    start: str = typer.Argument(..., help="Start node"),
    end: str = typer.Argument(..., help="End node"),
    max_length: int = typer.Option(5, help="Max path length"),
    show_context: bool = typer.Option(False, help="Show edge context")
):
    """Find path between two nodes"""

    path_result = kg.find_path(start, end, max_length=max_length)

    if not path_result:
        typer.echo(f"❌ No path found between {start} and {end}")
        return

    typer.echo(f"🛤️  Path from {start} → {end} ({path_result.length} hops)\n")

    for hop in path_result.hops:
        typer.echo(f"{hop.source.name}")
        typer.echo(f"  ├─[{hop.relation}]→ ", nl=False)
        if show_context and hop.context:
            typer.echo(f"\n  │  Context: {hop.context[:80]}...")

    typer.echo(f"{path_result.hops[-1].target.name}")
    typer.echo(f"\nTotal weight: {path_result.total_weight:.3f}")

@app.command()
def stats(
    cluster: Optional[str] = typer.Option(None, help="Show stats for specific cluster"),
    pagerank: bool = typer.Option(False, help="Show PageRank rankings"),
    top: int = typer.Option(20, help="Top N nodes to show"),
    communities: bool = typer.Option(False, help="Run community detection")
):
    """Display graph statistics"""

    if cluster:
        stats_obj = kg.stats(cluster=cluster)
    else:
        stats_obj = kg.stats()

    typer.echo("📊 Knowledge Graph Statistics\n")
    typer.echo(f"Nodes:     {stats_obj.node_count:,}")
    typer.echo(f"Edges:     {stats_obj.edge_count:,}")
    typer.echo(f"Avg Path:  {stats_obj.avg_path_length:.2f} hops")
    typer.echo(f"Clustering: {stats_obj.clustering_coeff:.3f}")

    if pagerank:
        typer.echo(f"\n🏆 Top {top} Documents by PageRank:\n")
        top_docs = kg.pagerank(node_type=NodeType.DOCUMENT, top_k=top)
        for i, (doc, score) in enumerate(top_docs, 1):
            typer.echo(f"{i:2d}. {doc.path:50s} ({score:.4f})")

    if communities:
        typer.echo("\n🌐 Detecting Communities...\n")
        comms = kg.detect_communities()
        for comm in comms:
            typer.echo(f"Cluster {comm.id}: {comm.label} ({len(comm.members)} docs)")
            typer.echo(f"  Top concepts: {', '.join(comm.top_concepts[:5])}")

@app.command()
def gaps(
    orphan_concepts: bool = typer.Option(False, help="Find orphan concepts"),
    missing_links: bool = typer.Option(False, help="Find missing cross-references"),
    stale_docs: bool = typer.Option(False, help="Find stale documents"),
    threshold_days: int = typer.Option(90, help="Staleness threshold in days")
):
    """Find documentation gaps"""

    typer.echo("🔍 Documentation Gaps Analysis\n")

    if orphan_concepts:
        orphans = kg.find_orphaned_concepts()
        typer.echo(f"Orphan Concepts ({len(orphans)}):")
        for concept in orphans:
            typer.echo(f"  ⚠️  {concept.name:30s} (mentioned {concept.mention_count}x)")

    if missing_links:
        missing = kg.find_missing_links(threshold=0.75)
        typer.echo(f"\nMissing Cross-References ({len(missing)}):")
        for link in missing:
            typer.echo(f"  📄 {link.source} ↔ {link.target} (similarity: {link.similarity:.2f})")

    if stale_docs:
        stale = kg.find_stale_documents(threshold_days=threshold_days)
        typer.echo(f"\nStale Documents ({len(stale)}):")
        for doc in stale:
            typer.echo(f"  ⏰ {doc.path} ({doc.days_old} days old)")
            typer.echo(f"     Neighbors updated: {doc.updated_neighbors[:3]}")

if __name__ == "__main__":
    app()
```

**Usage**:
```bash
python kg_cli.py search "authentication" --type document --limit 10
python kg_cli.py expand "docs/auth.md" --depth 2 --visualize
python kg_cli.py path "auth.md" "database.md" --show-context
python kg_cli.py stats --pagerank --top 20
python kg_cli.py gaps --orphan-concepts --missing-links
```

### Example 2: API Usage (Python)

```python
import asyncio
from mdcontext_kg import KnowledgeGraph, NodeType

async def main():
    # Load graph
    kg = await KnowledgeGraph.from_mdcontext("~/.mdcontext/indexes/my-project")

    # Example 1: Search for authentication docs
    print("=== Search Results ===")
    results = await kg.search("authentication", node_type=NodeType.DOCUMENT)
    for doc in results[:5]:
        print(f"{doc.name} (score: {doc.score:.3f})")

    # Example 2: Find path between two docs
    print("\n=== Path Finding ===")
    path = await kg.find_path("docs/auth.md", "docs/database.md")
    if path:
        print(f"Path length: {path.length} hops")
        for hop in path.hops:
            print(f"  {hop.source.name} --[{hop.relation}]--> {hop.target.name}")

    # Example 3: Expand from a document
    print("\n=== Expansion ===")
    neighbors = await kg.expand("docs/auth.md", depth=1)
    print(f"Found {len(neighbors.nodes)} related nodes")

    # Group by relationship
    links = [e for e in neighbors.edges if e.type == "LINKS_TO"]
    similar = [e for e in neighbors.edges if e.type == "SIMILAR_TO"]
    print(f"  - Direct links: {len(links)}")
    print(f"  - Similar docs: {len(similar)}")

    # Example 4: PageRank analysis
    print("\n=== PageRank ===")
    top_docs = await kg.pagerank(node_type=NodeType.DOCUMENT, top_k=10)
    for doc, score in top_docs:
        print(f"{doc.path:50s} {score:.4f}")

    # Example 5: Find documentation gaps
    print("\n=== Documentation Gaps ===")
    gaps = await kg.find_gaps()
    print(f"Orphan concepts: {len(gaps.orphan_concepts)}")
    for concept in gaps.orphan_concepts[:5]:
        print(f"  - {concept.name} (mentioned {concept.mention_count}x)")

    # Example 6: Visualize and export
    print("\n=== Visualization ===")
    viz = await kg.visualize(center="authentication", radius=2)
    viz.save_html("auth_graph.html")
    viz.save_image("auth_graph.svg", format="svg")
    print("Saved visualization to auth_graph.html and auth_graph.svg")

    # Example 7: Export for external tools
    print("\n=== Exports ===")
    await kg.export_neo4j("graph.cypher")
    await kg.export_gephi("graph.gexf")
    await kg.export_nodes("nodes.csv", format="csv")
    await kg.export_edges("edges.csv", format="csv")
    print("Exported to Neo4j, Gephi, and CSV formats")

    await kg.close()

if __name__ == "__main__":
    asyncio.run(main())
```

### Example 3: Visualization Generation (JavaScript/D3.js)

```javascript
import * as d3 from 'd3';
import { KnowledgeGraph } from '@mdcontext/kg';

async function visualizeGraph(centerId, radius) {
  // Load graph data
  const kg = await KnowledgeGraph.load('./kg-data');
  const vizData = await kg.visualize({
    center: centerId,
    radius: radius,
    layout: 'force-directed'
  });
  const graphData = vizData.toJSON();

  // Set up SVG
  const width = 1200;
  const height = 800;
  const svg = d3.select('#graph')
    .append('svg')
    .attr('width', width)
    .attr('height', height);

  // Color scale for node types
  const color = d3.scaleOrdinal()
    .domain(['DOCUMENT', 'CONCEPT', 'SECTION', 'CLUSTER'])
    .range(['#3498db', '#e74c3c', '#2ecc71', '#f39c12']);

  // Link color by type
  const linkColor = {
    'LINKS_TO': '#34495e',
    'SIMILAR_TO': '#9b59b6',
    'MENTIONS': '#e67e22',
    'BELONGS_TO': '#95a5a6'
  };

  // Force simulation
  const simulation = d3.forceSimulation(graphData.nodes)
    .force('link', d3.forceLink(graphData.links)
      .id(d => d.id)
      .distance(d => 100 / (d.weight + 0.1))
    )
    .force('charge', d3.forceManyBody().strength(-400))
    .force('center', d3.forceCenter(width / 2, height / 2))
    .force('collision', d3.forceCollide().radius(d => nodeRadius(d) + 5));

  // Node size by PageRank
  const nodeRadius = (d) => 5 + (d.properties.pagerank || 0.01) * 100;

  // Draw links
  const link = svg.append('g')
    .selectAll('line')
    .data(graphData.links)
    .enter().append('line')
      .attr('stroke', d => linkColor[d.type] || '#95a5a6')
      .attr('stroke-opacity', 0.6)
      .attr('stroke-width', d => 1 + d.weight * 3);

  // Draw nodes
  const node = svg.append('g')
    .selectAll('circle')
    .data(graphData.nodes)
    .enter().append('circle')
      .attr('r', nodeRadius)
      .attr('fill', d => color(d.type))
      .attr('stroke', '#fff')
      .attr('stroke-width', 2)
      .call(drag(simulation));

  // Node labels
  const label = svg.append('g')
    .selectAll('text')
    .data(graphData.nodes)
    .enter().append('text')
      .text(d => d.name.split('/').pop())  // Show filename only
      .attr('font-size', 10)
      .attr('dx', d => nodeRadius(d) + 5)
      .attr('dy', 3);

  // Tooltip
  const tooltip = d3.select('body').append('div')
    .attr('class', 'tooltip')
    .style('opacity', 0)
    .style('position', 'absolute')
    .style('background', 'white')
    .style('padding', '10px')
    .style('border', '1px solid #ddd')
    .style('border-radius', '4px');

  node.on('mouseover', (event, d) => {
    tooltip.transition().duration(200).style('opacity', 1);
    tooltip.html(`
      <strong>${d.name}</strong><br/>
      Type: ${d.type}<br/>
      PageRank: ${(d.properties.pagerank || 0).toFixed(4)}<br/>
      ${d.type === 'CONCEPT' ? `Mentions: ${d.properties.mentionCount}` : ''}
    `)
      .style('left', (event.pageX + 10) + 'px')
      .style('top', (event.pageY - 10) + 'px');
  })
  .on('mouseout', () => {
    tooltip.transition().duration(200).style('opacity', 0);
  });

  // Click to expand
  node.on('click', async (event, d) => {
    const neighbors = await kg.expand(d.id, { depth: 1 });

    // Add new nodes and links to simulation
    const newNodes = neighbors.nodes.filter(n =>
      !graphData.nodes.find(existing => existing.id === n.id)
    );
    const newLinks = neighbors.edges.filter(e =>
      !graphData.links.find(existing =>
        existing.source.id === e.source && existing.target.id === e.target
      )
    );

    graphData.nodes.push(...newNodes);
    graphData.links.push(...newLinks);

    // Update simulation
    simulation.nodes(graphData.nodes);
    simulation.force('link').links(graphData.links);
    simulation.alpha(0.3).restart();

    // Redraw
    updateGraph();
  });

  // Update positions on tick
  simulation.on('tick', () => {
    link
      .attr('x1', d => d.source.x)
      .attr('y1', d => d.source.y)
      .attr('x2', d => d.target.x)
      .attr('y2', d => d.target.y);

    node
      .attr('cx', d => d.x)
      .attr('cy', d => d.y);

    label
      .attr('x', d => d.x)
      .attr('y', d => d.y);
  });

  // Drag behavior
  function drag(simulation) {
    function dragstarted(event) {
      if (!event.active) simulation.alphaTarget(0.3).restart();
      event.subject.fx = event.subject.x;
      event.subject.fy = event.subject.y;
    }

    function dragged(event) {
      event.subject.fx = event.x;
      event.subject.fy = event.y;
    }

    function dragended(event) {
      if (!event.active) simulation.alphaTarget(0);
      event.subject.fx = null;
      event.subject.fy = null;
    }

    return d3.drag()
      .on('start', dragstarted)
      .on('drag', dragged)
      .on('end', dragended);
  }

  // Search highlight
  d3.select('#search-input').on('input', function() {
    const query = this.value.toLowerCase();

    node.attr('opacity', d =>
      d.name.toLowerCase().includes(query) ? 1 : 0.2
    );

    link.attr('opacity', d =>
      d.source.name.toLowerCase().includes(query) ||
      d.target.name.toLowerCase().includes(query) ? 0.6 : 0.1
    );
  });

  // Export as SVG
  d3.select('#export-btn').on('click', () => {
    const svgData = svg.node().outerHTML;
    const blob = new Blob([svgData], { type: 'image/svg+xml' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'graph.svg';
    a.click();
  });
}

// Initialize
visualizeGraph('authentication', 2);
```

**HTML**:
```html
<!DOCTYPE html>
<html>
<head>
  <title>Knowledge Graph Visualization</title>
  <script src="https://d3js.org/d3.v7.min.js"></script>
  <style>
    body { margin: 0; font-family: Arial, sans-serif; }
    #controls { padding: 20px; background: #f5f5f5; }
    #search-input { padding: 8px; width: 300px; font-size: 14px; }
    #export-btn { padding: 8px 16px; margin-left: 10px; }
    #graph { border: 1px solid #ddd; }
  </style>
</head>
<body>
  <div id="controls">
    <input id="search-input" placeholder="Search nodes..." />
    <button id="export-btn">Export SVG</button>
  </div>
  <div id="graph"></div>
  <script src="visualize.js"></script>
</body>
</html>
```

---

## Conclusion

This query interface design prioritizes **developer experience** through:

1. **Progressive Complexity**: Simple commands for 80% of use cases, power features for the remaining 20%
2. **Multiple Access Modes**: CLI for quick exploration, Python/TS APIs for programmatic use
3. **Rich Visualizations**: Interactive D3.js graphs for exploration, static exports for documentation
4. **Flexible Output**: JSON for APIs, Markdown for reports, CSV for analysis, SVG/PNG for sharing
5. **Discoverability**: Excellent help text, autocomplete, examples, error messages

**Next Steps**:
1. Build MVP CLI with core commands (`search`, `expand`, `path`, `stats`)
2. Implement Python API with async support
3. Create D3.js visualization template
4. Add TypeScript bindings for web integration
5. Test with real mdcontext index on agentic-flow docs
6. Iterate based on user feedback

The interface makes knowledge graph exploration **accessible** (simple commands), **powerful** (Cypher passthrough), and **visual** (interactive graphs), achieving the "WOW factor" of seeing documentation relationships come to life.

---

## References & Sources

**Query Languages:**
- [Cypher Manual - Neo4j](https://neo4j.com/docs/cypher-manual/current/introduction/)
- [Getting Started with Cypher - Neo4j](https://neo4j.com/docs/getting-started/cypher/)
- [Graph Query Language - Gremlin | Apache TinkerPop](https://tinkerpop.apache.org/gremlin.html)
- [Apache TinkerPop Documentation](https://tinkerpop.apache.org/docs/current/reference/)
- [SPARQL Query Language for RDF - W3C](https://www.w3.org/TR/sparql11-query/)
- [SPARQL 1.2 Query Language](https://w3c.github.io/sparql-query/spec/)

**Graph Visualization:**
- [You Want a Fast, Easy-To-Use, and Popular Graph Visualization Tool? Pick Two! - Memgraph](https://memgraph.com/blog/you-want-a-fast-easy-to-use-and-popular-graph-visualization-tool)
- [cytoscape vs vis-network vs d3-graphviz Comparison - npm-compare](https://npm-compare.com/cytoscape,d3-graphviz,vis-network)
- [Top 10 JavaScript Libraries for Knowledge Graph Visualization - Focal](https://www.getfocal.co/post/top-10-javascript-libraries-for-knowledge-graph-visualization)
- [D3.js Official Site](https://d3js.org/)
- [15 Best Graph Visualization Tools for Neo4j - Neo4j Blog](https://neo4j.com/blog/graph-visualization/neo4j-graph-visualization-tools/)
- [Visualize your data in Neo4j - Getting Started](https://neo4j.com/docs/getting-started/graph-visualization/graph-visualization/)
- [Neo4j Browser Manual - Visual Tour](https://neo4j.com/docs/browser-manual/current/visual-tour/)

**CLI Design:**
- [Command Line Interface Guidelines](https://clig.dev/)
- [Better CLI - CLI Design Guide & Reference](https://bettercli.org/)
- [10 design principles for delightful CLIs - Atlassian](https://www.atlassian.com/blog/it-teams/10-design-principles-for-delightful-clis)
- [Elevate developer experiences with CLI design guidelines - Thoughtworks](https://www.thoughtworks.com/en-us/insights/blog/engineering-effectiveness/elevate-developer-experiences-cli-design-guidelines)
- [cli-guidelines on GitHub](https://github.com/cli-guidelines/cli-guidelines)

**DSL Design:**
- [Notable design patterns for domain-specific languages - ResearchGate](https://www.researchgate.net/publication/222527268_Notable_design_patterns_for_domain-specific_languages)
- [Domain-Specific Languages for Algorithmic Graph Processing - MDPI](https://www.mdpi.com/1999-4893/18/7/445)
- [The complete guide to Domain Specific Languages - Strumenta](https://tomassetti.me/domain-specific-languages/)
- [DSL Design Patterns - Kinda Technical](https://kindatechnical.com/domain-specific-languages/dsl-design-patterns.html)

**Python CLI Frameworks:**
- [Navigating the CLI Landscape in Python - Medium](https://medium.com/@mohd_nass/navigating-the-cli-landscape-in-python-a-comparative-study-of-argparse-click-and-typer-480ebbb7172f)
- [Typer - Alternatives, Inspiration and Comparisons](https://typer.tiangolo.com/alternatives/)
- [Click vs Typer Comparison - Johal.in](https://johal.in/click-vs-typer-comparison-choosing-cli-frameworks-for-python-application-distribution/)
- [Comparing Python CLI Tools - CodeCut](https://codecut.ai/comparing-python-command-line-interface-tools-argparse-click-and-typer/)

**Graph Layouts:**
- [Force-Directed Graphs with D3.js - David Graus](https://graus.nu/blog/force-directed-graphs-playing-around-with-d3-js/)
- [D3.js vs Graphviz Comparison - Appmus](https://appmus.com/vs/d3-js-vs-graphviz)
- [Layout Engines - Graphviz](https://graphviz.org/docs/layouts/)
- [The Sugiyama Method - Layered Graph Drawing - Disy](https://blog.disy.net/sugiyama-method/)

---

**Document Version**: 1.0
**Date**: 2026-01-26
**Author**: Claude Sonnet 4.5 (via Claude Code)
**Project**: mdcontext Knowledge Graph - Query Interface Design
