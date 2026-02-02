# Graph Construction & Building: Implementation Guide

## Executive Summary

This document provides a detailed implementation guide for constructing and building knowledge graphs from documentation at scale. The focus is on **incremental construction**, **deduplication strategies**, **relationship weighting**, and **performance optimization** to handle 2000+ document collections efficiently.

**Key Principles:**
- **Incremental by design**: Process documents one-by-one, support updates without full rebuilds
- **Intelligent deduplication**: Merge semantically equivalent entities while preserving variations
- **Weighted relationships**: Confidence scores guide traversal and ranking
- **Validation-first**: Consistency checks throughout construction prevent graph corruption

---

## 1. Graph Building Algorithm

### 1.1 Core Construction Flow

```python
class GraphBuilder:
    """
    Incremental knowledge graph builder with deduplication and validation.
    """

    def __init__(self, config):
        self.graph = Graph()  # NetworkX, Neo4j, or custom
        self.entity_index = EntityIndex()  # For fast deduplication
        self.embedding_store = EmbeddingStore()  # HNSW/FAISS for similarity
        self.checkpointer = Checkpointer()  # Resume interrupted builds

        # Configuration
        self.similarity_threshold = config.get('similarity_threshold', 0.85)
        self.batch_size = config.get('batch_size', 50)
        self.confidence_threshold = config.get('confidence_threshold', 0.5)

    def build_from_documents(self, documents: Iterator[Document]):
        """
        Main entry point: build graph from document stream.
        Supports both batch and streaming modes.
        """
        for batch in self._batch(documents, self.batch_size):
            # Checkpoint: resume from here if interrupted
            checkpoint_id = self.checkpointer.save_state(self.graph)

            for doc in batch:
                try:
                    self._process_document(doc)
                except Exception as e:
                    logger.error(f"Failed to process {doc.path}: {e}")
                    continue

            # Batch optimizations
            self._optimize_batch(batch)
            self.checkpointer.commit(checkpoint_id)

        # Post-processing enrichment
        self._enrich_graph()
        return self.graph

    def _process_document(self, doc: Document):
        """
        Process a single document: extract nodes and edges.
        """
        # 1. Create/update document node
        doc_node = self._create_document_node(doc)

        # 2. Extract section nodes
        section_nodes = self._extract_sections(doc)
        for section in section_nodes:
            self.graph.add_node(section)
            self.graph.add_edge(doc_node, section, type='CONTAINS', weight=1.0)

        # 3. Extract concept nodes (with deduplication)
        concepts = self._extract_concepts(doc, section_nodes)
        for concept, mentions in concepts.items():
            concept_node = self._get_or_create_concept(concept)
            for mention in mentions:
                self._add_mention_edge(concept_node, mention)

        # 4. Extract explicit relationships
        explicit_rels = self._extract_explicit_relationships(doc)
        for rel in explicit_rels:
            self._add_relationship_edge(rel)

        # 5. Calculate semantic similarity to existing docs
        if doc.embedding:
            self._add_similarity_edges(doc_node, doc.embedding)
```

### 1.2 Node Creation with Properties

```python
def _create_document_node(self, doc: Document) -> NodeID:
    """
    Create a document node with rich metadata.
    """
    node_id = self.graph.add_node(
        type='Document',
        properties={
            'filePath': doc.path,
            'title': doc.title or self._infer_title(doc.path),
            'tokens': len(doc.content.split()),
            'lastModified': doc.last_modified,
            'hash': doc.content_hash,  # For change detection
            'embedding': doc.embedding,  # Store for similarity
            'topicCluster': None,  # Assigned during enrichment
            'pageRank': None,  # Calculated during enrichment
        }
    )

    # Index for fast lookup
    self.entity_index.add(node_id, doc.path, 'Document')
    return node_id

def _extract_sections(self, doc: Document) -> List[SectionNode]:
    """
    Extract section nodes from document structure (headings).
    """
    sections = []
    for heading in doc.headings:
        section_id = self.graph.add_node(
            type='Section',
            properties={
                'heading': heading.text,
                'level': heading.level,  # H1=1, H2=2, etc.
                'tokens': len(heading.content.split()),
                'parentSection': heading.parent_id,  # For hierarchy
                'docPath': doc.path,
                'order': heading.order,  # Position in document
                'embedding': self._embed_section(heading),
            }
        )
        sections.append(section_id)

    return sections

def _get_or_create_concept(self, concept: str) -> NodeID:
    """
    Get existing concept node or create new one (with deduplication).
    This is the heart of entity resolution.
    """
    # Step 1: Normalize concept
    normalized = self._normalize_concept(concept)

    # Step 2: Check exact match in index
    existing = self.entity_index.lookup(normalized, 'Concept')
    if existing:
        return existing

    # Step 3: Check semantic similarity
    concept_embedding = self._embed_concept(concept)
    similar = self.embedding_store.search(
        concept_embedding,
        k=5,
        threshold=self.similarity_threshold
    )

    if similar:
        # Found similar concept(s) - merge or link?
        best_match, similarity = similar[0]
        if similarity > 0.90:
            # High confidence: this is the same concept
            self._merge_concept_aliases(best_match, concept)
            return best_match
        elif similarity > 0.75:
            # Medium confidence: related but distinct
            # Create new node but add SIMILAR_TO edge
            new_node = self._create_new_concept_node(concept, normalized)
            self.graph.add_edge(
                new_node, best_match,
                type='SIMILAR_TO',
                weight=similarity
            )
            return new_node

    # Step 4: No match found - create new concept
    return self._create_new_concept_node(concept, normalized)

def _create_new_concept_node(self, concept: str, normalized: str) -> NodeID:
    """
    Create a new concept node with metadata.
    """
    concept_type = self._infer_concept_type(concept)

    node_id = self.graph.add_node(
        type='Concept',
        properties={
            'name': concept,
            'normalized': normalized,
            'aliases': [concept],  # Will grow as we merge
            'type': concept_type,  # feature|config|api|pattern|error
            'firstMention': datetime.now(),
            'frequency': 0,  # Incremented on each mention
            'embedding': self._embed_concept(concept),
            'definition': None,  # Extracted if found
        }
    )

    # Index for lookup
    self.entity_index.add(node_id, normalized, 'Concept')
    self.embedding_store.add(node_id, self._embed_concept(concept))

    return node_id
```

### 1.3 Edge Creation with Confidence Scores

```python
def _add_relationship_edge(self, rel: Relationship):
    """
    Add a relationship edge with confidence weighting.
    """
    source = self._get_or_create_concept(rel.source)
    target = self._get_or_create_concept(rel.target)

    # Calculate edge weight based on relationship strength
    weight = self._calculate_relationship_weight(rel)

    # Check if edge already exists
    existing_edge = self.graph.get_edge(source, target, rel.type)
    if existing_edge:
        # Update weight using exponential moving average
        existing_weight = existing_edge['weight']
        new_weight = 0.7 * existing_weight + 0.3 * weight
        self.graph.update_edge(
            source, target, rel.type,
            weight=new_weight,
            count=existing_edge['count'] + 1,
            contexts=existing_edge['contexts'] + [rel.context]
        )
    else:
        # Create new edge
        self.graph.add_edge(
            source, target,
            type=rel.type,  # RELATED_TO, DEPENDS_ON, CONFIGURES, etc.
            weight=weight,
            confidence=rel.confidence,  # 0-1 from extraction
            count=1,
            contexts=[rel.context],  # Store evidence
            source_doc=rel.doc_path,
        )

def _calculate_relationship_weight(self, rel: Relationship) -> float:
    """
    Calculate edge weight combining multiple signals.

    Weight components:
    - Confidence from extraction (0-1)
    - Relationship type strength (explicit > implicit)
    - Contextual evidence (proximity, co-occurrence)
    - Source document authority (PageRank)
    """
    weight = rel.confidence  # Base weight

    # Boost for explicit relationships (markdown links, definitions)
    if rel.is_explicit:
        weight *= 1.5

    # Boost for strong relationship types
    type_weights = {
        'DEPENDS_ON': 1.3,
        'REQUIRES': 1.3,
        'CONFIGURES': 1.2,
        'IMPLEMENTS': 1.2,
        'EXTENDS': 1.1,
        'RELATED_TO': 1.0,
        'MENTIONS': 0.8,
    }
    weight *= type_weights.get(rel.type, 1.0)

    # Consider proximity (concepts mentioned close together)
    if rel.token_distance < 50:
        weight *= 1.2
    elif rel.token_distance < 200:
        weight *= 1.1

    # Cap at 1.0
    return min(weight, 1.0)

def _add_similarity_edges(self, doc_node: NodeID, embedding: np.ndarray):
    """
    Add semantic similarity edges to related documents.
    """
    similar_docs = self.embedding_store.search(
        embedding,
        k=10,  # Top 10 most similar
        threshold=0.65  # Minimum similarity
    )

    for similar_id, similarity in similar_docs:
        if similar_id == doc_node:
            continue

        # Calculate shared concepts for additional signal
        shared_concepts = self._count_shared_concepts(doc_node, similar_id)

        # Adjust weight based on shared concepts
        adjusted_weight = similarity * (1 + 0.1 * min(shared_concepts, 5))
        adjusted_weight = min(adjusted_weight, 1.0)

        self.graph.add_edge(
            doc_node, similar_id,
            type='SIMILAR_TO',
            weight=adjusted_weight,
            cosineSimilarity=similarity,
            sharedConcepts=shared_concepts,
        )
```

---

## 2. Deduplication Logic

### 2.1 Entity Normalization

```python
def _normalize_concept(self, concept: str) -> str:
    """
    Normalize concept for deduplication.

    Handles:
    - Case variations (OAuth vs oauth)
    - Punctuation (rate-limiting vs rate_limiting)
    - Pluralization (session vs sessions)
    - Whitespace
    """
    # Basic normalization
    normalized = concept.lower().strip()

    # Remove punctuation (but preserve meaning)
    normalized = re.sub(r'[-_/]', ' ', normalized)
    normalized = re.sub(r'[^\w\s]', '', normalized)

    # Stemming (careful: can lose meaning)
    # "authentication" -> "authent"
    # Only use for index, keep original for display
    stemmed = self.stemmer.stem(normalized)

    # Singularization
    singular = self.lemmatizer.lemmatize(normalized)

    # Store all forms for lookup
    return singular

def _merge_concept_aliases(self, primary_node: NodeID, alias: str):
    """
    Merge an alias into existing concept node.
    """
    node = self.graph.get_node(primary_node)
    aliases = node['aliases']

    if alias not in aliases:
        aliases.append(alias)
        node['aliases'] = aliases

        # Update frequency (this concept is mentioned more)
        node['frequency'] += 1

        # Update index to point to canonical node
        normalized = self._normalize_concept(alias)
        self.entity_index.add_alias(primary_node, normalized)
```

### 2.2 Semantic Deduplication

```python
class EntityIndex:
    """
    Fast lookup index for entity deduplication.
    Combines exact matching + fuzzy matching + semantic matching.
    """

    def __init__(self):
        self.exact_index = {}  # normalized -> NodeID
        self.fuzzy_index = FuzzyIndex()  # For typo tolerance
        self.semantic_index = None  # Set by GraphBuilder

    def lookup(self, normalized: str, node_type: str) -> Optional[NodeID]:
        """
        Multi-stage lookup: exact -> fuzzy -> semantic.
        """
        # Stage 1: Exact match
        key = f"{node_type}:{normalized}"
        if key in self.exact_index:
            return self.exact_index[key]

        # Stage 2: Fuzzy match (Levenshtein distance < 2)
        fuzzy_matches = self.fuzzy_index.search(normalized, max_dist=2)
        if fuzzy_matches:
            # Return best match if confident
            best_match, distance = fuzzy_matches[0]
            if distance == 1:  # One character difference
                return best_match

        # Stage 3: Semantic match (handled by GraphBuilder)
        return None

    def add(self, node_id: NodeID, normalized: str, node_type: str):
        """Add node to index."""
        key = f"{node_type}:{normalized}"
        self.exact_index[key] = node_id
        self.fuzzy_index.add(normalized, node_id)

    def add_alias(self, node_id: NodeID, alias: str):
        """Add alias pointing to existing node."""
        self.exact_index[alias] = node_id
        self.fuzzy_index.add(alias, node_id)
```

### 2.3 Merge Strategy for Conflicts

```python
def merge_concepts(self, node1: NodeID, node2: NodeID) -> NodeID:
    """
    Merge two concept nodes when determined to be duplicates.

    Strategy:
    - Keep node with more connections (higher degree)
    - Merge aliases, frequencies, and properties
    - Redirect all edges to primary node
    - Mark secondary node as merged (don't delete for audit trail)
    """
    n1 = self.graph.get_node(node1)
    n2 = self.graph.get_node(node2)

    # Determine primary node (keep one with more connections)
    degree1 = self.graph.degree(node1)
    degree2 = self.graph.degree(node2)

    primary, secondary = (node1, node2) if degree1 >= degree2 else (node2, node1)
    primary_data = self.graph.get_node(primary)
    secondary_data = self.graph.get_node(secondary)

    # Merge aliases
    primary_data['aliases'].extend(secondary_data['aliases'])
    primary_data['aliases'] = list(set(primary_data['aliases']))

    # Merge frequencies
    primary_data['frequency'] += secondary_data['frequency']

    # Keep earliest first mention
    if secondary_data['firstMention'] < primary_data['firstMention']:
        primary_data['firstMention'] = secondary_data['firstMention']

    # Merge definitions (keep most detailed)
    if secondary_data.get('definition'):
        if not primary_data.get('definition'):
            primary_data['definition'] = secondary_data['definition']
        elif len(secondary_data['definition']) > len(primary_data['definition']):
            primary_data['definition'] = secondary_data['definition']

    # Redirect all edges from secondary to primary
    for edge in self.graph.get_edges(secondary):
        source, target, edge_type, edge_data = edge

        if source == secondary:
            # Outgoing edge
            self._merge_edge(primary, target, edge_type, edge_data)
        else:
            # Incoming edge
            self._merge_edge(source, primary, edge_type, edge_data)

    # Mark secondary as merged (keep for audit)
    self.graph.set_node_property(secondary, 'merged_into', primary)
    self.graph.set_node_property(secondary, 'status', 'merged')

    # Update index
    for alias in secondary_data['aliases']:
        normalized = self._normalize_concept(alias)
        self.entity_index.update(normalized, primary)

    return primary

def _merge_edge(self, source: NodeID, target: NodeID,
                edge_type: str, edge_data: dict):
    """
    Merge edge into existing or create new one.
    """
    existing = self.graph.get_edge(source, target, edge_type)

    if existing:
        # Merge edge data
        existing['weight'] = max(existing['weight'], edge_data['weight'])
        existing['confidence'] = max(existing['confidence'], edge_data['confidence'])
        existing['count'] += edge_data.get('count', 1)
        existing['contexts'].extend(edge_data.get('contexts', []))
    else:
        # Create new edge
        self.graph.add_edge(source, target, edge_type, **edge_data)
```

---

## 3. Incremental Construction

### 3.1 Processing Strategy: One-by-One vs Batch

```python
class IncrementalBuilder:
    """
    Supports both streaming (one-by-one) and batch processing.
    """

    def __init__(self, config):
        self.mode = config.get('mode', 'batch')  # 'streaming' or 'batch'
        self.batch_size = config.get('batch_size', 50)
        self.graph_builder = GraphBuilder(config)

    def build_incremental(self, documents: Iterator[Document]):
        """
        Incremental build: can be called multiple times with new documents.
        """
        if self.mode == 'streaming':
            return self._build_streaming(documents)
        else:
            return self._build_batch(documents)

    def _build_streaming(self, documents: Iterator[Document]):
        """
        One-by-one processing: minimal memory, slower.

        Use when:
        - Documents arrive in real-time
        - Memory constrained
        - Need immediate updates
        """
        for doc in documents:
            # Process immediately
            self.graph_builder._process_document(doc)

            # Incremental enrichment (expensive)
            self._incremental_enrich(doc)

            # Persist changes
            self.graph_builder.graph.commit()

    def _build_batch(self, documents: Iterator[Document]):
        """
        Batch processing: faster, more memory.

        Use when:
        - Processing historical documents
        - Memory available
        - Can defer updates
        """
        for batch in self._batch(documents, self.batch_size):
            # Process batch in parallel
            with ThreadPoolExecutor(max_workers=8) as executor:
                futures = [
                    executor.submit(self.graph_builder._process_document, doc)
                    for doc in batch
                ]
                wait(futures)

            # Batch enrichment (more efficient)
            self._batch_enrich(batch)

            # Persist batch
            self.graph_builder.graph.commit()
```

### 3.2 Update Strategy: File Changes

```python
def update_document(self, doc: Document):
    """
    Update graph when a document changes.

    Strategy:
    1. Detect what changed (diff content hash)
    2. Remove stale nodes/edges
    3. Re-extract from updated document
    4. Update affected relationships
    """
    # Find existing document node
    existing = self.entity_index.lookup(doc.path, 'Document')

    if not existing:
        # New document - normal processing
        return self.graph_builder._process_document(doc)

    # Check if content changed
    old_hash = self.graph.get_node_property(existing, 'hash')
    new_hash = doc.content_hash

    if old_hash == new_hash:
        # No change - just update timestamp
        self.graph.set_node_property(existing, 'lastModified', doc.last_modified)
        return

    # Content changed - need to update
    logger.info(f"Document {doc.path} changed, updating graph")

    # Step 1: Mark old data for cleanup
    old_sections = self.graph.get_neighbors(existing, edge_type='CONTAINS')
    old_concepts = set()
    for section in old_sections:
        concepts = self.graph.get_neighbors(section, edge_type='MENTIONS')
        old_concepts.update(concepts)

    # Step 2: Remove old structure (but keep node)
    for section in old_sections:
        self.graph.remove_node(section)

    # Step 3: Re-extract from updated document
    self._process_document(doc)

    # Step 4: Identify concepts no longer mentioned
    new_sections = self.graph.get_neighbors(existing, edge_type='CONTAINS')
    new_concepts = set()
    for section in new_sections:
        concepts = self.graph.get_neighbors(section, edge_type='MENTIONS')
        new_concepts.update(concepts)

    removed_concepts = old_concepts - new_concepts

    # Step 5: Update concept frequencies
    for concept_id in removed_concepts:
        freq = self.graph.get_node_property(concept_id, 'frequency')
        self.graph.set_node_property(concept_id, 'frequency', max(0, freq - 1))

        # If frequency drops to 0, mark as orphan
        if freq <= 1:
            self.graph.set_node_property(concept_id, 'status', 'orphan')

    # Step 6: Re-calculate similarity edges
    self._update_similarity_edges(existing, doc.embedding)

def _update_similarity_edges(self, doc_node: NodeID, new_embedding: np.ndarray):
    """
    Update SIMILAR_TO edges when document changes.
    """
    # Remove old similarity edges
    old_edges = self.graph.get_edges(doc_node, edge_type='SIMILAR_TO')
    for edge in old_edges:
        self.graph.remove_edge(edge)

    # Add new similarity edges
    self.graph_builder._add_similarity_edges(doc_node, new_embedding)
```

### 3.3 Checkpointing Strategy

```python
class Checkpointer:
    """
    Save/restore graph state to resume interrupted builds.
    """

    def __init__(self, checkpoint_dir: str):
        self.checkpoint_dir = Path(checkpoint_dir)
        self.checkpoint_dir.mkdir(exist_ok=True)
        self.checkpoint_interval = 100  # Every N documents

    def save_state(self, graph: Graph) -> str:
        """
        Save graph state to disk.
        Returns checkpoint ID.
        """
        checkpoint_id = f"checkpoint_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        checkpoint_path = self.checkpoint_dir / checkpoint_id

        # Save graph structure
        graph_data = {
            'nodes': graph.serialize_nodes(),
            'edges': graph.serialize_edges(),
            'metadata': {
                'timestamp': datetime.now().isoformat(),
                'node_count': graph.node_count(),
                'edge_count': graph.edge_count(),
            }
        }

        # Write to disk (compressed)
        with gzip.open(checkpoint_path.with_suffix('.json.gz'), 'wt') as f:
            json.dump(graph_data, f)

        logger.info(f"Checkpoint saved: {checkpoint_id}")
        return checkpoint_id

    def restore_state(self, checkpoint_id: str) -> Graph:
        """
        Restore graph from checkpoint.
        """
        checkpoint_path = self.checkpoint_dir / f"{checkpoint_id}.json.gz"

        if not checkpoint_path.exists():
            raise ValueError(f"Checkpoint not found: {checkpoint_id}")

        with gzip.open(checkpoint_path, 'rt') as f:
            graph_data = json.load(f)

        # Reconstruct graph
        graph = Graph()
        graph.deserialize_nodes(graph_data['nodes'])
        graph.deserialize_edges(graph_data['edges'])

        logger.info(f"Checkpoint restored: {checkpoint_id}")
        return graph

    def list_checkpoints(self) -> List[str]:
        """List available checkpoints."""
        return sorted([
            p.stem.replace('.json', '')
            for p in self.checkpoint_dir.glob('checkpoint_*.json.gz')
        ])

    def cleanup_old_checkpoints(self, keep_last: int = 5):
        """Remove old checkpoints, keep only recent ones."""
        checkpoints = self.list_checkpoints()
        to_remove = checkpoints[:-keep_last]

        for checkpoint_id in to_remove:
            path = self.checkpoint_dir / f"{checkpoint_id}.json.gz"
            path.unlink()
            logger.info(f"Removed old checkpoint: {checkpoint_id}")
```

---

## 4. Relationship Weighting

### 4.1 Edge Weight Calculation

Edge weights should reflect **relationship strength** and **confidence**. Multiple signals combine to produce final weight.

```python
class RelationshipWeighter:
    """
    Calculate edge weights using multiple signals.
    """

    def calculate_edge_weight(self, rel: Relationship, context: GraphContext) -> float:
        """
        Multi-signal edge weighting.

        Signals:
        1. Extraction confidence (from NER/LLM)
        2. Relationship type (explicit > implicit)
        3. Co-occurrence frequency
        4. Textual proximity
        5. Source document authority
        6. Semantic similarity of concepts
        """
        signals = []

        # Signal 1: Base confidence from extraction
        signals.append(('extraction_confidence', rel.confidence, 1.0))

        # Signal 2: Relationship type strength
        type_weight = self._get_type_weight(rel.type, rel.is_explicit)
        signals.append(('relationship_type', type_weight, 0.8))

        # Signal 3: Co-occurrence frequency (if concepts appear together often)
        cooccurrence = self._calculate_cooccurrence(rel.source, rel.target, context)
        signals.append(('cooccurrence', cooccurrence, 0.6))

        # Signal 4: Textual proximity
        proximity = self._calculate_proximity_score(rel.token_distance)
        signals.append(('proximity', proximity, 0.5))

        # Signal 5: Source document authority (PageRank)
        authority = context.get_document_authority(rel.source_doc)
        signals.append(('authority', authority, 0.4))

        # Signal 6: Semantic similarity of concepts
        if rel.source_embedding and rel.target_embedding:
            similarity = cosine_similarity(rel.source_embedding, rel.target_embedding)
            signals.append(('semantic_similarity', similarity, 0.7))

        # Weighted combination
        total_weight = sum(weight for _, _, weight in signals)
        weighted_score = sum(
            score * weight for _, score, weight in signals
        ) / total_weight

        # Cap at 1.0
        return min(weighted_score, 1.0)

    def _get_type_weight(self, rel_type: str, is_explicit: bool) -> float:
        """
        Relationship type has inherent strength.
        """
        base_weights = {
            'DEPENDS_ON': 0.95,
            'REQUIRES': 0.95,
            'CONFIGURES': 0.85,
            'IMPLEMENTS': 0.85,
            'EXTENDS': 0.80,
            'USES': 0.75,
            'RELATED_TO': 0.65,
            'MENTIONS': 0.50,
            'SIMILAR_TO': 0.60,
        }

        weight = base_weights.get(rel_type, 0.50)

        # Boost explicit relationships (markdown links, definitions)
        if is_explicit:
            weight *= 1.2

        return min(weight, 1.0)

    def _calculate_cooccurrence(self, source: str, target: str,
                                 context: GraphContext) -> float:
        """
        How often do these concepts appear together?
        Normalized by total mentions.
        """
        cooccur_count = context.count_cooccurrence(source, target)
        source_count = context.count_mentions(source)
        target_count = context.count_mentions(target)

        if source_count == 0 or target_count == 0:
            return 0.0

        # Jaccard-like coefficient
        expected = (source_count * target_count) / context.total_sections
        actual = cooccur_count

        # Normalize to [0, 1]
        score = min(actual / (expected + 1), 1.0)
        return score

    def _calculate_proximity_score(self, token_distance: int) -> float:
        """
        Concepts mentioned close together have stronger relationship.
        Exponential decay with distance.
        """
        if token_distance <= 0:
            return 1.0

        # Decay function: score = e^(-distance/scale)
        scale = 100  # Half-life at 100 tokens
        score = math.exp(-token_distance / scale)
        return score
```

### 4.2 Confidence Scores for Inferred Relationships

```python
class ConfidenceScorer:
    """
    Calculate confidence for inferred (not explicit) relationships.
    """

    def score_inferred_relationship(self, rel: InferredRelationship) -> float:
        """
        Confidence scoring for relationships not explicitly stated.

        Example: Inferring "API Gateway DEPENDS_ON Authentication Service"
        from documents that never explicitly state this.
        """
        confidence_factors = []

        # Factor 1: Pattern matching confidence
        if rel.matched_pattern:
            pattern_confidence = rel.matched_pattern.confidence
            confidence_factors.append(pattern_confidence)

        # Factor 2: Semantic similarity of context
        if rel.source_context and rel.target_context:
            context_sim = self._semantic_similarity(
                rel.source_context,
                rel.target_context
            )
            confidence_factors.append(context_sim)

        # Factor 3: Path existence (are they connected through other nodes?)
        path_strength = self._calculate_path_strength(
            rel.source, rel.target, max_hops=3
        )
        confidence_factors.append(path_strength)

        # Factor 4: Co-occurrence in high-authority documents
        cooccur_in_authoritative = self._check_authoritative_cooccurrence(
            rel.source, rel.target
        )
        confidence_factors.append(cooccur_in_authoritative)

        # Combine using geometric mean (conservative)
        if not confidence_factors:
            return 0.0

        confidence = math.prod(confidence_factors) ** (1 / len(confidence_factors))
        return confidence

    def _calculate_path_strength(self, source: NodeID, target: NodeID,
                                  max_hops: int) -> float:
        """
        If two concepts are connected through intermediate concepts,
        they likely have a relationship.
        """
        paths = self.graph.find_paths(source, target, max_length=max_hops)

        if not paths:
            return 0.0

        # Strength is inverse of shortest path length
        shortest_path = min(len(p) for p in paths)

        # Weight by edge weights along path
        path_weights = []
        for path in paths[:5]:  # Top 5 paths
            weight = self._path_weight(path)
            path_weights.append(weight)

        avg_weight = sum(path_weights) / len(path_weights)

        # Decay with distance
        strength = avg_weight * (1.0 / shortest_path)
        return min(strength, 1.0)

    def _path_weight(self, path: List[NodeID]) -> float:
        """
        Weight of a path is product of edge weights.
        """
        if len(path) < 2:
            return 0.0

        weights = []
        for i in range(len(path) - 1):
            edge = self.graph.get_edge(path[i], path[i+1])
            weights.append(edge['weight'])

        # Geometric mean (avoids one weak edge dominating)
        return math.prod(weights) ** (1 / len(weights))
```

### 4.3 Similarity Thresholds

```python
# Configuration for different similarity thresholds

SIMILARITY_THRESHOLDS = {
    # Document-to-document semantic similarity
    'document_similarity': {
        'high_confidence': 0.85,  # Very similar docs (likely same topic)
        'medium_confidence': 0.70,  # Related docs
        'low_confidence': 0.55,    # Loosely related
        'minimum': 0.50,           # Threshold to include edge
    },

    # Concept-to-concept deduplication
    'concept_deduplication': {
        'merge': 0.90,      # Same concept, merge
        'similar': 0.75,    # Related concepts, link but don't merge
        'minimum': 0.60,    # Threshold for SIMILAR_TO edge
    },

    # Section-to-concept extraction
    'concept_extraction': {
        'high_relevance': 0.80,  # Concept is central to section
        'medium_relevance': 0.60,  # Concept mentioned significantly
        'minimum': 0.40,     # Threshold to create MENTIONS edge
    },
}

def get_similarity_threshold(context: str, level: str) -> float:
    """
    Get configured threshold for a specific context.
    """
    return SIMILARITY_THRESHOLDS.get(context, {}).get(level, 0.5)
```

---

## 5. Graph Enrichment

After initial construction, enrich the graph with derived properties.

### 5.1 Community Detection (Clustering)

```python
def detect_communities(graph: Graph) -> Dict[NodeID, int]:
    """
    Detect communities (clusters) of related documents using Leiden algorithm.

    Leiden is preferred over Louvain because:
    - Guarantees well-connected communities
    - Faster convergence
    - Better modularity scores
    """
    # Extract document subgraph (only doc-to-doc edges)
    doc_graph = graph.subgraph(node_type='Document')

    # Run Leiden algorithm
    communities = leiden_algorithm(
        doc_graph,
        resolution=1.0,  # Controls community size (higher = smaller communities)
        randomness=0.01,  # Randomness in optimization
        iterations=10     # Number of refinement iterations
    )

    # Label communities based on most frequent concepts
    community_labels = {}
    for community_id, members in communities.items():
        # Get all concepts mentioned in this community
        concept_freq = defaultdict(int)
        for doc_id in members:
            concepts = graph.get_connected_concepts(doc_id)
            for concept in concepts:
                concept_freq[concept] += 1

        # Top 3 concepts define community
        top_concepts = sorted(
            concept_freq.items(),
            key=lambda x: x[1],
            reverse=True
        )[:3]

        label = ' + '.join(c[0] for c in top_concepts)
        community_labels[community_id] = label

    # Add community nodes to graph
    for community_id, label in community_labels.items():
        cluster_node = graph.add_node(
            type='TopicCluster',
            properties={
                'clusterID': community_id,
                'label': label,
                'memberCount': len(communities[community_id]),
                'coherenceScore': _calculate_coherence(
                    communities[community_id], graph
                ),
            }
        )

        # Connect documents to cluster
        for doc_id in communities[community_id]:
            membership_strength = _calculate_membership(doc_id, community_id, graph)
            graph.add_edge(
                doc_id, cluster_node,
                type='BELONGS_TO',
                weight=membership_strength,
            )

    return communities

def _calculate_coherence(members: List[NodeID], graph: Graph) -> float:
    """
    Coherence score: how well documents fit together in cluster.
    Higher is better.
    """
    if len(members) < 2:
        return 1.0

    # Average pairwise similarity within cluster
    similarities = []
    for doc1, doc2 in itertools.combinations(members, 2):
        edge = graph.get_edge(doc1, doc2, 'SIMILAR_TO')
        if edge:
            similarities.append(edge['weight'])

    if not similarities:
        return 0.0

    return sum(similarities) / len(similarities)

# Alternative: Use NetworkX's Louvain implementation
import networkx.algorithms.community as nx_comm

def detect_communities_louvain(graph: Graph) -> Dict[NodeID, int]:
    """
    Louvain algorithm (faster, but Leiden is generally better).
    """
    doc_graph = graph.subgraph(node_type='Document')
    nx_graph = graph.to_networkx()

    communities = nx_comm.louvain_communities(
        nx_graph,
        weight='weight',
        resolution=1.0,
        seed=42
    )

    # Convert to dict
    node_to_community = {}
    for i, community in enumerate(communities):
        for node in community:
            node_to_community[node] = i

    return node_to_community
```

### 5.2 Centrality Metrics (Important Concepts)

```python
def calculate_centrality_metrics(graph: Graph):
    """
    Calculate importance scores for nodes.

    Metrics:
    - PageRank: Global importance (random walk)
    - Betweenness: Bridge nodes (shortest paths)
    - Degree: Number of connections
    """
    nx_graph = graph.to_networkx()

    # PageRank: Most important documents/concepts
    pagerank = nx.pagerank(
        nx_graph,
        alpha=0.85,  # Damping factor
        weight='weight',
        max_iter=100
    )

    # Betweenness: Bridge concepts (connect different areas)
    betweenness = nx.betweenness_centrality(
        nx_graph,
        weight='weight',
        normalized=True
    )

    # Degree centrality: Highly connected nodes
    degree = nx.degree_centrality(nx_graph)

    # Store in graph
    for node_id in graph.nodes():
        graph.set_node_property(node_id, 'pageRank', pagerank.get(node_id, 0.0))
        graph.set_node_property(node_id, 'betweenness', betweenness.get(node_id, 0.0))
        graph.set_node_property(node_id, 'degree', degree.get(node_id, 0.0))

    # Find top concepts by PageRank
    top_concepts = sorted(
        [(nid, pagerank[nid]) for nid in graph.nodes()
         if graph.get_node_type(nid) == 'Concept'],
        key=lambda x: x[1],
        reverse=True
    )[:50]

    logger.info(f"Top 10 concepts by PageRank:")
    for node_id, score in top_concepts[:10]:
        name = graph.get_node_property(node_id, 'name')
        logger.info(f"  {name}: {score:.4f}")

    return {
        'pagerank': pagerank,
        'betweenness': betweenness,
        'degree': degree,
    }
```

### 5.3 Path Analysis (Concept Dependencies)

```python
def analyze_concept_dependencies(graph: Graph, concept: str) -> Dict:
    """
    Analyze dependencies for a specific concept.

    Returns:
    - Direct dependencies (1-hop)
    - Transitive dependencies (2+ hops)
    - Reverse dependencies (what depends on this)
    - Dependency depth (longest path)
    """
    concept_node = graph.find_concept(concept)
    if not concept_node:
        return None

    # Find all DEPENDS_ON edges
    direct_deps = graph.get_neighbors(
        concept_node,
        edge_type='DEPENDS_ON',
        direction='outgoing'
    )

    # Find transitive dependencies (BFS)
    transitive_deps = set()
    queue = [(concept_node, 0)]  # (node, depth)
    visited = {concept_node}
    max_depth = 0

    while queue:
        node, depth = queue.pop(0)
        max_depth = max(max_depth, depth)

        neighbors = graph.get_neighbors(node, edge_type='DEPENDS_ON', direction='outgoing')
        for neighbor in neighbors:
            if neighbor not in visited:
                visited.add(neighbor)
                transitive_deps.add(neighbor)
                queue.append((neighbor, depth + 1))

    # Find reverse dependencies (what depends on this concept)
    reverse_deps = graph.get_neighbors(
        concept_node,
        edge_type='DEPENDS_ON',
        direction='incoming'
    )

    return {
        'concept': concept,
        'direct_dependencies': [
            graph.get_node_property(n, 'name') for n in direct_deps
        ],
        'transitive_dependencies': [
            graph.get_node_property(n, 'name') for n in transitive_deps
        ],
        'reverse_dependencies': [
            graph.get_node_property(n, 'name') for n in reverse_deps
        ],
        'dependency_depth': max_depth,
        'total_dependencies': len(transitive_deps),
        'depended_on_by': len(reverse_deps),
    }

def find_circular_dependencies(graph: Graph) -> List[List[str]]:
    """
    Detect circular dependencies (cycles) in the graph.
    """
    # Extract dependency subgraph
    dep_graph = graph.subgraph(edge_types=['DEPENDS_ON', 'REQUIRES'])
    nx_graph = dep_graph.to_networkx()

    # Find cycles
    cycles = list(nx.simple_cycles(nx_graph))

    # Convert node IDs to concept names
    named_cycles = []
    for cycle in cycles:
        names = [graph.get_node_property(n, 'name') for n in cycle]
        named_cycles.append(names)

    return named_cycles
```

---

## 6. Validation During Construction

### 6.1 Consistency Checks

```python
class GraphValidator:
    """
    Validate graph consistency during construction.
    """

    def __init__(self, graph: Graph):
        self.graph = graph
        self.issues = []

    def validate(self) -> List[ValidationIssue]:
        """
        Run all validation checks.
        """
        self.issues = []

        # Structural validation
        self._check_orphan_nodes()
        self._check_dangling_edges()
        self._check_node_properties()
        self._check_edge_properties()

        # Semantic validation
        self._check_concept_consistency()
        self._check_circular_references()
        self._check_duplicate_nodes()

        # Quality validation
        self._check_edge_weights()
        self._check_community_coherence()

        return self.issues

    def _check_orphan_nodes(self):
        """
        Find nodes with no connections (possible extraction errors).
        """
        for node_id in self.graph.nodes():
            degree = self.graph.degree(node_id)
            node_type = self.graph.get_node_type(node_id)

            if degree == 0:
                # Orphan node
                if node_type == 'Concept':
                    # Concepts should have MENTIONS edges
                    self.issues.append(ValidationIssue(
                        severity='WARNING',
                        type='orphan_concept',
                        node_id=node_id,
                        message=f"Concept '{self.graph.get_node_property(node_id, 'name')}' has no mentions",
                    ))
                elif node_type == 'Document':
                    # Documents can be isolated (rare but valid)
                    self.issues.append(ValidationIssue(
                        severity='INFO',
                        type='isolated_document',
                        node_id=node_id,
                        message=f"Document '{self.graph.get_node_property(node_id, 'title')}' has no connections",
                    ))

    def _check_concept_consistency(self):
        """
        Check for inconsistencies in concept nodes.
        """
        concepts = [n for n in self.graph.nodes()
                   if self.graph.get_node_type(n) == 'Concept']

        for concept_id in concepts:
            # Check 1: Frequency matches mention count
            frequency = self.graph.get_node_property(concept_id, 'frequency')
            mention_edges = self.graph.get_edges(concept_id, edge_type='MENTIONS', direction='incoming')
            actual_mentions = sum(e['count'] for e in mention_edges)

            if frequency != actual_mentions:
                self.issues.append(ValidationIssue(
                    severity='ERROR',
                    type='frequency_mismatch',
                    node_id=concept_id,
                    message=f"Concept frequency ({frequency}) doesn't match mention count ({actual_mentions})",
                ))

            # Check 2: Has aliases
            aliases = self.graph.get_node_property(concept_id, 'aliases')
            if not aliases or len(aliases) == 0:
                self.issues.append(ValidationIssue(
                    severity='WARNING',
                    type='missing_aliases',
                    node_id=concept_id,
                    message=f"Concept has no aliases",
                ))

    def _check_circular_references(self):
        """
        Find circular dependency chains (A -> B -> A).
        """
        cycles = find_circular_dependencies(self.graph)

        for cycle in cycles:
            self.issues.append(ValidationIssue(
                severity='WARNING',
                type='circular_dependency',
                message=f"Circular dependency: {' -> '.join(cycle)}",
            ))

    def _check_edge_weights(self):
        """
        Validate edge weights are in valid range.
        """
        for edge in self.graph.edges():
            source, target, edge_type, edge_data = edge
            weight = edge_data.get('weight')

            if weight is None:
                self.issues.append(ValidationIssue(
                    severity='ERROR',
                    type='missing_weight',
                    message=f"Edge {source} -> {target} ({edge_type}) has no weight",
                ))
            elif weight < 0 or weight > 1.0:
                self.issues.append(ValidationIssue(
                    severity='ERROR',
                    type='invalid_weight',
                    message=f"Edge {source} -> {target} ({edge_type}) has invalid weight: {weight}",
                ))
```

### 6.2 Orphan Detection

```python
def detect_orphans(graph: Graph) -> Dict[str, List[NodeID]]:
    """
    Detect different types of orphan nodes.

    Types:
    - Isolated nodes (no connections at all)
    - Weak nodes (only 1-2 low-weight connections)
    - Underdocumented concepts (mentioned but never explained)
    - Dangling sections (sections without parent document)
    """
    orphans = {
        'isolated': [],
        'weak': [],
        'underdocumented': [],
        'dangling': [],
    }

    for node_id in graph.nodes():
        node_type = graph.get_node_type(node_id)
        degree = graph.degree(node_id)

        # Isolated nodes
        if degree == 0:
            orphans['isolated'].append(node_id)
            continue

        # Weak nodes (low-weight connections only)
        edges = graph.get_edges(node_id)
        avg_weight = sum(e['weight'] for e in edges) / len(edges)
        if degree <= 2 and avg_weight < 0.3:
            orphans['weak'].append(node_id)

        # Underdocumented concepts
        if node_type == 'Concept':
            mentions = graph.get_neighbors(node_id, edge_type='MENTIONS', direction='incoming')
            definition = graph.get_node_property(node_id, 'definition')

            if len(mentions) > 5 and not definition:
                orphans['underdocumented'].append(node_id)

        # Dangling sections (no parent document)
        if node_type == 'Section':
            parent_doc = graph.get_neighbors(node_id, edge_type='CONTAINS', direction='incoming')
            if not parent_doc:
                orphans['dangling'].append(node_id)

    return orphans
```

### 6.3 Broken Link Identification

```python
def identify_broken_links(graph: Graph, file_system: FileSystem) -> List[BrokenLink]:
    """
    Identify broken links in the graph.

    Types:
    - Document references non-existent file
    - Concept mentioned but never defined
    - Circular references
    - Inconsistent bidirectional links
    """
    broken_links = []

    # Check document file existence
    doc_nodes = [n for n in graph.nodes()
                if graph.get_node_type(n) == 'Document']

    for doc_id in doc_nodes:
        file_path = graph.get_node_property(doc_id, 'filePath')
        if not file_system.exists(file_path):
            broken_links.append(BrokenLink(
                type='missing_file',
                node_id=doc_id,
                details={'filePath': file_path},
                severity='ERROR',
            ))

    # Check LINKS_TO edges point to valid documents
    link_edges = [e for e in graph.edges()
                 if e[2] == 'LINKS_TO']  # edge_type

    for source, target, _, edge_data in link_edges:
        # Verify target exists
        if not graph.has_node(target):
            broken_links.append(BrokenLink(
                type='dangling_link',
                source=source,
                target=target,
                details=edge_data,
                severity='ERROR',
            ))

        # Verify bidirectional consistency (if marked as bidirectional)
        if edge_data.get('bidirectional'):
            reverse_edge = graph.get_edge(target, source, 'LINKS_TO')
            if not reverse_edge:
                broken_links.append(BrokenLink(
                    type='unidirectional_link',
                    source=source,
                    target=target,
                    details={'expected': 'bidirectional'},
                    severity='WARNING',
                ))

    return broken_links
```

---

## 7. Performance Optimization

### 7.1 Batch Operations

```python
class BatchOptimizer:
    """
    Optimize graph operations using batching.
    """

    def __init__(self, graph: Graph):
        self.graph = graph
        self.pending_nodes = []
        self.pending_edges = []
        self.batch_size = 1000

    def add_node_batch(self, nodes: List[NodeData]):
        """
        Add multiple nodes in single transaction.
        """
        self.pending_nodes.extend(nodes)

        if len(self.pending_nodes) >= self.batch_size:
            self._flush_nodes()

    def add_edge_batch(self, edges: List[EdgeData]):
        """
        Add multiple edges in single transaction.
        """
        self.pending_edges.extend(edges)

        if len(self.pending_edges) >= self.batch_size:
            self._flush_edges()

    def _flush_nodes(self):
        """
        Commit pending nodes to graph.
        """
        if not self.pending_nodes:
            return

        # Neo4j example: use UNWIND for batch insert
        if isinstance(self.graph, Neo4jGraph):
            query = """
            UNWIND $nodes AS node
            CREATE (n:Node {id: node.id})
            SET n += node.properties
            """
            self.graph.execute(query, {'nodes': self.pending_nodes})
        else:
            # In-memory graph: just add all
            for node in self.pending_nodes:
                self.graph.add_node(node.type, node.properties)

        logger.info(f"Flushed {len(self.pending_nodes)} nodes")
        self.pending_nodes.clear()

    def _flush_edges(self):
        """
        Commit pending edges to graph.
        """
        if not self.pending_edges:
            return

        # Group edges by type for efficient insertion
        edges_by_type = defaultdict(list)
        for edge in self.pending_edges:
            edges_by_type[edge.type].append(edge)

        # Insert by type
        for edge_type, edges in edges_by_type.items():
            if isinstance(self.graph, Neo4jGraph):
                query = f"""
                UNWIND $edges AS edge
                MATCH (source {{id: edge.source}})
                MATCH (target {{id: edge.target}})
                CREATE (source)-[r:{edge_type}]->(target)
                SET r += edge.properties
                """
                self.graph.execute(query, {'edges': edges})
            else:
                for edge in edges:
                    self.graph.add_edge(edge.source, edge.target, edge.type, **edge.properties)

        logger.info(f"Flushed {len(self.pending_edges)} edges")
        self.pending_edges.clear()

    def flush_all(self):
        """
        Flush all pending operations.
        """
        self._flush_nodes()
        self._flush_edges()
```

### 7.2 Index Strategies

```python
class GraphIndexer:
    """
    Create indexes for fast graph queries.
    """

    def create_indexes(self, graph: Graph):
        """
        Create all necessary indexes for efficient queries.
        """
        # For Neo4j
        if isinstance(graph, Neo4jGraph):
            self._create_neo4j_indexes(graph)

        # For in-memory graphs (NetworkX, etc.)
        else:
            self._create_memory_indexes(graph)

    def _create_neo4j_indexes(self, graph: Neo4jGraph):
        """
        Create Neo4j indexes and constraints.
        """
        indexes = [
            # Node property indexes
            "CREATE INDEX document_path IF NOT EXISTS FOR (d:Document) ON (d.filePath)",
            "CREATE INDEX document_hash IF NOT EXISTS FOR (d:Document) ON (d.hash)",
            "CREATE INDEX concept_name IF NOT EXISTS FOR (c:Concept) ON (c.normalized)",
            "CREATE INDEX concept_type IF NOT EXISTS FOR (c:Concept) ON (c.type)",
            "CREATE INDEX section_heading IF NOT EXISTS FOR (s:Section) ON (s.heading)",

            # Composite indexes for common queries
            "CREATE INDEX concept_type_freq IF NOT EXISTS FOR (c:Concept) ON (c.type, c.frequency)",

            # Full-text search indexes
            "CREATE FULLTEXT INDEX document_content IF NOT EXISTS FOR (d:Document) ON EACH [d.title, d.filePath]",
            "CREATE FULLTEXT INDEX concept_search IF NOT EXISTS FOR (c:Concept) ON EACH [c.name, c.definition]",

            # Constraints (ensure uniqueness)
            "CREATE CONSTRAINT document_path_unique IF NOT EXISTS FOR (d:Document) REQUIRE d.filePath IS UNIQUE",
            "CREATE CONSTRAINT concept_normalized_unique IF NOT EXISTS FOR (c:Concept) REQUIRE c.normalized IS UNIQUE",
        ]

        for index_query in indexes:
            try:
                graph.execute(index_query)
                logger.info(f"Created index: {index_query.split()[2]}")
            except Exception as e:
                logger.warning(f"Failed to create index: {e}")

    def _create_memory_indexes(self, graph: Graph):
        """
        Create in-memory indexes for fast lookups.
        """
        # Document path index
        graph.indexes['document_path'] = {
            graph.get_node_property(n, 'filePath'): n
            for n in graph.nodes()
            if graph.get_node_type(n) == 'Document'
        }

        # Concept name index
        graph.indexes['concept_name'] = {
            graph.get_node_property(n, 'normalized'): n
            for n in graph.nodes()
            if graph.get_node_type(n) == 'Concept'
        }

        # Concept type index (multi-value)
        graph.indexes['concept_type'] = defaultdict(list)
        for n in graph.nodes():
            if graph.get_node_type(n) == 'Concept':
                concept_type = graph.get_node_property(n, 'type')
                graph.indexes['concept_type'][concept_type].append(n)

        # Edge type index (for fast edge queries)
        graph.indexes['edge_type'] = defaultdict(list)
        for source, target, edge_type, _ in graph.edges():
            graph.indexes['edge_type'][edge_type].append((source, target))

        logger.info(f"Created {len(graph.indexes)} in-memory indexes")
```

### 7.3 Memory Management

```python
class MemoryManager:
    """
    Manage memory usage during large graph construction.
    """

    def __init__(self, max_memory_gb: float = 8.0):
        self.max_memory = max_memory_gb * 1024 * 1024 * 1024  # Convert to bytes
        self.cache = LRUCache(maxsize=10000)

    def check_memory_usage(self):
        """
        Check current memory usage and take action if needed.
        """
        import psutil
        process = psutil.Process()
        memory_info = process.memory_info()
        current_usage = memory_info.rss

        usage_percent = (current_usage / self.max_memory) * 100

        if usage_percent > 90:
            logger.warning(f"Memory usage high: {usage_percent:.1f}%")
            self._reduce_memory()

        return current_usage

    def _reduce_memory(self):
        """
        Reduce memory footprint.
        """
        # Strategy 1: Clear caches
        self.cache.clear()
        logger.info("Cleared LRU cache")

        # Strategy 2: Offload embeddings to disk
        self._offload_embeddings()

        # Strategy 3: Force garbage collection
        import gc
        gc.collect()
        logger.info("Forced garbage collection")

    def _offload_embeddings(self):
        """
        Save embeddings to disk and remove from memory.
        Only load on-demand.
        """
        # Save embeddings to HDF5 or similar
        embedding_store = h5py.File('embeddings.h5', 'w')

        for node_id in self.graph.nodes():
            embedding = self.graph.get_node_property(node_id, 'embedding')
            if embedding is not None:
                embedding_store.create_dataset(str(node_id), data=embedding)
                # Remove from memory
                self.graph.set_node_property(node_id, 'embedding', None)

        embedding_store.close()
        logger.info("Offloaded embeddings to disk")

# Streaming processing for very large graphs
class StreamingGraphBuilder:
    """
    Build graph in streaming fashion for datasets larger than memory.
    """

    def __init__(self, db_path: str):
        # Use persistent graph database (Neo4j, SQLite, etc.)
        self.graph = PersistentGraph(db_path)

    def build_streaming(self, document_stream: Iterator[Document]):
        """
        Process documents one at a time, never loading full graph into memory.
        """
        for doc in document_stream:
            # Process document
            self._process_document_streaming(doc)

            # Immediately persist (don't hold in memory)
            self.graph.commit()

            # Clear local caches
            self._clear_caches()

    def _process_document_streaming(self, doc: Document):
        """
        Process single document with minimal memory footprint.
        """
        # Extract concepts (keep only top K)
        concepts = self._extract_concepts(doc)
        top_concepts = sorted(concepts, key=lambda c: c.score, reverse=True)[:20]

        # Add to graph
        for concept in top_concepts:
            self._add_concept_streaming(concept)

        # Don't keep in memory
        del concepts, top_concepts
```

---

## 8. Code Examples

### 8.1 Add a Node

```python
# Example 1: Simple node addition
node_id = graph.add_node(
    type='Concept',
    properties={
        'name': 'Rate Limiting',
        'normalized': 'rate limiting',
        'type': 'pattern',
        'frequency': 1,
    }
)

# Example 2: Add document node with validation
def add_document_node_safe(graph, doc):
    """Add document node with error handling."""
    try:
        # Check if already exists
        existing = graph.find_node(
            type='Document',
            property='filePath',
            value=doc.path
        )

        if existing:
            logger.info(f"Document {doc.path} already exists, updating")
            # Update properties
            graph.update_node(existing, {
                'lastModified': doc.last_modified,
                'hash': doc.content_hash,
            })
            return existing

        # Create new node
        node_id = graph.add_node(
            type='Document',
            properties={
                'filePath': doc.path,
                'title': doc.title,
                'tokens': len(doc.content.split()),
                'lastModified': doc.last_modified,
                'hash': doc.content_hash,
            }
        )

        logger.info(f"Added document node: {doc.path}")
        return node_id

    except Exception as e:
        logger.error(f"Failed to add document node: {e}")
        raise
```

### 8.2 Create an Edge

```python
# Example 1: Simple edge creation
graph.add_edge(
    source=doc_node,
    target=section_node,
    type='CONTAINS',
    weight=1.0,
    order=1,
)

# Example 2: Create edge with confidence and validation
def add_relationship_edge_safe(graph, source_concept, target_concept, rel_type, confidence):
    """Add relationship edge with validation and weight calculation."""

    # Validate nodes exist
    if not graph.has_node(source_concept) or not graph.has_node(target_concept):
        raise ValueError("Source or target concept not found")

    # Check for self-loops
    if source_concept == target_concept:
        logger.warning("Attempted to create self-loop, skipping")
        return None

    # Calculate weight
    base_weight = confidence
    type_boost = {
        'DEPENDS_ON': 1.2,
        'CONFIGURES': 1.1,
        'RELATED_TO': 1.0,
    }.get(rel_type, 1.0)
    weight = min(base_weight * type_boost, 1.0)

    # Check if edge exists
    existing = graph.get_edge(source_concept, target_concept, rel_type)
    if existing:
        # Update weight (exponential moving average)
        new_weight = 0.7 * existing['weight'] + 0.3 * weight
        graph.update_edge(source_concept, target_concept, rel_type, {
            'weight': new_weight,
            'count': existing['count'] + 1,
        })
        logger.info(f"Updated edge {rel_type} weight: {new_weight:.3f}")
        return existing

    # Create new edge
    edge = graph.add_edge(
        source=source_concept,
        target=target_concept,
        type=rel_type,
        weight=weight,
        confidence=confidence,
        count=1,
        created=datetime.now().isoformat(),
    )

    logger.info(f"Created edge: {rel_type} (weight={weight:.3f})")
    return edge
```

### 8.3 Deduplication Logic Example

```python
# Full example: Extract and deduplicate concepts from a document

def extract_and_deduplicate_concepts(graph, doc):
    """
    Extract concepts from document and deduplicate against existing graph.
    """
    # Step 1: Extract raw concepts
    raw_concepts = extract_concepts_from_text(doc.content)

    # Step 2: Process each concept with deduplication
    concept_nodes = []

    for raw_concept in raw_concepts:
        # Normalize
        normalized = normalize_concept(raw_concept.text)

        # Check for exact match
        existing = graph.find_concept_by_normalized(normalized)

        if existing:
            # Found exact match - reuse node
            logger.debug(f"Reusing existing concept: {raw_concept.text}")
            concept_nodes.append(existing)

            # Update frequency
            freq = graph.get_node_property(existing, 'frequency')
            graph.set_node_property(existing, 'frequency', freq + 1)

            # Add alias if different
            aliases = graph.get_node_property(existing, 'aliases')
            if raw_concept.text not in aliases:
                aliases.append(raw_concept.text)
                graph.set_node_property(existing, 'aliases', aliases)

            continue

        # Check for semantic similarity
        concept_embedding = embed_text(raw_concept.text)
        similar = graph.find_similar_concepts(concept_embedding, threshold=0.85)

        if similar:
            # Found similar concept(s)
            best_match, similarity = similar[0]

            if similarity > 0.90:
                # Very similar - merge
                logger.info(f"Merging '{raw_concept.text}' into existing concept (sim={similarity:.3f})")
                concept_nodes.append(best_match)

                # Merge as alias
                merge_concept_alias(graph, best_match, raw_concept.text)

            elif similarity > 0.75:
                # Related but distinct - create new but link
                logger.info(f"Creating related concept for '{raw_concept.text}' (sim={similarity:.3f})")

                new_concept = graph.add_node(
                    type='Concept',
                    properties={
                        'name': raw_concept.text,
                        'normalized': normalized,
                        'aliases': [raw_concept.text],
                        'type': raw_concept.type,
                        'frequency': 1,
                        'embedding': concept_embedding,
                    }
                )

                # Link as similar
                graph.add_edge(
                    new_concept, best_match,
                    type='SIMILAR_TO',
                    weight=similarity,
                )

                concept_nodes.append(new_concept)

            continue

        # No match found - create new concept
        logger.info(f"Creating new concept: {raw_concept.text}")
        new_concept = graph.add_node(
            type='Concept',
            properties={
                'name': raw_concept.text,
                'normalized': normalized,
                'aliases': [raw_concept.text],
                'type': raw_concept.type,
                'frequency': 1,
                'firstMention': datetime.now().isoformat(),
                'embedding': concept_embedding,
            }
        )

        concept_nodes.append(new_concept)

    return concept_nodes

def merge_concept_alias(graph, primary_concept, alias):
    """Merge alias into primary concept."""
    # Add to aliases
    aliases = graph.get_node_property(primary_concept, 'aliases')
    if alias not in aliases:
        aliases.append(alias)
        graph.set_node_property(primary_concept, 'aliases', aliases)

    # Increment frequency
    freq = graph.get_node_property(primary_concept, 'frequency')
    graph.set_node_property(primary_concept, 'frequency', freq + 1)

    # Update index
    normalized = normalize_concept(alias)
    graph.entity_index.add_alias(primary_concept, normalized)
```

---

## 9. Implementation Checklist

### Phase 1: Foundation
- [ ] Implement Graph data structure (NetworkX or custom)
- [ ] Create NodeID system (UUID or incremental)
- [ ] Implement GraphBuilder class with basic add_node/add_edge
- [ ] Create EntityIndex for fast lookups
- [ ] Implement normalization functions (stemming, case-folding)
- [ ] Test with small dataset (10-20 documents)

### Phase 2: Deduplication
- [ ] Implement concept normalization pipeline
- [ ] Create FuzzyIndex for typo tolerance
- [ ] Implement semantic similarity search (HNSW/FAISS)
- [ ] Create merge_concepts function with conflict resolution
- [ ] Add alias management
- [ ] Test deduplication accuracy on 100 documents

### Phase 3: Incremental Construction
- [ ] Implement streaming processing (one-by-one)
- [ ] Implement batch processing with optimization
- [ ] Create Checkpointer for resume capability
- [ ] Implement update_document for changed files
- [ ] Add change detection (content hashing)
- [ ] Test incremental updates

### Phase 4: Relationship Weighting
- [ ] Implement RelationshipWeighter with multi-signal weighting
- [ ] Create ConfidenceScorer for inferred relationships
- [ ] Add proximity scoring (token distance)
- [ ] Implement co-occurrence analysis
- [ ] Test weight calculation accuracy

### Phase 5: Graph Enrichment
- [ ] Implement Leiden/Louvain community detection
- [ ] Calculate PageRank, betweenness, degree centrality
- [ ] Add path analysis for dependencies
- [ ] Detect circular dependencies
- [ ] Create TopicCluster nodes

### Phase 6: Validation
- [ ] Implement GraphValidator with consistency checks
- [ ] Create orphan detection
- [ ] Add broken link identification
- [ ] Implement edge weight validation
- [ ] Create validation report generator

### Phase 7: Performance
- [ ] Implement BatchOptimizer for bulk operations
- [ ] Create indexes (path, name, type)
- [ ] Add MemoryManager with caching
- [ ] Implement embedding offloading for large graphs
- [ ] Benchmark query performance
- [ ] Optimize hot paths

### Phase 8: Testing & Documentation
- [ ] Unit tests for all core functions
- [ ] Integration tests with real documents
- [ ] Performance benchmarks (2000+ docs)
- [ ] API documentation
- [ ] Usage examples
- [ ] Troubleshooting guide

---

## 10. Performance Targets

| Metric | Target | Notes |
|--------|--------|-------|
| **Document Processing** | 10-20 docs/sec | Single-threaded |
| **Batch Processing** | 50-100 docs/sec | With parallelization |
| **Graph Size** | 10,000+ nodes | Without performance degradation |
| **Edge Count** | 50,000+ edges | Maintainable query performance |
| **Query Latency** | <100ms | Single-hop queries |
| **Multi-hop Query** | <500ms | 2-3 hop traversals |
| **Memory Usage** | <4GB | For 2000 documents |
| **Checkpoint Time** | <10 seconds | Save full graph state |
| **Deduplication Accuracy** | >90% | Correctly merged concepts |
| **Edge Weight Precision** | >80% | Matches human judgment |

---

## Sources

Research sources used in this implementation guide:

**Incremental Graph Building & Entity Resolution:**
- [From LLMs to Knowledge Graphs: Building Production-Ready Graph Systems in 2025](https://medium.com/@claudiubranzan/from-llms-to-knowledge-graphs-building-production-ready-graph-systems-in-2025-2b4aff1ec99a)
- [An incremental graph-partitioning algorithm for entity resolution](https://www.sciencedirect.com/science/article/abs/pii/S1566253517305729)
- [Entity Resolved Knowledge Graphs: A Tutorial](https://neo4j.com/blog/developer/entity-resolved-knowledge-graphs/)
- [Construction of Knowledge Graphs: State and Challenges](https://arxiv.org/pdf/2302.11509)

**Relationship Weighting & Confidence Scoring:**
- [Uncertainty Management in the Construction of Knowledge Graphs: a Survey](https://arxiv.org/html/2405.16929v2)
- [Knowledge Graph Construction: Extraction, Learning, and Evaluation](https://www.mdpi.com/2076-3417/15/7/3727)
- [Understand reconciliation confidence score | Google Cloud](https://cloud.google.com/enterprise-knowledge-graph/docs/confidence-score)

**Community Detection:**
- [From Louvain to Leiden: guaranteeing well-connected communities](https://www.nature.com/articles/s41598-019-41695-z)
- [Leiden algorithm - Wikipedia](https://en.wikipedia.org/wiki/Leiden_algorithm)
- [Louvain method - Wikipedia](https://en.wikipedia.org/wiki/Louvain_method)
- [Leiden - Neo4j Graph Data Science](https://neo4j.com/docs/graph-data-science/current/algorithms/leiden/)

**Performance & Indexing:**
- [How Graph Database Indexing Works in NebulaGraph](https://www.nebula-graph.io/posts/how-indexing-works-in-nebula-graph)
- [Query Optimization in Graph Databases](https://hypermode.com/blog/query-optimization)
- [Reduce GraphRAG Indexing Costs: Optimized Strategies](https://www.falkordb.com/blog/reduce-graphrag-indexing-costs/)

**Validation & Consistency:**
- [KGValidator: A Framework for Automatic Validation of Knowledge Graph Construction](https://arxiv.org/html/2404.15923v1)
- [How do you ensure data consistency in a knowledge graph?](https://milvus.io/ai-quick-reference/how-do-you-ensure-data-consistency-in-a-knowledge-graph)
- [Detecting and Fixing Inconsistency of Large Knowledge Graphs](https://dl.acm.org/doi/10.1145/3688671.3688766)

---

**Document Version**: 1.0
**Date**: 2026-01-26
**Author**: Claude Sonnet 4.5
**Project**: mdcontext Knowledge Graph - Implementation Guide
