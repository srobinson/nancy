# Knowledge Graph Construction: A Novel Validation Strategy for mdcontext

## Executive Summary

This proposal presents a **Knowledge Graph Construction** approach to validate mdcontext's ability to navigate and extract meaningful relationships from 2000+ markdown documentation files in the agentic-flow project. By constructing a multi-layered knowledge graph that captures semantic relationships, structural patterns, and cross-document linkages, we can demonstrate mdcontext's unique value proposition: transforming unstructured documentation into a queryable knowledge network that answers complex, multi-hop questions impossible to solve with traditional search.

The "WOW factor": **mdcontext doesn't just find documents—it discovers how knowledge flows through your documentation.**

## 1. Vision: Why Knowledge Graphs Prove mdcontext's Value

### The Problem with Traditional Documentation Search

Traditional documentation tools treat each file as an isolated entity. You can search for keywords, but you can't ask:
- "What are all the authentication methods that depend on session management?"
- "Which configuration options cascade through multiple subsystems?"
- "What is the conceptual hierarchy of features mentioned across 50+ files?"

### mdcontext as Knowledge Infrastructure

mdcontext's architecture—combining semantic search, link analysis, and structured extraction—positions it as **ideal infrastructure for knowledge graph construction**. The knowledge graph becomes:

1. **Proof of Comprehension**: If mdcontext can build accurate graphs, it understands document relationships
2. **Proof of Utility**: Complex queries answerable via graphs demonstrate real-world value
3. **Proof of Scale**: Graph quality at 2000+ docs proves enterprise-readiness

### Inspiration from Industry Leaders

Modern knowledge management platforms demonstrate graph-based navigation's power:

- **Neo4j** uses knowledge graphs for 20 million+ document collections at Cisco, enabling metadata-driven search and GraphRAG for GenAI applications
- **Obsidian/Roam Research** provide bidirectional linking with real-time graph visualization, helping users identify hidden patterns and thought clusters
- **Microsoft GraphRAG** structures documentation hierarchically, enabling both local (specific entity) and global (holistic) queries with community detection algorithms

mdcontext can combine these approaches: Neo4j's scale, Obsidian's relationship discovery, and GraphRAG's hierarchical reasoning.

## 2. Approach: Graph Structure Design

### Graph Schema

#### Node Types

1. **Document Nodes**
   - Properties: `filePath`, `title`, `tokens`, `lastModified`, `topicCluster`
   - Represents: Individual markdown files

2. **Section Nodes**
   - Properties: `heading`, `level`, `tokens`, `parentSection`, `docPath`
   - Represents: H1-H6 headings within documents

3. **Concept Nodes**
   - Properties: `name`, `type` (feature|config|api|pattern|error), `firstMention`, `frequency`
   - Represents: Extracted concepts (e.g., "authentication", "rate-limiting", "webhook")

4. **Topic Cluster Nodes**
   - Properties: `clusterID`, `label`, `coherenceScore`, `memberCount`
   - Represents: Semantic communities detected via embedding clustering

5. **Keyword Nodes**
   - Properties: `term`, `stemmed`, `idf`, `documentFrequency`
   - Represents: Important keywords for BM25-style retrieval

#### Edge Types

1. **LINKS_TO** (Document → Document)
   - Properties: `linkType` (explicit|implicit), `context` (surrounding text)
   - Weight: Link strength (1.0 for explicit markdown links, 0.3-0.8 for semantic similarity)

2. **CONTAINS** (Document → Section)
   - Properties: `order`, `depth`
   - Weight: Structural importance (higher for top-level sections)

3. **MENTIONS** (Section → Concept)
   - Properties: `count`, `positions`, `sentimentContext`
   - Weight: TF-IDF score of concept in section

4. **RELATED_TO** (Concept → Concept)
   - Properties: `cooccurrenceCount`, `semanticSimilarity`, `relationshipType` (depends-on|configures|implements|extends)
   - Weight: Relationship strength (0-1 scale)

5. **BELONGS_TO** (Document → TopicCluster)
   - Properties: `membershipStrength`, `rank`
   - Weight: Cosine similarity to cluster centroid

6. **SIMILAR_TO** (Document → Document)
   - Properties: `cosineSimilarity`, `sharedConcepts`, `sharedKeywords`
   - Weight: Semantic similarity score

### Graph Construction Pipeline

```
Phase 1: Node Extraction
├── Index markdown files with mdcontext
├── Extract documents, sections, headings
├── Identify concepts via NER + keyword extraction
└── Cluster documents by semantic similarity (HNSW vectors)

Phase 2: Edge Construction
├── Explicit edges from markdown links
├── Semantic edges from embedding similarity (threshold: 0.65+)
├── Concept co-occurrence analysis
└── Dependency inference (e.g., "requires", "depends on", "see also")

Phase 3: Graph Enrichment
├── Community detection (Louvain algorithm)
├── PageRank for document importance
├── Centrality metrics for key concepts
└── Path analysis for knowledge flows

Phase 4: Validation
├── Cross-reference against ground truth relationships
├── Query answering accuracy (see test cases)
├── Graph coherence metrics
└── Human expert review of subgraphs
```

### Technology Stack

- **Graph Database**: Neo4j or in-memory graph structure (NetworkX for Python, graphology for JS)
- **Vector Search**: mdcontext's existing HNSW index
- **NER/Concept Extraction**: spaCy or keyword extraction via mdcontext's BM25 index
- **Community Detection**: Louvain method or connected components
- **Visualization**: Neo4j Bloom, vis.js, or D3.js force-directed graphs

## 3. Metrics: Measuring Success

### Graph Quality Metrics

#### Structural Metrics

1. **Graph Completeness**
   - Node coverage: % of documents/sections represented
   - Edge density: Actual edges / possible edges
   - Connected component ratio: % of nodes in largest component
   - **Target**: >95% node coverage, >80% single component

2. **Graph Coherence**
   - Clustering coefficient: How well nodes cluster together
   - Average path length: Average hops between any two nodes
   - Modularity: Quality of community detection
   - **Target**: Clustering coefficient >0.3, modularity >0.4

#### Semantic Metrics

3. **Link Precision & Recall**
   - **Precision**: % of predicted links that are correct (validated against ground truth)
   - **Recall**: % of ground truth links that were found
   - **F1 Score**: Harmonic mean of precision/recall
   - **Target**: F1 >0.75 for explicit links, F1 >0.60 for semantic links

4. **Concept Extraction Quality**
   - **Accuracy**: % of extracted concepts that are valid domain concepts
   - **Coverage**: % of manually identified concepts that were auto-detected
   - **Target**: Accuracy >0.80, coverage >0.70

5. **Clustering Coherence**
   - **Silhouette Score**: How well documents fit their clusters (-1 to 1)
   - **Intra-cluster similarity**: Average similarity within clusters
   - **Inter-cluster distance**: Separation between clusters
   - **Target**: Silhouette >0.4, intra-cluster sim >0.65

### Query Performance Metrics

6. **Query Answering Accuracy**
   - **Correctness**: % of test queries answered correctly
   - **Completeness**: % of expected results returned
   - **Relevance**: Mean Reciprocal Rank (MRR) of results
   - **Target**: >85% correctness, >80% completeness, MRR >0.75

7. **Multi-Hop Query Performance**
   - **Path accuracy**: % of relationship paths that are correct
   - **Path completeness**: % of valid paths discovered
   - **Target**: >75% for 2-hop queries, >60% for 3+ hop queries

### Comparative Metrics

8. **Baseline Comparison**
   - Compare knowledge graph queries vs. naive keyword search
   - Compare vs. semantic search without graph structure
   - **Target**: >40% improvement in multi-hop query accuracy

### Hallucination & Omission Metrics

9. **Hallucination Rate**
   - % of graph edges/nodes that don't reflect actual documentation content
   - **Target**: <5% hallucination rate

10. **Omission Rate**
    - % of critical relationships missing from graph (vs. expert-labeled ground truth)
    - **Target**: <15% omission rate

## 4. Test Cases: Concrete Queries

### Category A: Relationship Discovery (2-hop queries)

**Test Case 1: Dependency Chains**
```
Query: "What features depend on the session management system?"

Expected Graph Traversal:
1. Find [session management] concept node
2. Traverse MENTIONED_IN edges to sections
3. Find sections with "depends on", "requires", "uses" context
4. Return parent documents + relationship type

Success Criteria:
- Returns all docs explicitly mentioning session deps (precision >0.85)
- Ranks by dependency strength (NDCG >0.80)
- Identifies implicit dependencies via co-occurrence (recall >0.70)
```

**Test Case 2: Configuration Cascades**
```
Query: "Which configuration options affect database connection pooling?"

Expected Graph Traversal:
1. Find [database connection pooling] concept
2. Find [configuration] concept nodes with RELATED_TO edges
3. Trace MENTIONS edges to sections discussing config
4. Cluster by config category (env vars, yaml, runtime)

Success Criteria:
- Identifies all 15-20 related config options (recall >0.80)
- Distinguishes direct vs. indirect config effects (precision >0.75)
- Provides config hierarchy (parent-child relationships)
```

### Category B: Conceptual Hierarchies (multi-hop queries)

**Test Case 3: Feature Taxonomy**
```
Query: "Build the conceptual hierarchy of authentication features"

Expected Graph Traversal:
1. Find all [authentication] concept mentions
2. Detect parent-child via heading structure (CONTAINS edges)
3. Cluster by semantic similarity (SIMILAR_TO edges)
4. Build tree: Authentication → {OAuth, JWT, Session, API Keys} → {specific methods}

Success Criteria:
- Produces hierarchical tree with 3-4 levels
- Correctly identifies 90%+ of auth-related docs
- Ranks feature importance by PageRank (top features match expert judgment)
```

**Test Case 4: API Relationship Mapping**
```
Query: "How are REST API endpoints organized across services?"

Expected Graph Traversal:
1. Find documents in [api] topic cluster
2. Extract concept nodes for endpoints (regex patterns)
3. Build service → endpoint → dependencies graph
4. Detect shared patterns (e.g., common middleware, auth)

Success Criteria:
- Maps all documented endpoints to services (>95% coverage)
- Identifies shared patterns/conventions (precision >0.80)
- Produces service dependency graph
```

### Category C: Cross-Cutting Concerns (3+ hop queries)

**Test Case 5: Error Propagation Paths**
```
Query: "If database timeout occurs, which systems are affected and in what order?"

Expected Graph Traversal:
1. Find [database timeout] concept → sections mentioning errors
2. Traverse RELATED_TO edges to dependent systems
3. Follow LINKS_TO edges for error handling docs
4. Build propagation graph with temporal ordering

Success Criteria:
- Identifies 80%+ of affected systems
- Orders by dependency depth (immediate vs. cascading failures)
- Links to error handling documentation
```

**Test Case 6: Implementation Pattern Analysis**
```
Query: "What retry/backoff strategies are used across different features?"

Expected Graph Traversal:
1. Find [retry] and [backoff] concept nodes
2. Traverse MENTIONS to all implementing sections
3. Extract pattern details (exponential, linear, jittered)
4. Cluster by similarity + provide comparative analysis

Success Criteria:
- Finds all 10-15 retry implementations
- Correctly classifies retry types (precision >0.85)
- Identifies inconsistencies/outliers
```

### Category D: Knowledge Gaps (negative queries)

**Test Case 7: Orphan Detection**
```
Query: "Which major concepts are mentioned but never fully documented?"

Expected Graph Traversal:
1. Find concept nodes with high MENTIONS count
2. Filter where concept is never in section heading
3. Filter where concept has no dedicated document
4. Rank by mention frequency + lack of documentation depth

Success Criteria:
- Identifies 5-10 underdocumented concepts
- Prioritizes by business criticality (inferred from link centrality)
- Provides evidence (mention locations + contexts)
```

**Test Case 8: Broken Knowledge Flows**
```
Query: "Find documentation gaps where concepts are introduced but never explained"

Expected Graph Traversal:
1. Find concept first mentions in documents
2. Check if concept has definition section (CONTAINS edge to "Definition" heading)
3. Check if concept has LINKS_TO edge to explanatory doc
4. Return concepts with no explanation path

Success Criteria:
- Finds 90%+ of concepts lacking definitions
- Distinguishes "intentionally brief" vs. "missing" (using heuristics)
- Ranks by how critical the gap is (PageRank of concept)
```

### Category E: Temporal/Change Analysis

**Test Case 9: Documentation Freshness**
```
Query: "Which high-importance documents haven't been updated while related docs have?"

Expected Graph Traversal:
1. Rank documents by PageRank (importance)
2. For top 20%, check lastModified dates of SIMILAR_TO neighbors
3. Flag docs where neighbors updated recently but doc is stale
4. Provide suggested update priorities

Success Criteria:
- Identifies stale docs with >90% accuracy (vs. manual review)
- Ranks by update urgency (combination of importance + staleness)
- Suggests related docs to reference for updates
```

**Test Case 10: Concept Evolution Tracking**
```
Query: "How has the concept of 'agent orchestration' evolved across documentation versions?"

Expected Graph Traversal:
1. Find all [agent orchestration] mentions across doc history (requires git integration)
2. Build temporal graph of concept mentions
3. Detect new related concepts over time (RELATED_TO edge additions)
4. Produce concept evolution timeline

Success Criteria:
- Accurately tracks concept introduction/changes
- Identifies 5-8 related concepts added over time
- Visualizes evolution as timeline graph
```

## 5. Implementation: High-Level Steps

### Phase 1: Foundation (Week 1-2)

**Goal**: Build basic graph structure from existing mdcontext indexes

1. **Extract Nodes**
   ```bash
   mdcontext index ./agentic-flow --embed
   # Parse index to extract:
   # - Document nodes from documents.json
   # - Section nodes from sections.json
   # - Concept candidates from high-IDF keywords
   ```

2. **Build Explicit Edges**
   ```bash
   mdcontext links --all-files > links.json
   mdcontext backlinks --all-files > backlinks.json
   # Create LINKS_TO edges from markdown link analysis
   ```

3. **Graph Storage**
   - Decide: Neo4j (rich queries, visualization) vs. in-memory (fast prototyping)
   - Initialize graph schema
   - Import nodes/edges
   - Run basic graph stats (node count, edge count, density)

**Deliverable**: Working graph with 2000+ document nodes and explicit link edges

### Phase 2: Semantic Enrichment (Week 2-3)

**Goal**: Add semantic edges and concept nodes

4. **Concept Extraction**
   ```python
   # For each document:
   # 1. Extract top-N keywords (BM25 + TF-IDF)
   # 2. Run simple NER for proper nouns
   # 3. Pattern match for: config vars, API endpoints, error codes
   # 4. Deduplicate/normalize (stemming, case)
   # 5. Create concept nodes + MENTIONS edges
   ```

5. **Semantic Similarity Edges**
   ```python
   # Use mdcontext's HNSW index:
   for doc in documents:
       neighbors = mdcontext.search_similar(doc.embedding, k=10, threshold=0.65)
       for neighbor, similarity in neighbors:
           graph.add_edge(doc, neighbor, weight=similarity, type='SIMILAR_TO')
   ```

6. **Concept Relationships**
   ```python
   # Co-occurrence analysis:
   for section in sections:
       concepts_in_section = find_concepts(section)
       for c1, c2 in combinations(concepts_in_section, 2):
           graph.add_edge(c1, c2, weight=cooccurrence_count, type='RELATED_TO')
   ```

**Deliverable**: Graph with 500+ concept nodes and 5000+ semantic edges

### Phase 3: Clustering & Hierarchy (Week 3-4)

**Goal**: Detect communities and build hierarchies

7. **Topic Clustering**
   ```python
   # Cluster documents by embeddings:
   # - Use Louvain algorithm for community detection
   # - Alternative: K-means on embeddings (k=20-50)
   # - Label clusters via most frequent concepts
   # - Create TopicCluster nodes + BELONGS_TO edges
   ```

8. **Concept Hierarchy**
   ```python
   # Build concept taxonomy:
   # 1. Use heading structure as proxy for hierarchy
   #    (e.g., "## Authentication" contains "### OAuth")
   # 2. Detect parent-child via common patterns:
   #    "X is a type of Y", "X includes Y", etc.
   # 3. Add IS_A/PART_OF edge types
   ```

9. **Importance Scoring**
   ```python
   # Run PageRank on document nodes:
   # - High PageRank = central, well-linked docs
   # - Use to prioritize ground truth validation
   # Store as node property
   ```

**Deliverable**: Graph with hierarchical structure and importance metrics

### Phase 4: Validation & Testing (Week 4-5)

**Goal**: Validate graph quality and query performance

10. **Ground Truth Creation**
    - Manually review top 50 documents (by PageRank)
    - Label 200-300 concept relationships
    - Label 100-150 document relationships
    - Create gold standard for precision/recall

11. **Run Test Cases**
    ```python
    for test_case in test_cases:
        results = execute_graph_query(test_case.cypher_query)
        ground_truth = test_case.expected_results
        metrics = calculate_metrics(results, ground_truth)
        log_results(test_case.id, metrics)
    ```

12. **Metric Calculation**
    - Graph structural metrics (density, clustering coefficient, etc.)
    - Query performance (precision, recall, F1, MRR)
    - Comparative analysis (graph vs. non-graph search)

13. **Iteration**
    - Identify failure modes (e.g., low recall on implicit relationships)
    - Tune thresholds (similarity cutoffs, co-occurrence minimums)
    - Enhance concept extraction (add domain-specific patterns)
    - Re-run tests until targets met

**Deliverable**: Validated knowledge graph with documented metrics

### Phase 5: Visualization & Demonstration (Week 5-6)

**Goal**: Create compelling visualizations for stakeholders

14. **Interactive Graph Visualization**
    ```javascript
    // Use vis.js or Neo4j Bloom:
    // - Full graph view (2000+ nodes, force-directed layout)
    // - Filtered views (topic clusters, concept neighborhoods)
    // - Query result highlighting
    // - Temporal sliders (if git history integrated)
    ```

15. **Query Interface**
    ```python
    # Build simple CLI/web interface:
    # - Natural language query → Cypher translation
    # - Execute query → visualize subgraph
    # - Export results as markdown summary
    # Integration: mdcontext search --graph "query"
    ```

16. **Demo Scenarios**
    - Live demo of 5-10 test cases
    - Show "before/after" (keyword search vs. graph query)
    - Highlight discovered insights (orphan concepts, broken flows)
    - Export graph statistics report

**Deliverable**: Polished demo with visualizations and metrics report

### Phase 6: Documentation & Handoff (Week 6)

**Goal**: Comprehensive documentation for reproducibility

17. **Write Technical Report**
    - Graph schema documentation
    - Implementation details (algorithms, thresholds, hyperparameters)
    - Metric results with statistical analysis
    - Failure modes and future improvements

18. **Create Reproducibility Guide**
    ```markdown
    # Reproducing the Knowledge Graph
    1. Prerequisites: mdcontext installed, agentic-flow docs indexed
    2. Run extraction scripts: `python extract_graph.py`
    3. Import to Neo4j: `python import_neo4j.py`
    4. Run validation: `python validate_graph.py`
    5. Generate visualizations: `python visualize.py`
    ```

19. **Integration Proposal**
    - How to integrate graph into mdcontext core
    - API design for graph queries
    - Performance considerations (latency, memory)
    - Maintenance plan (incremental updates)

**Deliverable**: Complete documentation package + reproducible scripts

## 6. Expected Outcomes & "WOW" Moments

### Quantitative Results

- **Graph Scale**: 2000+ document nodes, 10,000+ edges, 500+ concept nodes
- **Query Performance**: 85%+ accuracy on complex multi-hop queries
- **Efficiency**: 80%+ token reduction vs. dumping full documents (mdcontext's core value maintained)
- **Graph Quality**: F1 >0.75 for explicit relationships, >0.60 for inferred relationships

### Qualitative Insights

1. **Hidden Patterns**: Discover undocumented dependencies between features
2. **Documentation Gaps**: Automatically identify orphaned concepts and missing explanations
3. **Knowledge Clusters**: Reveal implicit topic organization (what goes together)
4. **Importance Ranking**: Surface critical documents that deserve most attention

### Stakeholder Impact

- **For Developers**: "This graph just showed me 3 undocumented dependencies I didn't know existed"
- **For Tech Writers**: "I can now see which topics need better linking/explanation"
- **For Product Teams**: "This visualizes how our feature set relates—better than any architecture doc"
- **For AI Engineers**: "This is GraphRAG infrastructure built directly from documentation"

### Competitive Differentiation

Most documentation tools provide:
- Keyword search (Algolia, Elasticsearch)
- Semantic search (Pinecone, Weaviate)
- Static site generation (Docusaurus, VitePress)

**mdcontext + Knowledge Graph provides**:
- All of the above PLUS
- Relationship discovery
- Multi-hop reasoning
- Automatic taxonomy construction
- Gap analysis
- Knowledge flow visualization

This positions mdcontext as **documentation intelligence**, not just documentation search.

## 7. Risk Mitigation

### Technical Risks

**Risk 1: Concept extraction quality is too low**
- Mitigation: Start with high-precision patterns (config vars, API endpoints, explicit definitions)
- Fallback: Use human-labeled seed concepts and expand via similarity
- Validation: Run on small doc set (100 files) before full scale

**Risk 2: Graph becomes too large/slow**
- Mitigation: Use hierarchical approach (high-level graph + detail subgraphs)
- Fallback: Filter edges by importance (only keep top-K neighbors per node)
- Validation: Benchmark Neo4j query performance with 10K+ nodes

**Risk 3: Semantic edges have low precision (too many false positives)**
- Mitigation: Tune similarity threshold conservatively (start at 0.75, lower if recall suffers)
- Fallback: Combine semantic similarity with keyword overlap (require both)
- Validation: Manual review of random sample (100 edges) before full construction

### Evaluation Risks

**Risk 4: Ground truth creation is too expensive**
- Mitigation: Focus on high-value subset (top 50 docs by PageRank)
- Fallback: Use synthetic ground truth (derive from explicit markdown structure)
- Validation: Inter-rater agreement check (2-3 reviewers on 20 docs)

**Risk 5: Test queries don't reflect real use cases**
- Mitigation: Interview agentic-flow users for actual documentation pain points
- Fallback: Use query logs if available, or common doc search patterns
- Validation: Pilot with 2-3 domain experts providing feedback

### Timeline Risks

**Risk 6: 6-week timeline is too aggressive**
- Mitigation: MVP approach—focus on explicit links + semantic similarity only
- Fallback: Phase 3-5 can extend to 8-10 weeks if needed
- Validation: Weekly checkpoints with go/no-go decisions

## 8. Future Extensions

### Integration with mdcontext Core

1. **Graph-Augmented Search**
   ```bash
   mdcontext search "authentication" --graph-expand
   # Returns: Direct matches + 1-hop neighbors + related concepts
   ```

2. **Relationship Queries**
   ```bash
   mdcontext relate "session management" "database"
   # Returns: Shortest path(s) + shared concepts + co-occurrence stats
   ```

3. **Gap Analysis Command**
   ```bash
   mdcontext gaps --orphan-concepts --missing-links
   # Outputs: Automated documentation health report
   ```

### Advanced Features

4. **Temporal Tracking**: Integrate git history to track concept evolution
5. **Interactive Explorer**: Web UI for graph navigation (ala Neo4j Bloom)
6. **LLM Integration**: Use graph as context for RAG (GraphRAG pattern)
7. **Multi-Repo Graphs**: Build cross-project knowledge graphs for monorepo setups

### Research Directions

8. **Automatic Ontology Learning**: Use LLMs to label relationship types (IS_A, PART_OF, DEPENDS_ON)
9. **Quality Prediction**: Train model to predict documentation quality from graph structure
10. **Recommendation Engine**: "If you're reading doc X, you should also read Y" based on graph similarity

## 9. Conclusion

This Knowledge Graph Construction approach transforms mdcontext from a documentation search tool into a **documentation intelligence platform**. By building a rich, queryable graph from 2000+ markdown files, we demonstrate:

1. **Comprehension**: mdcontext understands document relationships at scale
2. **Utility**: Complex queries become trivial with graph structure
3. **Scalability**: Performance and accuracy maintained at enterprise scale
4. **Innovation**: Unique differentiation vs. existing doc tools

The test cases cover relationship discovery, conceptual hierarchies, cross-cutting concerns, knowledge gaps, and temporal analysis—showcasing capabilities impossible with traditional search.

**The ultimate "WOW"**: Show a developer searching for "authentication" and receiving not just matching documents, but a full dependency graph showing what auth touches, what depends on it, what's related, and what's missing from the documentation—all auto-generated from markdown files.

This is mdcontext's vision realized: **Give LLMs exactly the knowledge they need, with the structure they need it in.**

---

## References

**Graph-Based Documentation Management:**
- Neo4j. (2026). *Knowledge Graph Use Cases*. [https://neo4j.com/use-cases/knowledge-graph/](https://neo4j.com/use-cases/knowledge-graph/)
- Neo4j. (2026). *How to Build a Knowledge Graph in 7 Steps*. [https://neo4j.com/blog/knowledge-graph/how-to-build-knowledge-graph/](https://neo4j.com/blog/knowledge-graph/how-to-build-knowledge-graph/)
- Neo4j. (2026). *Building the Enterprise Knowledge Graph*. [https://neo4j.com/blog/building-enterprise-knowledge-graph/](https://neo4j.com/blog/building-enterprise-knowledge-graph/)

**Graph-Based Note-Taking & Navigation:**
- Medium. *Roam Research and Obsidian: A Comprehensive Comparison*. [https://medium.com/@theo-james/roam-research-and-obsidian-a-comprehensive-comparison-for-note-taking-19c591655f84](https://medium.com/@theo-james/roam-research-and-obsidian-a-comprehensive-comparison-for-note-taking-19c591655f84)
- InfraNodus. *Visualize PKM Knowledge Graphs: Obsidian, RoamResearch, Logseq*. [https://infranodus.com/use-case/visualize-knowledge-graphs-pkm](https://infranodus.com/use-case/visualize-knowledge-graphs-pkm)
- ClickUp. *Roam Research vs. Obsidian: Which Note-Taking Tool Is Best?* [https://clickup.com/blog/obsidian-vs-roam-research/](https://clickup.com/blog/obsidian-vs-roam-research/)

**Knowledge Graph Evaluation & Validation:**
- EMSE. *Knowledge Graphs: Quality Assessment*. [https://www.emse.fr/~zimmermann/KGBook/Multifile/quality-assessment/](https://www.emse.fr/~zimmermann/KGBook/Multifile/quality-assessment/)
- ResearchGate. *A Practical Framework for Evaluating the Quality of Knowledge Graph*. [https://www.researchgate.net/publication/338361155_A_Practical_Framework_for_Evaluating_the_Quality_of_Knowledge_Graph](https://www.researchgate.net/publication/338361155_A_Practical_Framework_for_Evaluating_the_Quality_of_Knowledge_Graph)
- Amazon Science. *Efficient Knowledge Graph Accuracy Evaluation*. [https://www.amazon.science/publications/efficient-knowledge-graph-accuracy-evaluation](https://www.amazon.science/publications/efficient-knowledge-graph-accuracy-evaluation)
- Springer. *Enhancing Knowledge Graph Construction: Evaluating with Emphasis on Hallucination, Omission, and Graph Similarity Metrics*. [https://link.springer.com/chapter/10.1007/978-3-031-81221-7_3](https://link.springer.com/chapter/10.1007/978-3-031-81221-7_3)

**Knowledge Graph Testing & Validation Frameworks:**
- PuppyGraph. (2026). *7 Knowledge Graph Examples of 2026*. [https://www.puppygraph.com/blog/knowledge-graph-examples](https://www.puppygraph.com/blog/knowledge-graph-examples)
- AIMultiple. (2026). *In-depth Guide to Knowledge Graph: Use Cases in 2026*. [https://research.aimultiple.com/knowledge-graph/](https://research.aimultiple.com/knowledge-graph/)
- arXiv. *KGValidator: A Framework for Automatic Validation of Knowledge Graph Construction*. [https://arxiv.org/abs/2404.15923](https://arxiv.org/abs/2404.15923)
- ScienceDirect. *Knowledge graph validation by integrating LLMs and human-in-the-loop*. [https://www.sciencedirect.com/science/article/pii/S030645732500086X](https://www.sciencedirect.com/science/article/pii/S030645732500086X)

**GraphRAG & Retrieval-Augmented Generation:**
- arXiv. *Retrieval-Augmented Generation with Graphs (GraphRAG)*. [https://arxiv.org/abs/2501.00309](https://arxiv.org/abs/2501.00309)
- Microsoft. *Welcome - GraphRAG*. [https://microsoft.github.io/graphrag/](https://microsoft.github.io/graphrag/)
- GitHub. *microsoft/graphrag: A modular graph-based Retrieval-Augmented Generation (RAG) system*. [https://github.com/microsoft/graphrag](https://github.com/microsoft/graphrag)
- Neo4j. *What Is GraphRAG?* [https://neo4j.com/blog/genai/what-is-graphrag/](https://neo4j.com/blog/genai/what-is-graphrag/)
- arXiv. *Graph Retrieval-Augmented Generation: A Survey*. [https://arxiv.org/abs/2408.08921](https://arxiv.org/abs/2408.08921)
- Elasticsearch Labs. *Graph RAG: Navigating graphs for Retrieval-Augmented Generation using Elasticsearch*. [https://www.elastic.co/search-labs/blog/rag-graph-traversal](https://www.elastic.co/search-labs/blog/rag-graph-traversal)

---

**Document Version**: 1.0
**Date**: 2026-01-26
**Author**: Claude Sonnet 4.5 (via Claude Code)
**Project**: mdcontext Knowledge Graph Validation Strategy
