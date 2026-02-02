# Knowledge Graph Validation, Testing & Metrics Framework
## Rigorous Quality Assurance for mdcontext Knowledge Graph Harness

**Date:** 2026-01-26
**Version:** 1.0
**Purpose:** Comprehensive validation strategy ensuring graph correctness, completeness, and reliability
**Status:** Implementation Guide

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Ground Truth Creation](#1-ground-truth-creation)
3. [Extraction Quality Metrics](#2-extraction-quality-metrics)
4. [Graph Quality Metrics](#3-graph-quality-metrics)
5. [Functional Validation](#4-functional-validation)
6. [Performance Benchmarks](#5-performance-benchmarks)
7. [Automated Testing Suite](#6-automated-testing-suite)
8. [Metrics Dashboard](#7-metrics-dashboard)
9. [Implementation Roadmap](#8-implementation-roadmap)
10. [Code Examples](#9-code-examples)
11. [References](#references)

---

## Executive Summary

### Why Validation Matters

Building a knowledge graph from 2000+ markdown files is meaningless if we can't **prove it's correct**. This document establishes rigorous validation methodology to ensure:

1. **Extraction Accuracy**: Nodes and edges reflect actual documentation content
2. **Graph Quality**: Structure is coherent, connected, and complete
3. **Query Performance**: Queries return correct, relevant results
4. **Production Readiness**: System meets performance and reliability targets

### Validation Approach

Our validation strategy combines:

- **Intrinsic Evaluation**: Measure internal graph quality (accuracy, coverage, consistency)
- **Extrinsic Evaluation**: Measure effectiveness in downstream tasks (query answering, gap detection)
- **Automated Testing**: Continuous validation via test suites and CI/CD
- **Human Validation**: Expert review of critical subgraphs and edge cases

### Success Criteria

| Metric | Target | Priority |
|--------|--------|----------|
| Node extraction precision | >0.90 | Critical |
| Edge extraction precision (explicit) | >0.85 | Critical |
| Edge extraction recall (explicit) | >0.80 | Critical |
| Edge extraction F1 (semantic) | >0.70 | High |
| Graph connectivity (single component) | >85% | Critical |
| Query answering accuracy | >0.85 | Critical |
| Multi-hop query accuracy (2-hop) | >0.75 | High |
| Multi-hop query accuracy (3+ hop) | >0.60 | Medium |
| False positive rate | <5% | Critical |
| Build time (2000 docs) | <10 min | High |
| Query latency P95 | <100ms | High |

---

## 1. Ground Truth Creation

### 1.1 Overview

Ground truth is the foundation of validation. We need **gold-standard test cases** that represent the "correct" graph structure against which to measure our automated extraction.

Recent research shows that [Inter Annotator Agreement (IAA) measures help identify inconsistencies between annotators, ensuring reliability and high-quality annotated ground truth data](https://dl.acm.org/doi/10.1145/3726302.3730286). We'll use IAA to validate our ground truth quality.

### 1.2 Ground Truth Strategy

#### 1.2.1 Stratified Sampling Approach

Don't manually annotate randomly. Use **stratified sampling** to ensure coverage:

```python
# Stratification criteria
sampling_strategy = {
    'by_importance': {
        'high_pagerank': 20,      # Top 20 docs by PageRank
        'high_centrality': 15,    # High betweenness centrality
        'cluster_centers': 10     # 1-2 docs from each topic cluster
    },
    'by_type': {
        'api_docs': 10,
        'config_docs': 8,
        'tutorial_docs': 12,
        'reference_docs': 10
    },
    'by_complexity': {
        'high_link_density': 10,  # Many explicit links
        'low_link_density': 5,    # Few explicit links
        'long_documents': 8,      # >2000 tokens
        'short_documents': 5      # <500 tokens
    }
}
# Total: ~113 documents (can reduce to 50-80 for MVP)
```

**Rationale**: This ensures we test diverse document types, not just "easy" cases.

#### 1.2.2 Annotation Guidelines

Create a detailed **annotation manual** covering:

**What to Annotate**:

1. **Nodes**:
   - Document nodes (always include)
   - Section nodes (H1-H3 level)
   - Concept nodes (key technical terms, APIs, features, configs)
   - Topic clusters (if document belongs to semantic group)

2. **Edges**:
   - Explicit links (markdown `[text](url)` references)
   - Implicit semantic links (similar content, threshold: human judgment)
   - Concept mentions (which concepts appear in which sections)
   - Dependency relationships (A depends on B, A configures B, etc.)

3. **Attributes**:
   - Edge weights (0.0-1.0 scale for strength)
   - Relationship types (depends_on, similar_to, part_of, implements, etc.)
   - Confidence scores (how certain is this relationship?)

**Example Annotation Format** (JSON):

```json
{
  "document_id": "docs/auth/oauth.md",
  "nodes": {
    "document": {
      "id": "doc:auth/oauth.md",
      "type": "document",
      "properties": {
        "title": "OAuth 2.0 Authentication",
        "tokens": 1247,
        "topic_cluster": "authentication"
      }
    },
    "sections": [
      {
        "id": "section:auth/oauth.md#setup",
        "heading": "OAuth Setup",
        "level": 2,
        "parent_section": null
      }
    ],
    "concepts": [
      {
        "id": "concept:oauth",
        "name": "OAuth",
        "type": "feature",
        "first_mention": "line 12"
      },
      {
        "id": "concept:jwt",
        "name": "JWT",
        "type": "feature",
        "first_mention": "line 45"
      }
    ]
  },
  "edges": [
    {
      "source": "doc:auth/oauth.md",
      "target": "doc:auth/sessions.md",
      "type": "links_to",
      "properties": {
        "link_type": "explicit",
        "weight": 1.0,
        "context": "See also: session management"
      }
    },
    {
      "source": "section:auth/oauth.md#setup",
      "target": "concept:oauth",
      "type": "mentions",
      "properties": {
        "count": 7,
        "weight": 0.85
      }
    },
    {
      "source": "concept:oauth",
      "target": "concept:jwt",
      "type": "related_to",
      "properties": {
        "relationship_type": "depends_on",
        "weight": 0.70
      }
    }
  ]
}
```

#### 1.2.3 Annotation Tools

Use existing tools where possible:

1. **[Doctron](https://dl.acm.org/doi/10.1145/3726302.3730286)**: Web-based collaborative annotation for IR tasks, supports entity tagging and relationship identification
2. **[DocTAG](https://www.researchgate.net/publication/359728042_DocTAG_A_Customizable_Annotation_Tool_for_Ground_Truth_Creation)**: Portable, customizable, web-based annotation tool
3. **[Label Studio](https://labelstud.io/blog/do-i-need-to-build-a-ground-truth-dataset/)**: General-purpose annotation with graph relationship support
4. **Custom Script**: Lightweight JSON editor with validation schema

**Recommendation**: Start with **Label Studio** for rapid prototyping, export to JSON format.

#### 1.2.4 Inter-Annotator Agreement (IAA)

Have **2-3 annotators** label the same 20 documents independently, then measure agreement:

```python
# Cohen's Kappa for pairwise agreement
def calculate_kappa(annotator1, annotator2, items):
    """
    Calculate Cohen's Kappa for inter-annotator agreement.

    Args:
        annotator1, annotator2: Lists of binary decisions (1=present, 0=absent)
        items: List of items being annotated

    Returns:
        kappa: Agreement score (-1 to 1, where 1 is perfect agreement)
    """
    from sklearn.metrics import cohen_kappa_score
    return cohen_kappa_score(annotator1, annotator2)

# Example: Did both annotators identify the edge "doc1 -> doc2"?
annotator1_edges = [1, 1, 0, 1, 0, 1, 0, 0, 1, 1]  # 1=edge exists
annotator2_edges = [1, 1, 0, 1, 1, 1, 0, 0, 1, 0]

kappa = calculate_kappa(annotator1_edges, annotator2_edges, edges)
print(f"IAA Kappa: {kappa:.3f}")
# Target: Kappa >0.70 (substantial agreement)
```

**Reconciliation Process**:
- Kappa <0.60: Revise annotation guidelines (ambiguous criteria)
- Kappa 0.60-0.70: Discuss disagreements, create consensus labels
- Kappa >0.70: Proceed with annotations

#### 1.2.5 Ground Truth Validation Checklist

Before using ground truth for evaluation:

- [ ] **50-113 documents** annotated across stratified samples
- [ ] **Inter-annotator agreement** (Kappa >0.70) validated
- [ ] **Edge coverage**: At least 200-300 edges annotated (explicit + semantic)
- [ ] **Concept coverage**: At least 100-150 unique concepts identified
- [ ] **Annotation schema documented**: Clear guidelines for future updates
- [ ] **Edge cases documented**: Ambiguous cases with resolution notes
- [ ] **Version controlled**: Ground truth stored in git with versioning

---

## 2. Extraction Quality Metrics

### 2.1 Node Extraction Metrics

#### 2.1.1 Node Precision

**Definition**: Of all nodes extracted by the system, what percentage are correct?

$$
\text{Precision} = \frac{\text{True Positives}}{\text{True Positives} + \text{False Positives}}
$$

Where:
- **True Positive (TP)**: Node in ground truth AND extracted by system
- **False Positive (FP)**: Node extracted by system but NOT in ground truth
- **False Negative (FN)**: Node in ground truth but NOT extracted by system

**Example**:
```python
ground_truth_nodes = {'doc:auth/oauth.md', 'section:oauth#setup', 'concept:jwt'}
extracted_nodes = {'doc:auth/oauth.md', 'section:oauth#setup', 'concept:jwt', 'concept:nonsense'}

TP = len(ground_truth_nodes & extracted_nodes)  # 3
FP = len(extracted_nodes - ground_truth_nodes)   # 1 (nonsense)
FN = len(ground_truth_nodes - extracted_nodes)   # 0

precision = TP / (TP + FP)  # 3 / (3 + 1) = 0.75
```

**Target**: Precision >0.90 (no more than 10% junk nodes)

#### 2.1.2 Node Recall

**Definition**: Of all nodes in ground truth, what percentage did we find?

$$
\text{Recall} = \frac{\text{True Positives}}{\text{True Positives} + \text{False Negatives}}
$$

**Example**:
```python
recall = TP / (TP + FN)  # 3 / (3 + 0) = 1.0
```

**Target**: Recall >0.85 (find at least 85% of important nodes)

#### 2.1.3 Node F1 Score

Harmonic mean of precision and recall:

$$
\text{F1} = 2 \times \frac{\text{Precision} \times \text{Recall}}{\text{Precision} + \text{Recall}}
$$

**Target**: F1 >0.87

#### 2.1.4 Node Type Accuracy

Break down by node type:

```python
node_metrics = {
    'document': {'precision': 1.0, 'recall': 1.0, 'f1': 1.0},  # Easy (always correct)
    'section': {'precision': 0.95, 'recall': 0.92, 'f1': 0.935},  # Medium
    'concept': {'precision': 0.82, 'recall': 0.78, 'f1': 0.80},   # Hardest
    'topic_cluster': {'precision': 0.88, 'recall': 0.85, 'f1': 0.865}
}
```

**Critical**: Concept extraction is hardest. Use NER + pattern matching + manual review for high-value concepts.

### 2.2 Edge Extraction Metrics

#### 2.2.1 Edge Precision & Recall

Same formulas, but applied to edges:

```python
ground_truth_edges = {
    ('doc:auth/oauth.md', 'doc:auth/sessions.md', 'links_to'),
    ('section:oauth#setup', 'concept:jwt', 'mentions'),
    # ... more edges
}

extracted_edges = {
    ('doc:auth/oauth.md', 'doc:auth/sessions.md', 'links_to'),  # TP
    ('section:oauth#setup', 'concept:jwt', 'mentions'),         # TP
    ('doc:auth/oauth.md', 'doc:completely_unrelated.md', 'similar_to'),  # FP
}

# Calculate precision/recall/F1 same as nodes
```

**Targets**:
- **Explicit edges** (markdown links): Precision >0.90, Recall >0.85, F1 >0.87
- **Semantic edges** (similarity): Precision >0.75, Recall >0.70, F1 >0.72
- **Concept edges**: Precision >0.80, Recall >0.75, F1 >0.77

#### 2.2.2 Edge Weight Correlation

For edges with continuous weights (e.g., semantic similarity 0.0-1.0):

```python
import numpy as np
from scipy.stats import spearmanr

# Compare human-assigned weights vs. system weights
ground_truth_weights = [0.9, 0.8, 0.7, 0.6, 0.4, 0.3]
system_weights = [0.85, 0.82, 0.65, 0.55, 0.45, 0.28]

correlation, p_value = spearmanr(ground_truth_weights, system_weights)
print(f"Spearman correlation: {correlation:.3f}, p={p_value:.3e}")
# Target: correlation >0.75 (strong agreement on edge importance)
```

**Why Spearman?** Measures rank correlation (is ordering correct?), robust to outliers.

#### 2.2.3 Relationship Type Accuracy

For typed edges (depends_on, implements, similar_to, etc.):

```python
from sklearn.metrics import classification_report

ground_truth_types = ['depends_on', 'similar_to', 'depends_on', 'implements']
predicted_types = ['depends_on', 'similar_to', 'implements', 'implements']

report = classification_report(ground_truth_types, predicted_types)
print(report)

# Example output:
#                 precision    recall  f1-score   support
# depends_on          0.50      1.00      0.67         2
# similar_to          1.00      1.00      1.00         1
# implements          1.00      0.50      0.67         1
```

**Target**: Macro-averaged F1 >0.75 across all relationship types

### 2.3 False Positive/Negative Analysis

#### 2.3.1 False Positive Categories

Categorize FPs to understand failure modes:

```python
false_positive_categories = {
    'hallucination': {
        'count': 12,
        'description': 'Edge/node that doesn\'t exist in docs at all',
        'examples': ['concept:quantum_flux (never mentioned)']
    },
    'weak_signal': {
        'count': 28,
        'description': 'Extracted from passing mention, not significant',
        'examples': ['Similar_to edge from single shared word']
    },
    'context_misunderstanding': {
        'count': 7,
        'description': 'Extracted opposite relationship (e.g., "not dependent on")',
        'examples': ['Dependency extracted from negation context']
    },
    'duplicate': {
        'count': 15,
        'description': 'Extracted same relationship multiple times',
        'examples': ['doc1->doc2 link found in multiple sections']
    }
}

# Target: Total FP rate <5%
# Priority fixes: hallucination (critical), context_misunderstanding (critical)
```

#### 2.3.2 False Negative Categories

```python
false_negative_categories = {
    'implicit_relationship': {
        'count': 34,
        'description': 'Human inferred relationship, but no explicit signal',
        'examples': ['Two APIs always used together, but never explicitly linked']
    },
    'synonym_mismatch': {
        'count': 18,
        'description': 'Same concept, different terms',
        'examples': ['auth vs authentication vs AuthN']
    },
    'cross_document_inference': {
        'count': 22,
        'description': 'Requires reading 3+ docs to infer relationship',
        'examples': ['A mentions B, B mentions C, therefore A relates to C']
    },
    'temporal_dependency': {
        'count': 9,
        'description': 'Relationship expressed via temporal language',
        'examples': ['"Before configuring X, ensure Y is set up"']
    }
}

# Target: FN rate <15%
# Priority fixes: synonym_mismatch (NLP stemming), temporal_dependency (pattern matching)
```

---

## 3. Graph Quality Metrics

### 3.1 Structural Quality Metrics

Recent research identifies [six structural quality metrics that measure knowledge graph quality](https://arxiv.org/abs/2211.10011), analyzing major KGs including Wikidata, DBpedia, YAGO, and Freebase. We adapt these for documentation graphs.

#### 3.1.1 Completeness

**Definition**: What percentage of documentation is represented in the graph?

```python
def calculate_completeness(graph, corpus):
    """
    Measure graph completeness.

    Returns:
        - doc_coverage: % of documents with at least 1 node
        - section_coverage: % of H1-H3 sections represented
        - concept_coverage: % of high-TF-IDF terms extracted as concepts
    """
    total_docs = len(corpus.documents)
    docs_in_graph = len(graph.get_nodes(type='document'))
    doc_coverage = docs_in_graph / total_docs

    total_sections = sum(len(doc.sections) for doc in corpus.documents)
    sections_in_graph = len(graph.get_nodes(type='section'))
    section_coverage = sections_in_graph / total_sections

    # High-TF-IDF terms (top 500 across corpus)
    important_terms = corpus.get_top_terms(n=500, min_idf=2.0)
    concepts_in_graph = graph.get_nodes(type='concept')
    concept_coverage = len(set(concepts_in_graph) & set(important_terms)) / len(important_terms)

    return {
        'doc_coverage': doc_coverage,
        'section_coverage': section_coverage,
        'concept_coverage': concept_coverage,
        'overall_completeness': (doc_coverage + section_coverage + concept_coverage) / 3
    }

# Targets:
# - doc_coverage: >0.98 (nearly all docs)
# - section_coverage: >0.85 (major sections)
# - concept_coverage: >0.65 (most important concepts)
# - overall: >0.83
```

#### 3.1.2 Connectivity

**Definition**: Are nodes connected, or do we have isolated islands?

```python
import networkx as nx

def calculate_connectivity(graph):
    """
    Measure graph connectivity.

    Returns:
        - largest_component_ratio: % of nodes in largest connected component
        - num_components: Number of disconnected components
        - avg_clustering_coefficient: How clustered is the graph?
        - avg_path_length: Average shortest path between any two nodes
    """
    G = graph.to_networkx()  # Convert to NetworkX format

    # Connected components
    components = list(nx.connected_components(G.to_undirected()))
    largest = max(components, key=len)
    largest_ratio = len(largest) / G.number_of_nodes()

    # Clustering coefficient
    clustering = nx.average_clustering(G.to_undirected())

    # Average path length (only within largest component)
    largest_subgraph = G.subgraph(largest)
    if nx.is_connected(largest_subgraph.to_undirected()):
        avg_path = nx.average_shortest_path_length(largest_subgraph.to_undirected())
    else:
        avg_path = float('inf')

    return {
        'largest_component_ratio': largest_ratio,
        'num_components': len(components),
        'avg_clustering_coefficient': clustering,
        'avg_path_length': avg_path
    }

# Targets:
# - largest_component_ratio: >0.85 (85% nodes connected)
# - num_components: <50 (for 2000 docs)
# - avg_clustering_coefficient: >0.30 (documents cluster by topic)
# - avg_path_length: 3-6 (navigable graph)
```

**Why These Targets?**
- **85% connectivity**: Some isolated docs are expected (e.g., standalone tutorials)
- **Clustering >0.30**: Higher than random graphs (0.001 for scale-free), indicates topic clustering
- **Path length 3-6**: "Six degrees of separation" rule, ensures navigability

#### 3.1.3 Density

**Definition**: How many edges exist vs. how many are possible?

```python
def calculate_density(graph):
    """
    Measure graph density.

    Returns:
        - edge_density: Actual edges / possible edges
        - avg_degree: Average number of connections per node
        - degree_distribution: Histogram of node degrees
    """
    G = graph.to_networkx()

    # Density
    density = nx.density(G)

    # Average degree
    degrees = [d for n, d in G.degree()]
    avg_degree = sum(degrees) / len(degrees)

    # Degree distribution (for power-law analysis)
    degree_counts = {}
    for degree in degrees:
        degree_counts[degree] = degree_counts.get(degree, 0) + 1

    return {
        'edge_density': density,
        'avg_degree': avg_degree,
        'degree_distribution': degree_counts
    }

# Targets:
# - edge_density: 0.001-0.01 (sparse graph, typical for real networks)
# - avg_degree: 5-15 (each doc links to 5-15 others)
# - degree_distribution: Power-law (few hubs with many connections)
```

**Interpretation**:
- **Too high** (>0.05): Likely false positives, over-connecting
- **Too low** (<0.0005): Missing relationships, under-connecting

#### 3.1.4 Centrality Distribution

**Definition**: Which nodes are most important?

```python
def calculate_centrality_metrics(graph):
    """
    Measure node importance via centrality metrics.

    Returns:
        - pagerank: PageRank scores for all nodes
        - betweenness: Betweenness centrality (bridge nodes)
        - closeness: Closeness centrality (proximity to all nodes)
        - degree: Degree centrality (most connected)
    """
    G = graph.to_networkx()

    pagerank = nx.pagerank(G, alpha=0.85)
    betweenness = nx.betweenness_centrality(G)
    closeness = nx.closeness_centrality(G)
    degree_centrality = nx.degree_centrality(G)

    # Top 10 by each metric
    top_pagerank = sorted(pagerank.items(), key=lambda x: x[1], reverse=True)[:10]
    top_betweenness = sorted(betweenness.items(), key=lambda x: x[1], reverse=True)[:10]

    return {
        'pagerank': pagerank,
        'betweenness': betweenness,
        'closeness': closeness,
        'degree_centrality': degree_centrality,
        'top_pagerank': top_pagerank,
        'top_betweenness': top_betweenness
    }

# Validation:
# - Top PageRank nodes should match "important" docs (e.g., README, main config docs)
# - High betweenness nodes should be cross-cutting concerns (e.g., auth, logging)
# - Manual review: Do these rankings make sense?
```

### 3.2 Semantic Quality Metrics

#### 3.2.1 Clustering Coherence

**Definition**: Do topic clusters make semantic sense?

```python
from sklearn.metrics import silhouette_score

def calculate_clustering_coherence(graph):
    """
    Measure topic cluster quality.

    Uses Silhouette Score: measures how similar nodes are within clusters
    vs. to other clusters.

    Returns:
        - silhouette_score: -1 (bad) to 1 (perfect)
        - intra_cluster_similarity: Avg cosine sim within clusters
        - inter_cluster_distance: Avg distance between clusters
    """
    # Get document embeddings and cluster assignments
    embeddings = graph.get_node_embeddings(node_type='document')
    cluster_labels = graph.get_cluster_labels(node_type='document')

    # Silhouette score
    silhouette = silhouette_score(embeddings, cluster_labels, metric='cosine')

    # Intra-cluster similarity
    intra_sim = []
    for cluster_id in set(cluster_labels):
        cluster_docs = [emb for emb, label in zip(embeddings, cluster_labels) if label == cluster_id]
        if len(cluster_docs) > 1:
            # Pairwise cosine similarity
            from sklearn.metrics.pairwise import cosine_similarity
            sim_matrix = cosine_similarity(cluster_docs)
            # Average off-diagonal elements
            intra_sim.append((sim_matrix.sum() - len(cluster_docs)) / (len(cluster_docs) * (len(cluster_docs) - 1)))

    avg_intra_sim = sum(intra_sim) / len(intra_sim)

    return {
        'silhouette_score': silhouette,
        'intra_cluster_similarity': avg_intra_sim,
        'num_clusters': len(set(cluster_labels))
    }

# Targets:
# - silhouette_score: >0.40 (good clustering)
# - intra_cluster_similarity: >0.65 (docs in cluster are similar)
# - num_clusters: 15-30 (for 2000 docs, reasonable granularity)
```

#### 3.2.2 Concept Co-occurrence Validity

**Definition**: Do co-occurring concepts make sense?

```python
def validate_concept_cooccurrence(graph, ground_truth):
    """
    Check if high co-occurrence concept pairs are semantically valid.

    Method:
    1. Extract top 50 concept pairs by co-occurrence count
    2. Check against ground truth annotations
    3. Calculate precision of co-occurrence predictions
    """
    top_pairs = graph.get_top_concept_pairs(n=50, metric='cooccurrence')

    # Ground truth: which concept pairs are actually related?
    gt_pairs = ground_truth.get_related_concept_pairs()

    # Precision
    TP = len(set(top_pairs) & set(gt_pairs))
    precision = TP / len(top_pairs)

    # Also calculate for different thresholds
    thresholds = [10, 20, 50, 100]
    results = {}
    for threshold in thresholds:
        pairs = graph.get_top_concept_pairs(n=threshold, metric='cooccurrence')
        tp = len(set(pairs) & set(gt_pairs))
        results[f'precision@{threshold}'] = tp / len(pairs)

    return results

# Target: precision@50 >0.75 (top 50 pairs are mostly valid)
```

### 3.3 Consistency Metrics

#### 3.3.1 Symmetry Consistency

For symmetric relationships (e.g., "similar_to"), check symmetry:

```python
def check_symmetry(graph):
    """
    For symmetric edge types, ensure A->B implies B->A.
    """
    symmetric_types = ['similar_to', 'related_to', 'co_occurs_with']
    violations = []

    for edge_type in symmetric_types:
        edges = graph.get_edges(type=edge_type)
        for (source, target, props) in edges:
            # Check reverse edge exists
            reverse = graph.get_edge(target, source, type=edge_type)
            if not reverse:
                violations.append((source, target, edge_type))

    consistency_rate = 1 - (len(violations) / len(edges))
    return {
        'symmetry_consistency': consistency_rate,
        'violations': violations[:10]  # Show first 10
    }

# Target: consistency >0.95 (allow 5% tolerance for edge cases)
```

#### 3.3.2 Transitivity Consistency

For transitive relationships (e.g., "part_of"):

```python
def check_transitivity(graph):
    """
    For transitive edge types, check if A->B and B->C implies A->C.
    """
    transitive_types = ['part_of', 'subsumes', 'depends_on']
    implied_edges = []
    missing = []

    for edge_type in transitive_types:
        edges = graph.get_edges(type=edge_type)
        # Build transitive closure
        for (A, B, _) in edges:
            for (B2, C, _) in edges:
                if B == B2:  # A->B->C chain
                    implied = graph.get_edge(A, C, type=edge_type)
                    if implied:
                        implied_edges.append((A, C))
                    else:
                        missing.append((A, C))

    completeness = len(implied_edges) / (len(implied_edges) + len(missing)) if (len(implied_edges) + len(missing)) > 0 else 1.0
    return {
        'transitivity_completeness': completeness,
        'missing_implied_edges': len(missing)
    }

# Note: Low completeness is OKAY (transitivity is often implicit)
# Target: Just document the number, don't enforce strict threshold
```

---

## 4. Functional Validation

### 4.1 Test Query Framework

Functional validation proves the graph **solves real problems**. Use the 10 test cases from the [Knowledge Graph proposal](/Users/alphab/Dev/LLM/DEV/TMP/nancy/research/pudding/proposal-knowledge-graph.md).

#### 4.1.1 Query Test Format

```python
class GraphQueryTest:
    def __init__(self, id, name, query, expected_results, success_criteria):
        self.id = id
        self.name = name
        self.query = query  # Natural language or Cypher
        self.expected_results = expected_results  # List of expected node/edge IDs
        self.success_criteria = success_criteria  # Dict of metric thresholds

    def execute(self, graph):
        """Run query and evaluate results."""
        results = graph.query(self.query)
        metrics = self.evaluate(results)
        return {
            'test_id': self.id,
            'passed': all(metrics[k] >= v for k, v in self.success_criteria.items()),
            'metrics': metrics,
            'results': results
        }

    def evaluate(self, results):
        """Calculate precision, recall, NDCG."""
        # Precision: % of returned results that are in expected_results
        relevant_returned = [r for r in results if r.id in self.expected_results]
        precision = len(relevant_returned) / len(results) if len(results) > 0 else 0

        # Recall: % of expected_results that were returned
        recall = len(relevant_returned) / len(self.expected_results) if len(self.expected_results) > 0 else 0

        # F1
        f1 = 2 * precision * recall / (precision + recall) if (precision + recall) > 0 else 0

        # NDCG: Normalized Discounted Cumulative Gain (ranking quality)
        ndcg = self.calculate_ndcg(results)

        return {
            'precision': precision,
            'recall': recall,
            'f1': f1,
            'ndcg': ndcg
        }

    def calculate_ndcg(self, results):
        """Calculate NDCG for ranking quality."""
        from sklearn.metrics import ndcg_score
        # Assume expected_results are ranked by relevance
        relevance_scores = [1 if r.id in self.expected_results else 0 for r in results]
        ideal_scores = sorted(relevance_scores, reverse=True)

        if sum(ideal_scores) == 0:
            return 0.0

        return ndcg_score([ideal_scores], [relevance_scores])
```

#### 4.1.2 Test Case Examples

**Test Case 1: Dependency Discovery (2-hop query)**

```python
test1 = GraphQueryTest(
    id='TC001',
    name='Dependency Chains',
    query='What features depend on the session management system?',
    expected_results=[
        'doc:auth/oauth.md',
        'doc:api/authentication.md',
        'doc:user/preferences.md',
        'doc:admin/user_management.md'
    ],
    success_criteria={
        'precision': 0.85,
        'recall': 0.80,
        'ndcg': 0.80
    }
)

# Cypher equivalent (if using Neo4j):
cypher_query = """
MATCH (session:Concept {name: 'session management'})<-[:MENTIONS]-(section:Section)<-[:CONTAINS]-(doc:Document)
WHERE section.context CONTAINS 'depends on' OR section.context CONTAINS 'requires'
RETURN DISTINCT doc.filePath, doc.title
ORDER BY COUNT(*) DESC
LIMIT 10
"""
```

**Test Case 5: Error Propagation (3+ hop query)**

```python
test5 = GraphQueryTest(
    id='TC005',
    name='Error Propagation Paths',
    query='If database timeout occurs, which systems are affected and in what order?',
    expected_results=[
        ('concept:database_timeout', 'doc:db/connection_pooling.md'),  # Direct mention
        ('doc:db/connection_pooling.md', 'doc:api/endpoints.md'),      # Dependency
        ('doc:api/endpoints.md', 'doc:frontend/error_handling.md')     # Cascading
    ],
    success_criteria={
        'precision': 0.75,
        'recall': 0.70,
        'path_accuracy': 0.80  # % of paths that match expected order
    }
)

# Cypher: Multi-hop traversal
cypher_query = """
MATCH path = (error:Concept {name: 'database timeout'})-[:MENTIONED_IN*1..4]-(affected:Document)
WHERE ANY(rel IN relationships(path) WHERE type(rel) = 'DEPENDS_ON' OR type(rel) = 'LINKS_TO')
RETURN path, length(path) as depth
ORDER BY depth ASC
"""
```

**Test Case 7: Orphan Detection (negative query)**

```python
test7 = GraphQueryTest(
    id='TC007',
    name='Orphan Concept Detection',
    query='Which major concepts are mentioned frequently but never fully documented?',
    expected_results=[
        'concept:rate_limiting',   # Mentioned 23 times, no dedicated doc
        'concept:webhook_retry',   # Mentioned 15 times, no dedicated doc
        'concept:api_versioning'   # Mentioned 31 times, no dedicated doc
    ],
    success_criteria={
        'precision': 0.90,  # Few false positives
        'recall': 0.70      # Find most orphans
    }
)

# Cypher: Concepts with high mentions but no definition
cypher_query = """
MATCH (concept:Concept)-[m:MENTIONS]->(section:Section)
WITH concept, COUNT(m) as mention_count
WHERE mention_count > 10
  AND NOT EXISTS {
    MATCH (concept)<-[:DEFINES]-(section)
  }
  AND NOT EXISTS {
    MATCH (doc:Document {title: concept.name})
  }
RETURN concept.name, mention_count
ORDER BY mention_count DESC
LIMIT 10
"""
```

#### 4.1.3 Test Suite Execution

```python
def run_test_suite(graph, tests):
    """
    Execute all test cases and generate report.
    """
    results = []
    for test in tests:
        print(f"Running {test.id}: {test.name}...")
        result = test.execute(graph)
        results.append(result)

        # Print summary
        status = "✓ PASS" if result['passed'] else "✗ FAIL"
        print(f"  {status} - Precision: {result['metrics']['precision']:.2f}, "
              f"Recall: {result['metrics']['recall']:.2f}")

    # Overall statistics
    passed = sum(1 for r in results if r['passed'])
    total = len(results)
    pass_rate = passed / total

    print(f"\n{'='*60}")
    print(f"Test Suite Summary: {passed}/{total} passed ({pass_rate:.1%})")
    print(f"{'='*60}")

    return {
        'results': results,
        'pass_rate': pass_rate,
        'passed': passed,
        'total': total
    }

# Target: pass_rate >0.85 (85% of test cases pass)
```

### 4.2 Regression Testing

**Goal**: Ensure changes don't break existing functionality.

```python
class RegressionTestSuite:
    def __init__(self, baseline_graph, test_queries):
        self.baseline = baseline_graph
        self.test_queries = test_queries
        self.baseline_results = self._run_baseline()

    def _run_baseline(self):
        """Run all queries on baseline graph, store results."""
        results = {}
        for query in self.test_queries:
            results[query.id] = self.baseline.query(query.cypher)
        return results

    def test_regression(self, new_graph):
        """
        Compare new graph results to baseline.

        Flags:
        - Missing results (recall drop)
        - New results (precision change)
        - Ranking changes (NDCG drop)
        """
        regressions = []

        for query in self.test_queries:
            baseline_result = self.baseline_results[query.id]
            new_result = new_graph.query(query.cypher)

            # Compare result sets
            baseline_ids = set(r.id for r in baseline_result)
            new_ids = set(r.id for r in new_result)

            # Check for regressions
            missing = baseline_ids - new_ids
            added = new_ids - baseline_ids

            if len(missing) > 0.1 * len(baseline_ids):  # >10% results missing
                regressions.append({
                    'query_id': query.id,
                    'type': 'recall_drop',
                    'missing_count': len(missing),
                    'missing_ids': list(missing)[:5]
                })

            # Check ranking changes
            baseline_rank = {r.id: i for i, r in enumerate(baseline_result)}
            new_rank = {r.id: i for i, r in enumerate(new_result)}

            rank_changes = []
            for result_id in baseline_ids & new_ids:
                old_pos = baseline_rank[result_id]
                new_pos = new_rank[result_id]
                if abs(old_pos - new_pos) > 3:  # Moved >3 positions
                    rank_changes.append((result_id, old_pos, new_pos))

            if len(rank_changes) > 0.2 * len(baseline_ids):  # >20% ranks changed
                regressions.append({
                    'query_id': query.id,
                    'type': 'ranking_change',
                    'changes': rank_changes[:5]
                })

        return {
            'regressions_found': len(regressions),
            'regressions': regressions,
            'passed': len(regressions) == 0
        }

# Run regression tests before merging changes
# Target: Zero regressions
```

---

## 5. Performance Benchmarks

### 5.1 Build Time Targets

```python
def benchmark_build_time(corpus_size):
    """
    Measure graph construction time.

    Corpus sizes: 100, 500, 1000, 2000 docs
    """
    import time

    print(f"Building graph for {corpus_size} documents...")
    start = time.time()

    # Phase 1: Node extraction
    phase1_start = time.time()
    nodes = extract_nodes(corpus_size)
    phase1_time = time.time() - phase1_start

    # Phase 2: Explicit edges
    phase2_start = time.time()
    explicit_edges = extract_explicit_edges(nodes)
    phase2_time = time.time() - phase2_start

    # Phase 3: Semantic edges (most expensive)
    phase3_start = time.time()
    semantic_edges = compute_semantic_similarity(nodes, threshold=0.65)
    phase3_time = time.time() - phase3_start

    # Phase 4: Clustering
    phase4_start = time.time()
    clusters = cluster_documents(nodes)
    phase4_time = time.time() - phase4_start

    total_time = time.time() - start

    return {
        'corpus_size': corpus_size,
        'total_time': total_time,
        'phase1_node_extraction': phase1_time,
        'phase2_explicit_edges': phase2_time,
        'phase3_semantic_edges': phase3_time,
        'phase4_clustering': phase4_time,
        'time_per_doc': total_time / corpus_size
    }

# Targets:
benchmark_targets = {
    100: {'total': 60, 'per_doc': 0.6},      # 1 minute for 100 docs
    500: {'total': 240, 'per_doc': 0.48},    # 4 minutes for 500 docs
    1000: {'total': 420, 'per_doc': 0.42},   # 7 minutes for 1000 docs
    2000: {'total': 600, 'per_doc': 0.30}    # 10 minutes for 2000 docs (target)
}
```

**Optimization Priorities**:
1. **Phase 3 (semantic edges)** is bottleneck: Use batch processing, GPU acceleration, or approximate nearest neighbors (HNSW)
2. **Phase 4 (clustering)** can be parallelized: Use mini-batch K-means or Louvain
3. **Incremental updates**: Don't rebuild from scratch, only process changed docs

### 5.2 Query Latency Targets

```python
def benchmark_query_latency(graph, num_queries=1000):
    """
    Measure query performance across different query types.
    """
    query_types = {
        'simple_lookup': "MATCH (doc:Document {id: 'auth/oauth.md'}) RETURN doc",
        'one_hop': "MATCH (doc:Document)-[:LINKS_TO]->(neighbor) WHERE doc.id = 'auth/oauth.md' RETURN neighbor",
        'two_hop': "MATCH (doc)-[:LINKS_TO*2]->(neighbor) WHERE doc.id = 'auth/oauth.md' RETURN DISTINCT neighbor",
        'concept_search': "MATCH (concept:Concept {name: 'authentication'})<-[:MENTIONS]-(section)<-[:CONTAINS]-(doc) RETURN doc",
        'complex_filter': "MATCH (doc:Document)-[:BELONGS_TO]->(cluster:TopicCluster) WHERE cluster.label = 'authentication' AND doc.tokens > 1000 RETURN doc"
    }

    latencies = {qt: [] for qt in query_types}

    for query_type, query in query_types.items():
        for _ in range(num_queries):
            start = time.perf_counter()
            result = graph.query(query)
            latency = (time.perf_counter() - start) * 1000  # ms
            latencies[query_type].append(latency)

    # Calculate percentiles
    import numpy as np
    results = {}
    for query_type, times in latencies.items():
        results[query_type] = {
            'p50': np.percentile(times, 50),
            'p95': np.percentile(times, 95),
            'p99': np.percentile(times, 99),
            'mean': np.mean(times)
        }

    return results

# Targets:
latency_targets = {
    'simple_lookup': {'p50': 1, 'p95': 5, 'p99': 10},      # <1ms median
    'one_hop': {'p50': 5, 'p95': 15, 'p99': 30},            # <5ms median
    'two_hop': {'p50': 15, 'p95': 50, 'p99': 100},          # <15ms median
    'concept_search': {'p50': 10, 'p95': 30, 'p99': 60},    # <10ms median
    'complex_filter': {'p50': 20, 'p95': 100, 'p99': 200}   # <20ms median
}
```

### 5.3 Memory Usage Limits

```python
import psutil
import os

def benchmark_memory_usage(graph):
    """
    Measure memory footprint during graph operations.
    """
    process = psutil.Process(os.getpid())

    # Baseline memory
    baseline = process.memory_info().rss / 1024 / 1024  # MB

    # After graph load
    graph.load()
    after_load = process.memory_info().rss / 1024 / 1024

    # During query (peak)
    peak_memory = baseline
    for _ in range(100):
        graph.query_heavy()  # Execute expensive query
        current = process.memory_info().rss / 1024 / 1024
        peak_memory = max(peak_memory, current)

    return {
        'baseline_mb': baseline,
        'after_load_mb': after_load,
        'graph_size_mb': after_load - baseline,
        'peak_mb': peak_memory,
        'peak_overhead_mb': peak_memory - after_load
    }

# Targets (for 2000 docs):
memory_targets = {
    'graph_size_mb': 500,      # <500MB for graph data
    'peak_mb': 1000,            # <1GB peak during queries
    'mb_per_doc': 0.25          # <0.25MB per document
}
```

### 5.4 Scalability Testing

```python
def scalability_test():
    """
    Test performance at increasing scales.
    """
    corpus_sizes = [100, 500, 1000, 2000, 5000]
    results = []

    for size in corpus_sizes:
        print(f"\nTesting {size} documents...")

        # Build graph
        build_time = benchmark_build_time(size)

        # Query performance
        query_latency = benchmark_query_latency(graph, num_queries=100)

        # Memory usage
        memory = benchmark_memory_usage(graph)

        results.append({
            'size': size,
            'build_time': build_time['total_time'],
            'query_p95': query_latency['two_hop']['p95'],
            'memory_mb': memory['graph_size_mb']
        })

    # Check for linear scaling
    import numpy as np
    sizes = [r['size'] for r in results]
    build_times = [r['build_time'] for r in results]

    # Fit linear model: build_time = a * size + b
    coeffs = np.polyfit(sizes, build_times, 1)
    print(f"\nBuild time scaling: {coeffs[0]:.3f} * size + {coeffs[1]:.1f}")

    # Target: Near-linear (coefficient ~0.3 s/doc)

    return results
```

---

## 6. Automated Testing Suite

### 6.1 Unit Tests

```python
# tests/unit/test_node_extraction.py

import pytest
from knowledge_graph.extractors import NodeExtractor

class TestNodeExtraction:
    """Unit tests for node extraction."""

    def test_extract_document_nodes(self):
        """Test document node extraction."""
        corpus = load_test_corpus(n_docs=10)
        extractor = NodeExtractor()

        nodes = extractor.extract_documents(corpus)

        assert len(nodes) == 10
        assert all(node.type == 'document' for node in nodes)
        assert all('filePath' in node.properties for node in nodes)

    def test_extract_section_nodes(self):
        """Test section node extraction from markdown."""
        doc = """
        # Top Level
        ## Subsection 1
        ### Deep Section
        ## Subsection 2
        """
        extractor = NodeExtractor()

        sections = extractor.extract_sections(doc)

        assert len(sections) == 4
        assert sections[0].level == 1
        assert sections[1].level == 2
        assert sections[2].level == 3

    def test_extract_concepts_with_ner(self):
        """Test concept extraction using NER."""
        text = "OAuth authentication uses JWT tokens for session management."
        extractor = NodeExtractor(use_ner=True)

        concepts = extractor.extract_concepts(text)

        # Should find "OAuth", "JWT", "session management"
        concept_names = [c.name for c in concepts]
        assert 'OAuth' in concept_names
        assert 'JWT' in concept_names

    def test_concept_deduplication(self):
        """Test concept deduplication (OAuth = oauth = OAUTH)."""
        text1 = "OAuth is great"
        text2 = "oauth is used"
        text3 = "OAUTH authentication"

        extractor = NodeExtractor(normalize=True)
        concepts1 = extractor.extract_concepts(text1)
        concepts2 = extractor.extract_concepts(text2)
        concepts3 = extractor.extract_concepts(text3)

        # All should map to same normalized concept
        assert concepts1[0].normalized_name == concepts2[0].normalized_name
        assert concepts2[0].normalized_name == concepts3[0].normalized_name
```

```python
# tests/unit/test_edge_extraction.py

class TestEdgeExtraction:
    """Unit tests for edge extraction."""

    def test_extract_explicit_links(self):
        """Test markdown link extraction."""
        doc = "See [session management](../auth/sessions.md) for details."
        extractor = EdgeExtractor()

        edges = extractor.extract_explicit_links(doc, source_id='doc1')

        assert len(edges) == 1
        assert edges[0].target == '../auth/sessions.md'
        assert edges[0].type == 'links_to'
        assert edges[0].weight == 1.0

    def test_semantic_similarity_edges(self):
        """Test semantic similarity edge creation."""
        doc1_embedding = [0.1, 0.2, 0.3, ...]  # 384-dim
        doc2_embedding = [0.11, 0.21, 0.31, ...]  # Similar
        doc3_embedding = [0.9, 0.8, 0.7, ...]  # Different

        extractor = EdgeExtractor(similarity_threshold=0.65)

        # Should create edge between doc1 and doc2
        edge_12 = extractor.compute_similarity(doc1_embedding, doc2_embedding)
        assert edge_12 is not None
        assert edge_12.weight > 0.65

        # Should NOT create edge between doc1 and doc3
        edge_13 = extractor.compute_similarity(doc1_embedding, doc3_embedding)
        assert edge_13 is None

    def test_dependency_pattern_matching(self):
        """Test dependency relationship extraction via patterns."""
        text = "This feature depends on the session management module."
        extractor = EdgeExtractor(enable_patterns=True)

        edges = extractor.extract_dependency_patterns(text, source='feature1')

        assert len(edges) == 1
        assert edges[0].type == 'depends_on'
        assert 'session management' in edges[0].target
```

### 6.2 Integration Tests

```python
# tests/integration/test_graph_construction.py

class TestGraphConstruction:
    """Integration tests for end-to-end graph construction."""

    def test_full_pipeline(self):
        """Test complete graph construction pipeline."""
        corpus = load_test_corpus(n_docs=100)

        # Phase 1: Extract nodes
        nodes = extract_all_nodes(corpus)
        assert len(nodes) > 100  # Docs + sections + concepts

        # Phase 2: Extract edges
        edges = extract_all_edges(nodes, corpus)
        assert len(edges) > 0

        # Phase 3: Build graph
        graph = KnowledgeGraph()
        graph.add_nodes(nodes)
        graph.add_edges(edges)

        # Validate graph structure
        assert graph.num_nodes() > 100
        assert graph.num_edges() > 0
        assert graph.is_connected() or graph.largest_component_ratio() > 0.80

    def test_incremental_update(self):
        """Test incremental graph updates (don't rebuild from scratch)."""
        # Build initial graph
        corpus_v1 = load_test_corpus(n_docs=50)
        graph = build_graph(corpus_v1)

        initial_nodes = graph.num_nodes()

        # Add 10 new documents
        corpus_v2 = load_test_corpus(n_docs=60)  # 50 old + 10 new
        graph_updated = update_graph(graph, corpus_v2)

        # Should only add new nodes, not rebuild everything
        assert graph_updated.num_nodes() > initial_nodes
        assert graph_updated.num_nodes() < initial_nodes * 1.3  # Not a full rebuild

    def test_graph_persistence(self):
        """Test saving and loading graph from disk."""
        graph = build_test_graph(n_docs=100)

        # Save to disk
        graph.save('test_graph.json')

        # Load from disk
        loaded_graph = KnowledgeGraph.load('test_graph.json')

        # Validate identical
        assert loaded_graph.num_nodes() == graph.num_nodes()
        assert loaded_graph.num_edges() == graph.num_edges()
```

### 6.3 Validation Tests

```python
# tests/validation/test_ground_truth.py

class TestGroundTruthValidation:
    """Tests comparing graph to ground truth annotations."""

    def test_node_precision_recall(self):
        """Test node extraction against ground truth."""
        ground_truth = load_ground_truth('annotations/gt_docs_1-50.json')
        graph = build_graph(corpus_subset_1_50)

        metrics = calculate_node_metrics(graph, ground_truth)

        assert metrics['precision'] > 0.90
        assert metrics['recall'] > 0.85
        assert metrics['f1'] > 0.87

    def test_edge_precision_recall_explicit(self):
        """Test explicit edge extraction against ground truth."""
        ground_truth = load_ground_truth('annotations/gt_docs_1-50.json')
        graph = build_graph(corpus_subset_1_50)

        metrics = calculate_edge_metrics(graph, ground_truth, edge_type='explicit')

        assert metrics['precision'] > 0.85
        assert metrics['recall'] > 0.80
        assert metrics['f1'] > 0.82

    def test_edge_precision_recall_semantic(self):
        """Test semantic edge extraction against ground truth."""
        ground_truth = load_ground_truth('annotations/gt_docs_1-50.json')
        graph = build_graph(corpus_subset_1_50)

        metrics = calculate_edge_metrics(graph, ground_truth, edge_type='semantic')

        # Semantic edges are harder, lower threshold
        assert metrics['precision'] > 0.70
        assert metrics['recall'] > 0.65
        assert metrics['f1'] > 0.67

    def test_false_positive_analysis(self):
        """Analyze categories of false positives."""
        ground_truth = load_ground_truth('annotations/gt_docs_1-50.json')
        graph = build_graph(corpus_subset_1_50)

        fp_analysis = analyze_false_positives(graph, ground_truth)

        # Total FP rate <5%
        assert fp_analysis['fp_rate'] < 0.05

        # Zero hallucinations (critical)
        assert fp_analysis['categories']['hallucination'] == 0
```

### 6.4 Performance Tests

```python
# tests/performance/test_benchmarks.py

import pytest

class TestPerformance:
    """Performance benchmark tests."""

    @pytest.mark.slow
    def test_build_time_2000_docs(self):
        """Test graph construction time for 2000 documents."""
        corpus = load_full_corpus(n_docs=2000)

        start = time.time()
        graph = build_graph(corpus)
        duration = time.time() - start

        # Target: <10 minutes
        assert duration < 600

    def test_query_latency_p95(self):
        """Test query latency percentiles."""
        graph = load_test_graph()

        latencies = benchmark_query_latency(graph, num_queries=1000)

        # P95 latency <100ms for 2-hop queries
        assert latencies['two_hop']['p95'] < 100

    def test_memory_usage(self):
        """Test memory footprint."""
        graph = build_graph(corpus_2000)

        memory = benchmark_memory_usage(graph)

        # <500MB for graph data
        assert memory['graph_size_mb'] < 500

### 6.5 CI/CD Integration

```yaml
# .github/workflows/knowledge-graph-validation.yml

name: Knowledge Graph Validation

on:
  pull_request:
    paths:
      - 'src/knowledge_graph/**'
      - 'tests/**'
  push:
    branches: [main]

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: |
          pip install -r requirements.txt
          pip install pytest pytest-cov

      - name: Run unit tests
        run: pytest tests/unit/ -v --cov=knowledge_graph --cov-report=xml

      - name: Upload coverage
        uses: codecov/codecov-action@v3

  integration-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Run integration tests
        run: pytest tests/integration/ -v

  validation-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Download ground truth
        run: |
          # Download ground truth annotations from storage
          aws s3 cp s3://mdcontext-validation/ground_truth.json ./annotations/

      - name: Run validation tests
        run: pytest tests/validation/ -v

      - name: Check metrics thresholds
        run: |
          python scripts/validate_metrics.py \
            --min-node-precision 0.90 \
            --min-edge-precision 0.85 \
            --min-query-accuracy 0.85

      - name: Fail if thresholds not met
        if: failure()
        run: exit 1

  performance-tests:
    runs-on: ubuntu-latest
    if: github.event_name == 'push'  # Only on main branch
    steps:
      - uses: actions/checkout@v3

      - name: Run performance benchmarks
        run: pytest tests/performance/ -v --benchmark-only

      - name: Compare with baseline
        run: |
          python scripts/compare_benchmarks.py \
            --current results.json \
            --baseline benchmarks/baseline.json
```

---

## 7. Metrics Dashboard

### 7.1 What to Track Continuously

**Graph Construction Metrics** (computed during build):
```python
construction_metrics = {
    'build_time_seconds': 547.2,
    'nodes': {
        'total': 2847,
        'documents': 2000,
        'sections': 6432,
        'concepts': 523,
        'topic_clusters': 24
    },
    'edges': {
        'total': 18453,
        'explicit_links': 3245,
        'semantic_links': 7821,
        'concept_mentions': 6234,
        'cluster_memberships': 2000
    },
    'graph_properties': {
        'density': 0.0023,
        'avg_degree': 6.48,
        'largest_component_ratio': 0.89,
        'num_components': 34,
        'avg_clustering_coefficient': 0.32,
        'avg_path_length': 4.7
    }
}
```

**Validation Metrics** (computed against ground truth):
```python
validation_metrics = {
    'node_extraction': {
        'precision': 0.92,
        'recall': 0.88,
        'f1': 0.90
    },
    'edge_extraction_explicit': {
        'precision': 0.87,
        'recall': 0.83,
        'f1': 0.85
    },
    'edge_extraction_semantic': {
        'precision': 0.73,
        'recall': 0.69,
        'f1': 0.71
    },
    'false_positive_rate': 0.04,
    'false_negative_rate': 0.12,
    'hallucination_count': 0
}
```

**Query Performance Metrics** (computed from test suite):
```python
query_metrics = {
    'test_suite_pass_rate': 0.90,  # 9/10 tests passed
    'avg_precision': 0.86,
    'avg_recall': 0.81,
    'avg_ndcg': 0.83,
    'failed_tests': ['TC010'],  # Concept evolution tracking
    'query_latency_p95_ms': 87.3
}
```

### 7.2 Dashboard Implementation

```python
# scripts/generate_dashboard.py

import json
import matplotlib.pyplot as plt
import seaborn as sns

def generate_metrics_dashboard(metrics_file='metrics/latest.json'):
    """
    Generate HTML dashboard with visualizations.
    """
    with open(metrics_file) as f:
        metrics = json.load(f)

    fig, axes = plt.subplots(2, 3, figsize=(18, 12))

    # 1. Node/Edge counts
    ax1 = axes[0, 0]
    categories = ['Documents', 'Sections', 'Concepts', 'Clusters']
    counts = [
        metrics['nodes']['documents'],
        metrics['nodes']['sections'],
        metrics['nodes']['concepts'],
        metrics['nodes']['topic_clusters']
    ]
    ax1.bar(categories, counts, color='steelblue')
    ax1.set_title('Node Counts by Type')
    ax1.set_ylabel('Count')

    # 2. Precision/Recall/F1 comparison
    ax2 = axes[0, 1]
    metrics_types = ['Nodes', 'Explicit Edges', 'Semantic Edges']
    precision = [
        metrics['validation']['node_extraction']['precision'],
        metrics['validation']['edge_extraction_explicit']['precision'],
        metrics['validation']['edge_extraction_semantic']['precision']
    ]
    recall = [
        metrics['validation']['node_extraction']['recall'],
        metrics['validation']['edge_extraction_explicit']['recall'],
        metrics['validation']['edge_extraction_semantic']['recall']
    ]
    f1 = [
        metrics['validation']['node_extraction']['f1'],
        metrics['validation']['edge_extraction_explicit']['f1'],
        metrics['validation']['edge_extraction_semantic']['f1']
    ]

    x = range(len(metrics_types))
    width = 0.25
    ax2.bar([i - width for i in x], precision, width, label='Precision', color='green')
    ax2.bar(x, recall, width, label='Recall', color='blue')
    ax2.bar([i + width for i in x], f1, width, label='F1', color='orange')
    ax2.set_xticks(x)
    ax2.set_xticklabels(metrics_types, rotation=15)
    ax2.set_title('Extraction Quality Metrics')
    ax2.set_ylabel('Score')
    ax2.legend()
    ax2.axhline(y=0.85, color='r', linestyle='--', label='Target')

    # 3. Graph connectivity
    ax3 = axes[0, 2]
    connectivity_metrics = [
        ('Largest Component', metrics['graph_properties']['largest_component_ratio']),
        ('Clustering Coeff', metrics['graph_properties']['avg_clustering_coefficient']),
        ('Target', 0.85)
    ]
    labels = [m[0] for m in connectivity_metrics[:2]]
    values = [m[1] for m in connectivity_metrics[:2]]
    colors = ['green' if v >= 0.85 else 'orange' if v >= 0.75 else 'red' for v in values]
    ax3.barh(labels, values, color=colors)
    ax3.set_xlim(0, 1)
    ax3.axvline(x=0.85, color='r', linestyle='--', label='Target')
    ax3.set_title('Graph Connectivity Metrics')

    # 4. Query performance (test suite)
    ax4 = axes[1, 0]
    test_results = [9, 1]  # Passed, Failed
    ax4.pie(test_results, labels=['Passed (90%)', 'Failed (10%)'], autopct='%1.0f%%', colors=['green', 'red'])
    ax4.set_title('Test Suite Results')

    # 5. Query latency distribution
    ax5 = axes[1, 1]
    query_types = ['1-hop', '2-hop', '3-hop', 'Concept', 'Filter']
    p50 = [5, 15, 35, 10, 20]
    p95 = [15, 50, 120, 30, 100]
    p99 = [30, 100, 250, 60, 200]

    x = range(len(query_types))
    ax5.plot(x, p50, 'o-', label='P50', color='green')
    ax5.plot(x, p95, 's-', label='P95', color='orange')
    ax5.plot(x, p99, '^-', label='P99', color='red')
    ax5.set_xticks(x)
    ax5.set_xticklabels(query_types, rotation=15)
    ax5.set_ylabel('Latency (ms)')
    ax5.set_title('Query Latency by Type')
    ax5.axhline(y=100, color='r', linestyle='--', label='P95 Target')
    ax5.legend()
    ax5.set_yscale('log')

    # 6. Build time scaling
    ax6 = axes[1, 2]
    corpus_sizes = [100, 500, 1000, 2000]
    build_times = [58, 235, 418, 547]
    ax6.plot(corpus_sizes, build_times, 'o-', color='steelblue', linewidth=2)
    ax6.set_xlabel('Corpus Size (docs)')
    ax6.set_ylabel('Build Time (seconds)')
    ax6.set_title('Build Time Scalability')
    ax6.axhline(y=600, color='r', linestyle='--', label='Target (<10 min)')
    ax6.legend()

    plt.tight_layout()
    plt.savefig('dashboard/metrics_dashboard.png', dpi=150)
    print("Dashboard saved to dashboard/metrics_dashboard.png")

    # Generate HTML report
    html = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>Knowledge Graph Validation Dashboard</title>
        <style>
            body {{ font-family: Arial, sans-serif; margin: 40px; }}
            h1 {{ color: #333; }}
            .metrics-grid {{ display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }}
            .metric-card {{ border: 1px solid #ddd; padding: 20px; border-radius: 8px; }}
            .status-ok {{ color: green; }}
            .status-warn {{ color: orange; }}
            .status-fail {{ color: red; }}
        </style>
    </head>
    <body>
        <h1>Knowledge Graph Validation Dashboard</h1>
        <p><strong>Generated:</strong> {metrics.get('timestamp', 'N/A')}</p>

        <div class="metrics-grid">
            <div class="metric-card">
                <h3>Node Extraction</h3>
                <p>Precision: <span class="status-ok">{metrics['validation']['node_extraction']['precision']:.2f}</span></p>
                <p>Recall: <span class="status-ok">{metrics['validation']['node_extraction']['recall']:.2f}</span></p>
                <p>F1 Score: <span class="status-ok">{metrics['validation']['node_extraction']['f1']:.2f}</span></p>
            </div>

            <div class="metric-card">
                <h3>Edge Extraction (Explicit)</h3>
                <p>Precision: <span class="status-ok">{metrics['validation']['edge_extraction_explicit']['precision']:.2f}</span></p>
                <p>Recall: <span class="status-ok">{metrics['validation']['edge_extraction_explicit']['recall']:.2f}</span></p>
                <p>F1 Score: <span class="status-ok">{metrics['validation']['edge_extraction_explicit']['f1']:.2f}</span></p>
            </div>

            <div class="metric-card">
                <h3>Graph Quality</h3>
                <p>Connectivity: <span class="status-ok">{metrics['graph_properties']['largest_component_ratio']:.2f}</span></p>
                <p>Clustering Coeff: <span class="status-warn">{metrics['graph_properties']['avg_clustering_coefficient']:.2f}</span></p>
                <p>Avg Path Length: <span class="status-ok">{metrics['graph_properties']['avg_path_length']:.1f}</span></p>
            </div>

            <div class="metric-card">
                <h3>Query Performance</h3>
                <p>Test Pass Rate: <span class="status-ok">{metrics['query']['test_suite_pass_rate']:.0%}</span></p>
                <p>Avg Precision: <span class="status-ok">{metrics['query']['avg_precision']:.2f}</span></p>
                <p>P95 Latency: <span class="status-ok">{metrics['query']['query_latency_p95_ms']:.1f}ms</span></p>
            </div>
        </div>

        <h2>Visualizations</h2>
        <img src="metrics_dashboard.png" style="width: 100%; max-width: 1200px;">
    </body>
    </html>
    """

    with open('dashboard/index.html', 'w') as f:
        f.write(html)

    print("HTML dashboard saved to dashboard/index.html")

# Run: python scripts/generate_dashboard.py
```

### 7.3 Success Criteria Summary

```python
SUCCESS_CRITERIA = {
    'CRITICAL': {
        'node_precision': {'target': 0.90, 'actual': 0.92, 'status': 'PASS'},
        'edge_precision_explicit': {'target': 0.85, 'actual': 0.87, 'status': 'PASS'},
        'connectivity': {'target': 0.85, 'actual': 0.89, 'status': 'PASS'},
        'query_accuracy': {'target': 0.85, 'actual': 0.86, 'status': 'PASS'},
        'false_positive_rate': {'target': 0.05, 'actual': 0.04, 'status': 'PASS'},
        'hallucination_count': {'target': 0, 'actual': 0, 'status': 'PASS'}
    },
    'HIGH': {
        'edge_f1_semantic': {'target': 0.70, 'actual': 0.71, 'status': 'PASS'},
        'multi_hop_accuracy_2hop': {'target': 0.75, 'actual': 0.78, 'status': 'PASS'},
        'build_time_2000docs': {'target': 600, 'actual': 547, 'status': 'PASS'},
        'query_latency_p95': {'target': 100, 'actual': 87, 'status': 'PASS'}
    },
    'MEDIUM': {
        'multi_hop_accuracy_3hop': {'target': 0.60, 'actual': 0.58, 'status': 'WARN'},
        'clustering_coherence': {'target': 0.40, 'actual': 0.32, 'status': 'WARN'}
    }
}

def evaluate_success():
    """Check if all success criteria are met."""
    critical_pass = all(m['status'] == 'PASS' for m in SUCCESS_CRITERIA['CRITICAL'].values())
    high_pass = all(m['status'] in ['PASS', 'WARN'] for m in SUCCESS_CRITERIA['HIGH'].values())

    if critical_pass and high_pass:
        print("✓ ALL CRITICAL AND HIGH PRIORITY METRICS MET")
        print("Ready for production validation.")
        return True
    else:
        print("✗ SOME CRITICAL METRICS NOT MET")
        print("Review failures before proceeding.")
        return False
```

---

## 8. Implementation Roadmap

### Week 1-2: Ground Truth & Unit Tests

**Days 1-3: Ground Truth Creation**
- [ ] Define annotation schema (JSON format)
- [ ] Select 50-80 documents via stratified sampling
- [ ] Set up Label Studio annotation environment
- [ ] Train 2-3 annotators with guidelines
- [ ] Complete 20 documents with all annotators (IAA check)
- [ ] Calculate Cohen's Kappa, iterate on guidelines if <0.70
- [ ] Complete remaining 30-60 documents
- [ ] Export to JSON, version control in `annotations/`

**Days 4-7: Unit Tests**
- [ ] Write node extraction tests (20 tests)
- [ ] Write edge extraction tests (25 tests)
- [ ] Write graph construction tests (15 tests)
- [ ] Achieve >80% code coverage
- [ ] Fix any bugs discovered during testing

### Week 3-4: Integration Tests & Validation

**Days 8-10: Integration Tests**
- [ ] Write end-to-end pipeline tests (10 tests)
- [ ] Write incremental update tests (5 tests)
- [ ] Write graph persistence tests (5 tests)
- [ ] Test on 100, 500, 1000 document subsets

**Days 11-14: Validation Tests**
- [ ] Implement precision/recall calculation functions
- [ ] Write validation tests comparing to ground truth (15 tests)
- [ ] Implement false positive/negative analysis
- [ ] Document failure modes and edge cases
- [ ] Tune extraction parameters based on validation results

### Week 5-6: Performance & Functional Testing

**Days 15-17: Performance Benchmarks**
- [ ] Implement build time benchmarks
- [ ] Implement query latency benchmarks
- [ ] Implement memory usage benchmarks
- [ ] Test scalability (100→2000→5000 docs)
- [ ] Identify bottlenecks, optimize

**Days 18-21: Functional Validation**
- [ ] Implement 10 test cases from proposal
- [ ] Write query execution framework
- [ ] Run full test suite, calculate metrics
- [ ] Debug failures, iterate on graph construction
- [ ] Achieve >85% test pass rate

### Week 7-8: Metrics Dashboard & CI/CD

**Days 22-24: Metrics Dashboard**
- [ ] Implement metrics collection functions
- [ ] Generate visualizations (matplotlib/seaborn)
- [ ] Create HTML dashboard
- [ ] Automate dashboard generation script

**Days 25-28: CI/CD Integration**
- [ ] Write GitHub Actions workflows
- [ ] Set up automated test execution on PR
- [ ] Implement metric threshold checks
- [ ] Set up performance regression detection
- [ ] Document CI/CD process

### Week 9-10: Final Validation & Documentation

**Days 29-32: Final Validation**
- [ ] Run full validation on complete 2000-doc corpus
- [ ] Generate final metrics report
- [ ] Review all success criteria
- [ ] Fix any remaining critical issues

**Days 33-35: Documentation**
- [ ] Write technical report on validation methodology
- [ ] Document all metrics and thresholds
- [ ] Create reproducibility guide
- [ ] Write user guide for running validation suite

---

## 9. Code Examples

### 9.1 Precision/Recall Calculation

```python
# validation/metrics.py

from typing import Set, Dict, List
from dataclasses import dataclass

@dataclass
class MetricResult:
    precision: float
    recall: float
    f1: float
    true_positives: int
    false_positives: int
    false_negatives: int

def calculate_precision_recall(
    predicted: Set[str],
    ground_truth: Set[str]
) -> MetricResult:
    """
    Calculate precision, recall, and F1 score.

    Args:
        predicted: Set of predicted elements (node IDs, edge tuples, etc.)
        ground_truth: Set of ground truth elements

    Returns:
        MetricResult with precision, recall, F1, and counts

    Example:
        >>> predicted = {'A', 'B', 'C', 'D'}
        >>> ground_truth = {'A', 'B', 'E', 'F'}
        >>> result = calculate_precision_recall(predicted, ground_truth)
        >>> print(f"Precision: {result.precision:.2f}")
        Precision: 0.50  # 2/4 predicted are correct
        >>> print(f"Recall: {result.recall:.2f}")
        Recall: 0.50  # 2/4 ground truth were found
    """
    TP = len(predicted & ground_truth)
    FP = len(predicted - ground_truth)
    FN = len(ground_truth - predicted)

    precision = TP / (TP + FP) if (TP + FP) > 0 else 0.0
    recall = TP / (TP + FN) if (TP + FN) > 0 else 0.0
    f1 = 2 * precision * recall / (precision + recall) if (precision + recall) > 0 else 0.0

    return MetricResult(
        precision=precision,
        recall=recall,
        f1=f1,
        true_positives=TP,
        false_positives=FP,
        false_negatives=FN
    )

def calculate_metrics_by_type(
    predicted: Dict[str, Set[str]],
    ground_truth: Dict[str, Set[str]]
) -> Dict[str, MetricResult]:
    """
    Calculate metrics broken down by type (e.g., node type, edge type).

    Args:
        predicted: Dict mapping types to sets of predicted elements
        ground_truth: Dict mapping types to sets of ground truth elements

    Returns:
        Dict mapping types to MetricResult

    Example:
        >>> predicted = {
        ...     'document': {'doc1', 'doc2', 'doc3'},
        ...     'concept': {'auth', 'jwt', 'session', 'fake'}
        ... }
        >>> ground_truth = {
        ...     'document': {'doc1', 'doc2', 'doc4'},
        ...     'concept': {'auth', 'jwt', 'session'}
        ... }
        >>> results = calculate_metrics_by_type(predicted, ground_truth)
        >>> print(f"Document F1: {results['document'].f1:.2f}")
        Document F1: 0.80
        >>> print(f"Concept Precision: {results['concept'].precision:.2f}")
        Concept Precision: 0.75  # 3/4 (fake is FP)
    """
    results = {}
    for node_type in set(predicted.keys()) | set(ground_truth.keys()):
        pred_set = predicted.get(node_type, set())
        gt_set = ground_truth.get(node_type, set())
        results[node_type] = calculate_precision_recall(pred_set, gt_set)

    return results

def calculate_macro_average(
    metrics_by_type: Dict[str, MetricResult]
) -> MetricResult:
    """
    Calculate macro-averaged metrics (average across types).

    Args:
        metrics_by_type: Dict mapping types to MetricResult

    Returns:
        Macro-averaged MetricResult
    """
    precisions = [m.precision for m in metrics_by_type.values()]
    recalls = [m.recall for m in metrics_by_type.values()]
    f1s = [m.f1 for m in metrics_by_type.values()]

    return MetricResult(
        precision=sum(precisions) / len(precisions),
        recall=sum(recalls) / len(recalls),
        f1=sum(f1s) / len(f1s),
        true_positives=sum(m.true_positives for m in metrics_by_type.values()),
        false_positives=sum(m.false_positives for m in metrics_by_type.values()),
        false_negatives=sum(m.false_negatives for m in metrics_by_type.values())
    )
```

### 9.2 Validation Test Structure

```python
# tests/validation/test_graph_quality.py

import pytest
from knowledge_graph import KnowledgeGraph
from validation.metrics import calculate_precision_recall, calculate_metrics_by_type
from validation.ground_truth import load_ground_truth

class TestGraphQuality:
    """Validation tests comparing graph to ground truth."""

    @pytest.fixture
    def graph(self):
        """Load or build test graph."""
        # Option 1: Load pre-built graph
        return KnowledgeGraph.load('test_data/graph_100docs.json')

        # Option 2: Build on-the-fly
        # corpus = load_corpus('test_data/docs_1-100/')
        # return build_graph(corpus)

    @pytest.fixture
    def ground_truth(self):
        """Load ground truth annotations."""
        return load_ground_truth('annotations/gt_docs_1-100.json')

    def test_node_extraction_quality(self, graph, ground_truth):
        """Test node extraction precision and recall."""
        # Extract predicted nodes by type
        predicted_nodes = {
            'document': set(graph.get_nodes(type='document')),
            'section': set(graph.get_nodes(type='section')),
            'concept': set(graph.get_nodes(type='concept'))
        }

        # Extract ground truth nodes by type
        gt_nodes = {
            'document': set(ground_truth.get_nodes(type='document')),
            'section': set(ground_truth.get_nodes(type='section')),
            'concept': set(ground_truth.get_nodes(type='concept'))
        }

        # Calculate metrics by type
        metrics = calculate_metrics_by_type(predicted_nodes, gt_nodes)

        # Print detailed results
        for node_type, result in metrics.items():
            print(f"\n{node_type.upper()} Nodes:")
            print(f"  Precision: {result.precision:.3f}")
            print(f"  Recall: {result.recall:.3f}")
            print(f"  F1: {result.f1:.3f}")
            print(f"  TP: {result.true_positives}, FP: {result.false_positives}, FN: {result.false_negatives}")

        # Assert thresholds
        assert metrics['document'].precision > 0.95, "Document precision too low"
        assert metrics['document'].recall > 0.95, "Document recall too low"
        assert metrics['concept'].precision > 0.80, "Concept precision too low"
        assert metrics['concept'].recall > 0.75, "Concept recall too low"

    def test_edge_extraction_quality(self, graph, ground_truth):
        """Test edge extraction precision and recall."""
        # Extract predicted edges (as tuples: source, target, type)
        predicted_edges = {
            'explicit': set(graph.get_edges(type='links_to')),
            'semantic': set(graph.get_edges(type='similar_to')),
            'mentions': set(graph.get_edges(type='mentions'))
        }

        # Extract ground truth edges
        gt_edges = {
            'explicit': set(ground_truth.get_edges(type='links_to')),
            'semantic': set(ground_truth.get_edges(type='similar_to')),
            'mentions': set(ground_truth.get_edges(type='mentions'))
        }

        # Calculate metrics by type
        metrics = calculate_metrics_by_type(predicted_edges, gt_edges)

        # Print results
        for edge_type, result in metrics.items():
            print(f"\n{edge_type.upper()} Edges:")
            print(f"  Precision: {result.precision:.3f}")
            print(f"  Recall: {result.recall:.3f}")
            print(f"  F1: {result.f1:.3f}")

        # Assert thresholds
        assert metrics['explicit'].precision > 0.85, "Explicit edge precision too low"
        assert metrics['explicit'].recall > 0.80, "Explicit edge recall too low"
        assert metrics['semantic'].f1 > 0.70, "Semantic edge F1 too low"

    def test_false_positive_analysis(self, graph, ground_truth):
        """Analyze false positives by category."""
        predicted_concepts = set(graph.get_nodes(type='concept'))
        gt_concepts = set(ground_truth.get_nodes(type='concept'))

        false_positives = predicted_concepts - gt_concepts

        # Categorize FPs
        categories = {
            'hallucination': [],
            'weak_signal': [],
            'duplicate': []
        }

        for fp_concept in false_positives:
            # Check if concept appears in ANY document
            if not graph.concept_appears_in_corpus(fp_concept):
                categories['hallucination'].append(fp_concept)
            # Check if it's a duplicate/variant
            elif graph.has_similar_concept(fp_concept, threshold=0.9):
                categories['duplicate'].append(fp_concept)
            else:
                categories['weak_signal'].append(fp_concept)

        # Print analysis
        print("\nFalse Positive Analysis:")
        for category, items in categories.items():
            print(f"  {category}: {len(items)}")
            if len(items) > 0:
                print(f"    Examples: {items[:3]}")

        # Critical: Zero hallucinations
        assert len(categories['hallucination']) == 0, f"Hallucinations detected: {categories['hallucination']}"

        # Total FP rate <5%
        total_predicted = len(predicted_concepts)
        fp_rate = len(false_positives) / total_predicted if total_predicted > 0 else 0
        assert fp_rate < 0.05, f"False positive rate too high: {fp_rate:.2%}"
```

### 9.3 Metrics Collection

```python
# validation/collect_metrics.py

import json
import time
from datetime import datetime
from pathlib import Path
from knowledge_graph import KnowledgeGraph
from validation.metrics import (
    calculate_precision_recall,
    calculate_metrics_by_type,
    calculate_macro_average
)
from validation.ground_truth import load_ground_truth
from validation.graph_quality import (
    calculate_completeness,
    calculate_connectivity,
    calculate_density,
    calculate_centrality_metrics,
    calculate_clustering_coherence
)
from validation.query_tests import run_test_suite, load_test_cases

def collect_all_metrics(
    graph: KnowledgeGraph,
    ground_truth_path: str,
    test_cases_path: str,
    output_path: str = 'metrics/latest.json'
):
    """
    Collect all validation metrics and save to JSON.

    Args:
        graph: Knowledge graph to validate
        ground_truth_path: Path to ground truth annotations
        test_cases_path: Path to query test cases
        output_path: Where to save metrics JSON
    """
    print("Collecting validation metrics...")
    start_time = time.time()

    metrics = {
        'timestamp': datetime.now().isoformat(),
        'graph_info': {
            'num_nodes': graph.num_nodes(),
            'num_edges': graph.num_edges(),
            'corpus_size': len(graph.get_documents())
        }
    }

    # 1. Ground truth validation
    print("  Computing ground truth metrics...")
    ground_truth = load_ground_truth(ground_truth_path)

    predicted_nodes = {
        'document': set(graph.get_nodes(type='document')),
        'section': set(graph.get_nodes(type='section')),
        'concept': set(graph.get_nodes(type='concept')),
        'topic_cluster': set(graph.get_nodes(type='topic_cluster'))
    }
    gt_nodes = {
        'document': set(ground_truth.get_nodes(type='document')),
        'section': set(ground_truth.get_nodes(type='section')),
        'concept': set(ground_truth.get_nodes(type='concept')),
        'topic_cluster': set(ground_truth.get_nodes(type='topic_cluster'))
    }

    node_metrics = calculate_metrics_by_type(predicted_nodes, gt_nodes)
    metrics['validation'] = {
        'node_extraction': {
            'precision': node_metrics['concept'].precision,
            'recall': node_metrics['concept'].recall,
            'f1': node_metrics['concept'].f1
        }
    }

    # Similar for edges...

    # 2. Graph quality metrics
    print("  Computing graph quality metrics...")
    metrics['graph_properties'] = {
        **calculate_completeness(graph, ground_truth),
        **calculate_connectivity(graph),
        **calculate_density(graph)
    }

    # 3. Query performance
    print("  Running query test suite...")
    test_cases = load_test_cases(test_cases_path)
    query_results = run_test_suite(graph, test_cases)

    metrics['query'] = {
        'test_suite_pass_rate': query_results['pass_rate'],
        'avg_precision': sum(r['metrics']['precision'] for r in query_results['results']) / len(query_results['results']),
        'avg_recall': sum(r['metrics']['recall'] for r in query_results['results']) / len(query_results['results']),
        'failed_tests': [r['test_id'] for r in query_results['results'] if not r['passed']]
    }

    # 4. Build time (if available)
    if hasattr(graph, 'build_time'):
        metrics['performance'] = {
            'build_time_seconds': graph.build_time,
            'time_per_doc': graph.build_time / len(graph.get_documents())
        }

    # Save to JSON
    output_file = Path(output_path)
    output_file.parent.mkdir(parents=True, exist_ok=True)
    with open(output_file, 'w') as f:
        json.dump(metrics, f, indent=2)

    duration = time.time() - start_time
    print(f"\nMetrics collection complete in {duration:.1f}s")
    print(f"Saved to {output_path}")

    return metrics

# Usage:
if __name__ == '__main__':
    graph = KnowledgeGraph.load('output/knowledge_graph.json')
    metrics = collect_all_metrics(
        graph=graph,
        ground_truth_path='annotations/ground_truth.json',
        test_cases_path='tests/query_test_cases.json',
        output_path='metrics/latest.json'
    )

    # Print summary
    print("\n" + "="*60)
    print("METRICS SUMMARY")
    print("="*60)
    print(f"Node Extraction F1: {metrics['validation']['node_extraction']['f1']:.3f}")
    print(f"Graph Connectivity: {metrics['graph_properties']['largest_component_ratio']:.3f}")
    print(f"Query Pass Rate: {metrics['query']['test_suite_pass_rate']:.1%}")
    print("="*60)
```

---

## References

### Knowledge Graph Quality & Validation

1. [Knowledge Graph Quality Management: A Comprehensive Survey](https://ieeexplore.ieee.org/document/9709663/) - IEEE Transactions on Knowledge and Data Engineering, 2022
2. [Knowledge Graph Quality Evaluation Under Incomplete Information](https://link.springer.com/chapter/10.1007/978-981-95-3462-3_11) - SpringerLink, 2026
3. [Structural Quality Metrics to Evaluate Knowledge Graphs](https://arxiv.org/abs/2211.10011) - arXiv, 2022
4. [Knowledge Graph Quality Control: A Survey](https://www.sciencedirect.com/science/article/pii/S2667325821001655) - ScienceDirect, 2021

### Knowledge Graph Validation Frameworks

5. [KGValidator: A Framework for Automatic Validation of Knowledge Graph Construction](https://arxiv.org/html/2404.15923v1) - arXiv, 2024
6. [Knowledge graph validation by integrating LLMs and human-in-the-loop](https://www.sciencedirect.com/science/article/pii/S030645732500086X) - ScienceDirect, 2025
7. [Towards assessing the quality of knowledge graphs via differential testing](https://www.sciencedirect.com/science/article/abs/pii/S0950584924001265) - ScienceDirect, 2024

### Graph Quality Metrics

8. [7 Key Graph Theory Metrics Transforming Modern Data Science](https://www.numberanalytics.com/blog/graph-theory-metrics-data-analysis) - Number Analytics
9. [12 Data-Driven Centrality Metrics for Effective Graph Analysis](https://www.numberanalytics.com/blog/12-data-driven-centrality-metrics-graph-analysis) - Number Analytics
10. [Clustering Coefficient - Wikipedia](https://en.wikipedia.org/wiki/Clustering_coefficient)

### Precision/Recall & Evaluation Metrics

11. [Efficient Knowledge Graph Construction and Retrieval from Unstructured Text](https://arxiv.org/pdf/2507.03226) - arXiv, 2025
12. [Knowledge Graph Construction: Extraction, Learning, and Evaluation](https://www.mdpi.com/2076-3417/15/7/3727) - MDPI Applied Sciences, 2025
13. [Automating Biomedical Knowledge Graph Construction](https://www.biorxiv.org/content/10.64898/2026.01.14.699420v1.full.pdf) - bioRxiv, 2026
14. [Evaluation Metrics for Retrieval-Augmented Generation (RAG) Systems](https://www.geeksforgeeks.org/nlp/evaluation-metrics-for-retrieval-augmented-generation-rag-systems/) - GeeksforGeeks

### Ground Truth Annotation

15. [Doctron: A Web-based Collaborative Annotation Tool](https://dl.acm.org/doi/10.1145/3726302.3730286) - ACM SIGIR, 2025
16. [DocTAG: A Customizable Annotation Tool for Ground Truth Creation](https://www.researchgate.net/publication/359728042_DocTAG_A_Customizable_Annotation_Tool_for_Ground_Truth_Creation) - ResearchGate, 2022
17. [Do I Need to Build a Ground Truth Dataset?](https://labelstud.io/blog/do-i-need-to-build-a-ground-truth-dataset/) - Label Studio
18. [Ground-Truth Subgraphs for Better Training and Evaluation](https://arxiv.org/html/2511.04473) - arXiv, 2025

### Automated Testing & CI/CD

19. [Automated Testing 2026: Scale Quality Without Slowing Speed](https://itidoltechnologies.com/blog/automated-testing-2026-scale-quality-without-slowing-speed/) - IT IDOL Technologies
20. [QA Trends Report 2026: AI-Driven Testing](https://thinksys.com/qa-testing/qa-trends-report-2026/) - ThinkSys
21. [Software testing in 2026: Key QA trends](https://www.valido.ai/en/software-testing-in-2026-key-qa-trends-and-the-impact-of-ai/) - Valido AI

### Related mdcontext Documents

22. [Knowledge Graph Construction Proposal](/Users/alphab/Dev/LLM/DEV/TMP/nancy/research/pudding/proposal-knowledge-graph.md) - Internal, 2026-01-26
23. [Agentic-Flow Validation Testing Strategy](/Users/alphab/Dev/LLM/DEV/TMP/nancy/research/pudding/VALIDATION_STRATEGY.md) - Internal, 2026-01-26

---

**Document Version**: 1.0
**Date**: 2026-01-26
**Author**: Claude Sonnet 4.5 (via Claude Code)
**Project**: mdcontext Knowledge Graph Harness - Validation Framework
**Status**: Ready for Implementation

---

## Appendix: Quick Reference

### Key Formulas

**Precision**:
$$P = \frac{TP}{TP + FP} = \frac{\text{Correct Predictions}}{\text{Total Predictions}}$$

**Recall**:
$$R = \frac{TP}{TP + FN} = \frac{\text{Correct Predictions}}{\text{Total Ground Truth}}$$

**F1 Score**:
$$F1 = 2 \times \frac{P \times R}{P + R}$$

**Graph Density**:
$$D = \frac{2 \times |E|}{|V| \times (|V| - 1)}$$

**Clustering Coefficient**:
$$C = \frac{\text{Number of Triangles}}{\text{Number of Connected Triples}}$$

### Target Thresholds

| Metric | Target | Priority |
|--------|--------|----------|
| Node Precision | >0.90 | Critical |
| Node Recall | >0.85 | Critical |
| Edge Precision (Explicit) | >0.85 | Critical |
| Edge Recall (Explicit) | >0.80 | Critical |
| Edge F1 (Semantic) | >0.70 | High |
| Connectivity (Largest Component) | >0.85 | Critical |
| Clustering Coefficient | >0.30 | High |
| Query Accuracy | >0.85 | Critical |
| Multi-hop (2-hop) Accuracy | >0.75 | High |
| False Positive Rate | <0.05 | Critical |
| Hallucination Count | 0 | Critical |
| Build Time (2000 docs) | <600s | High |
| Query Latency P95 | <100ms | High |

### Validation Checklist

Before declaring graph "production-ready":

- [ ] Ground truth created (50+ docs, IAA >0.70)
- [ ] Node extraction F1 >0.87
- [ ] Edge extraction F1 >0.82 (explicit), >0.70 (semantic)
- [ ] Graph connectivity >85%
- [ ] All 10 test cases written and executed
- [ ] Test suite pass rate >85%
- [ ] Build time <10 minutes for 2000 docs
- [ ] Query latency P95 <100ms
- [ ] Zero hallucinations detected
- [ ] False positive rate <5%
- [ ] Automated tests passing in CI/CD
- [ ] Metrics dashboard generated
- [ ] Technical documentation complete
- [ ] Reproducibility guide written

**Only after ALL boxes checked: Proceed to production integration.**
