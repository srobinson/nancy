# Semantic Search Intelligence Test: mdcontext Evaluation Proposal

**Author:** Claude Sonnet 4.5
**Date:** 2026-01-26
**Version:** 1.0
**Status:** Proposal

---

## Executive Summary

This document proposes a comprehensive evaluation framework to prove mdcontext's semantic search capabilities demonstrably exceed traditional keyword-based search systems. Drawing from established benchmarks (MS MARCO, BEIR) and industry practices (Algolia, Elasticsearch, Pinecone), we design a test suite that measures **intelligent understanding** of documentation content, not just lexical matching.

**Core Thesis:** mdcontext should handle queries requiring conceptual reasoning, synonym understanding, disambiguation, and multi-hop inference—queries where naive keyword search catastrophically fails.

---

## 1. Vision: What is "Intelligent Search" for Documentation?

### 1.1 The Documentation Search Problem

Documentation differs from general web search in critical ways:

- **Technical vocabulary** with domain-specific jargon
- **Concept synonymy** (authentication = auth = login = credentials)
- **Implicit relationships** (configuration implies setup, deployment, environment)
- **Hierarchical knowledge** (understanding parent-child topic relationships)
- **Code-text duality** (matching natural language queries to code examples)

### 1.2 Intelligence Markers

A truly intelligent documentation search system demonstrates:

1. **Semantic Understanding**: Interprets query intent, not just keyword presence
2. **Contextual Reasoning**: Uses surrounding context to disambiguate terms
3. **Synonym Recognition**: Matches equivalent concepts expressed differently
4. **Multi-Hop Inference**: Connects related concepts across document boundaries
5. **Conceptual Ranking**: Prioritizes relevance by meaning, not term frequency

### 1.3 Success Criteria

mdcontext succeeds if it:

- Returns relevant results for **zero-keyword-overlap queries**
- Correctly **disambiguates** polysemous terms based on context
- **Bridges concept gaps** (query mentions "credentials", finds "API key setup")
- **Outperforms BM25** baseline by 35%+ on relevance metrics
- Matches or exceeds **GitHub Copilot semantic search** quality

---

## 2. Evaluation Framework

### 2.1 Benchmark Architecture

Drawing from BEIR methodology, we propose a heterogeneous benchmark comprising:

**Test Corpus**: mdcontext's own documentation (~12 files, 2,500 tokens)

**Query Categories** (detailed in Section 3):
1. Conceptual queries (semantic understanding)
2. Synonym/paraphrase queries (lexical variation)
3. Disambiguation queries (polysemy handling)
4. Multi-hop reasoning queries (inference)
5. Code-seeking queries (code-text bridging)
6. Negative queries (precision testing)

**Ground Truth**: Human-annotated relevance judgments (binary + graded scale)

### 2.2 Evaluation Metrics

Following BEIR and industry standards:

#### Primary Metrics

**nDCG@10 (Normalized Discounted Cumulative Gain)**
- Industry standard for ranking evaluation
- Accounts for graded relevance (not just binary)
- Penalizes relevant documents appearing low in results
- Score range: 0-1 (1 = perfect ranking)

**MAP@10 (Mean Average Precision)**
- Measures precision across different recall levels
- Sensitive to result order
- Ideal for documentation where top results matter most

**MRR (Mean Reciprocal Rank)**
- Focuses on first relevant result position
- Critical for "quick answer" documentation queries
- Formula: MRR = 1/rank_of_first_relevant_result

#### Secondary Metrics

**Recall@k** (k=1,3,5,10)
- Percentage of relevant documents found in top-k
- Measures completeness of results

**Precision@k**
- Percentage of top-k results that are relevant
- Measures result quality

**F1 Score**
- Harmonic mean of precision and recall
- Balances completeness vs. quality

### 2.3 Comparison Baselines

**Lexical Baselines:**
- **BM25**: Gold standard for keyword search
- **TF-IDF**: Classic information retrieval
- **Regex/Exact Match**: Worst-case baseline

**Semantic Competitors:**
- **GitHub Copilot Semantic Search**: Industry benchmark (as of 2025)
- **Algolia DocSearch v4 + AskAI**: Commercial semantic doc search
- **Elasticsearch Semantic Query (ELSER)**: Enterprise semantic search

**Target Performance:**
- Beat BM25 by 35%+ on nDCG@10
- Match GitHub Copilot quality (MRR > 0.75)
- Exceed Algolia for technical documentation (nDCG@10 > 0.80)

---

## 3. Test Categories & Challenge Queries

### 3.1 Category 1: Conceptual Queries (Semantic Understanding)

**Definition:** Queries that describe concepts without using exact documentation terminology.

**Why Hard:** Zero or minimal keyword overlap. Requires understanding query *intent* and matching to conceptual *meaning*.

#### Example Queries:

| Query | Keyword Search Failure | Expected Match | Reasoning |
|-------|------------------------|----------------|-----------|
| "How do I make my search smarter?" | No "smarter" in docs | Semantic search setup, embeddings configuration | Interprets "smarter" as semantic/AI-powered capability |
| "Speed up document processing" | "Speed" rarely appears | Indexing with `--watch`, performance tips | Maps "speed up" to performance/optimization sections |
| "Find stuff by meaning instead of words" | No exact phrase | Semantic search documentation | Understands definition of semantic search |
| "Save my preferences across runs" | "preferences" != "configuration" | Configuration guide, config file formats | Maps "preferences" → "configuration" |
| "Stop indexing unnecessary files" | "unnecessary" is subjective | Exclude patterns, `.gitignore`, `excludePatterns` config | Interprets "unnecessary" as "excluded" |
| "What providers can I use offline?" | "offline" implies local | Ollama, LM Studio sections in CONFIG.md | Infers "offline" → "local" → Ollama/LM Studio |
| "Get AI explanations of my results" | "explanations" != "summarization" | AI Summarization section | Maps "explanations" to summarization feature |
| "Understand my codebase structure" | No "understand" or "codebase" | `tree` command, document outline | Interprets developer intent for navigation |

**Success Metric:** nDCG@10 > 0.75, MRR > 0.80 (semantic should excel here)

---

### 3.2 Category 2: Synonym & Paraphrase Handling

**Definition:** Same concept expressed with different vocabulary.

**Why Hard:** Documentation uses specific terms; users may use everyday language or technical synonyms.

#### Example Queries:

| Query Variant A | Query Variant B | Query Variant C | Expected Match |
|-----------------|-----------------|-----------------|----------------|
| "authentication setup" | "login configuration" | "credential handling" | API key/provider configuration |
| "deployment instructions" | "going live guide" | "production setup" | Deployment sections (if exists) |
| "error messages" | "failures" | "problems" | Error handling, ERRORS.md |
| "search results" | "query output" | "findings" | Search command documentation |
| "file organization" | "directory layout" | "folder hierarchy" | Tree command, index structure |
| "speed improvements" | "performance tuning" | "optimization tips" | Performance section |
| "installation" | "setup" | "getting started" | Installation/Quick Start sections |
| "cost calculation" | "pricing estimate" | "expense tracking" | AI summarization cost transparency |

**Success Metric:** All variants return identical top-3 results. Synonym recognition rate > 90%.

---

### 3.3 Category 3: Disambiguation Queries (Context-Aware Understanding)

**Definition:** Polysemous terms that require context to interpret correctly.

**Why Hard:** Same word, multiple meanings. System must use query context to select correct interpretation.

#### Example Queries:

| Ambiguous Query | Context Clue | Correct Interpretation | Wrong Interpretation |
|-----------------|--------------|------------------------|---------------------|
| "index my project" | Subject: indexing | The `index` command | Index as data structure |
| "search quality modes" | Subject: accuracy | Fast vs thorough quality settings | Mode as programming concept |
| "link analysis" | Subject: docs | `links`/`backlinks` commands | URL hyperlinks only |
| "vector search" | Subject: semantic | Embeddings-based search | Mathematical vectors |
| "context window limits" | Subject: LLMs | Token budget, summarization | Context menu or UI context |
| "provider configuration" | Subject: embeddings | OpenAI/Ollama/Voyage setup | Generic dependency injection |
| "tree output" | Subject: navigation | File/document tree visualization | Binary tree data structure |
| "stats for my docs" | Subject: analysis | `stats` command output | Statistical analysis methods |

**Success Metric:** Disambiguation accuracy > 85%. No conflation of distinct concepts.

---

### 3.4 Category 4: Multi-Hop Reasoning (Cross-Document Inference)

**Definition:** Queries requiring synthesis of information from multiple sections or documents.

**Why Hard:** Answer not in single location. Requires understanding relationships between concepts.

#### Example Queries:

| Query | Hop 1 | Hop 2 | Hop 3 | Expected Result |
|-------|-------|-------|-------|-----------------|
| "How to use semantic search without spending money?" | Free providers | Ollama/LM Studio | Setup instructions | Combined: CONFIG.md sections on Ollama + cost comparison |
| "What's needed to enable the smartest search?" | Semantic search | Embeddings required | Provider setup | Index with `--embed` + provider configuration |
| "Find documents about configuration options for search results" | Search config | Configuration guide | Specific options | CONFIG.md → search.defaultLimit, minSimilarity |
| "How to reduce token usage when querying" | Token budget | Context command | `--brief` flag | Context command with token limits |
| "Set up offline semantic search from scratch" | Semantic requires embeddings | Offline = local | Local providers | Install Ollama → pull model → index with `--embed --provider ollama` |
| "Compare costs of different AI summarization methods" | AI summarization | CLI vs API | Provider pricing | Summarization.md → provider table + cost estimates |
| "What's the relationship between sections and embeddings?" | Sections are indexed | Embeddings represent sections | Vector mapping | DESIGN.md data model + embeddings config |

**Success Metric:** Multi-hop queries should retrieve 2+ relevant sections spanning documents. Recall@10 > 0.70.

---

### 3.5 Category 5: Code-Seeking Queries (Natural Language → Code Examples)

**Definition:** User describes what they want to *do*, expects code examples showing *how*.

**Why Hard:** Bridging natural language intent to technical implementation syntax.

#### Example Queries:

| Natural Language Query | Expected Code Example | Location |
|------------------------|------------------------|----------|
| "Show me how to index with embeddings" | `mdcontext index --embed` | README.md commands section |
| "Example of semantic search" | `mdcontext search "authentication"` | README search examples |
| "Configure custom exclude patterns" | Config file with `excludePatterns` array | CONFIG.md examples |
| "Set up Ollama for embeddings" | `ollama serve && mdcontext index --embed --provider ollama` | README Ollama section |
| "Get AI summary of results" | `mdcontext search "query" --summarize` | README AI Summarization |
| "Check config file syntax" | JavaScript config with JSDoc type annotation | CONFIG.md format examples |
| "Filter search results by token budget" | `mdcontext context -t 500 README.md` | README context command |

**Success Metric:** Code examples appear in top-5 results. Code block retrieval precision > 0.80.

---

### 3.6 Category 6: Negative Queries (Precision Testing)

**Definition:** Queries that *should not* return results, or should explicitly indicate no match.

**Why Hard:** Avoiding false positives. System must recognize out-of-scope queries.

#### Example Queries:

| Query | Why It Should Fail/Return Empty | Expected Behavior |
|-------|--------------------------------|-------------------|
| "How to configure Elasticsearch with mdcontext?" | mdcontext doesn't integrate with Elasticsearch | No results or clear "not found" |
| "Delete my index permanently" | No destructive deletion command exists | No strong matches |
| "mdcontext machine learning model training" | mdcontext uses pre-trained models, doesn't train | Clarification or empty result |
| "Deploy mdcontext to AWS Lambda" | Not a deployment tool | Empty or weak matches |
| "Python API for mdcontext" | CLI tool, no Python API | No results or GitHub link only |
| "Translate documentation to Spanish" | No translation feature | Empty result |
| "Real-time collaborative editing" | Not a feature | No matches |

**Success Metric:** Precision@5 = 0.0 (no false positives). Optional: return "no relevant results" message.

---

## 4. Ground Truth & Annotation

### 4.1 Relevance Grading Scale

Following MS MARCO and BEIR standards:

| Grade | Label | Definition | Example |
|-------|-------|------------|---------|
| 3 | Perfectly Relevant | Directly answers query, complete information | Query: "setup semantic search" → Match: Embeddings setup section |
| 2 | Highly Relevant | Answers query, may lack some details | Query: "search options" → Match: Search command flags list |
| 1 | Marginally Relevant | Related topic, incomplete answer | Query: "performance tips" → Match: General index documentation |
| 0 | Not Relevant | Off-topic or no useful information | Query: "semantic search" → Match: Unrelated config option |

### 4.2 Annotation Process

1. **Query Generation**: Author 30-40 queries across all categories
2. **Candidate Retrieval**: Run queries through mdcontext + baselines (BM25, Elasticsearch)
3. **Pooling**: Combine top-10 results from all systems
4. **Human Annotation**: 2-3 annotators grade each query-document pair
5. **Inter-Annotator Agreement**: Calculate Cohen's Kappa (target: κ > 0.70)
6. **Gold Standard**: Resolve disagreements, finalize relevance judgments

### 4.3 Test Set Composition

| Category | Query Count | Difficulty | Priority |
|----------|-------------|------------|----------|
| Conceptual | 8 | High | Critical |
| Synonym/Paraphrase | 6 | Medium | High |
| Disambiguation | 6 | High | High |
| Multi-Hop | 5 | Very High | Medium |
| Code-Seeking | 7 | Medium | High |
| Negative | 5 | Medium | Low |
| **TOTAL** | **37** | Mixed | - |

---

## 5. Implementation Plan

### 5.1 Phase 1: Infrastructure (Week 1)

**Deliverables:**
- Test harness script (`semantic-eval.js`)
- Query format: JSONL file with queries + expected relevance
- Baseline implementations (BM25, TF-IDF)
- Metrics calculation library (nDCG, MAP, MRR)

**Example Query Format:**
```json
{
  "id": "Q001",
  "query": "How do I make my search smarter?",
  "category": "conceptual",
  "relevance_judgments": {
    "docs/CONFIG.md#semantic-search-setup": 3,
    "README.md#setting-up-semantic-search": 3,
    "docs/summarization.md": 1,
    "docs/DESIGN.md": 0
  }
}
```

### 5.2 Phase 2: Baseline Evaluation (Week 2)

**Goals:**
1. Establish BM25 baseline performance
2. Identify "failure cases" where keyword search returns 0 results
3. Measure keyword overlap vs. relevance correlation

**Output:**
- Baseline metrics report (BM25, TF-IDF, Exact Match)
- Failure case analysis (queries with nDCG@10 < 0.30)

### 5.3 Phase 3: mdcontext Evaluation (Week 3)

**Tests:**
1. Run all 37 queries through mdcontext semantic search
2. Vary similarity thresholds (0.25, 0.35, 0.50)
3. Test quality modes (`fast`, `thorough`)
4. Enable/disable re-ranking and HyDE

**Metrics:**
- nDCG@10, MAP@10, MRR per category
- Recall@k curves (k=1,3,5,10)
- Precision-Recall curves
- Query latency distribution

### 5.4 Phase 4: Competitive Analysis (Week 4)

**Comparisons:**

1. **GitHub Copilot Semantic Search**
   - Test queries in VS Code with Copilot indexed repo
   - Manually score top-5 results
   - Compare relevance and result diversity

2. **Algolia DocSearch v4**
   - Deploy test docs to Algolia
   - Run queries through Algolia search API
   - Measure nDCG@10 and latency

3. **Elasticsearch Semantic Query (ELSER)**
   - Index docs in Elasticsearch with ELSER model
   - Run semantic queries
   - Compare relevance metrics

**Output:**
- Competitive benchmark table
- Feature comparison (latency, setup complexity, cost)
- Qualitative analysis (when each system excels/fails)

---

## 6. Competitive Analysis

### 6.1 GitHub Copilot Semantic Search (2025)

**Strengths:**
- Instant indexing (<60 seconds)
- Code-specific understanding
- Integrated with IDE workflow
- Handles large codebases (millions of lines)

**Weaknesses:**
- Optimized for code, not pure documentation
- No offline mode
- Requires GitHub Copilot subscription
- Limited customization

**mdcontext Advantages:**
- Purpose-built for markdown documentation
- Offline-capable (Ollama, LM Studio)
- Configurable quality/speed tradeoffs
- Section-level granularity

**Test Strategy:**
- Focus on documentation-heavy queries
- Measure precision for conceptual queries
- Compare "first relevant result" rank

### 6.2 Algolia DocSearch v4 + AskAI

**Strengths:**
- Conversational AI (AskAI follow-up questions)
- Cloud-hosted, no maintenance
- Excellent typo tolerance
- Sub-100ms query latency

**Weaknesses:**
- Requires cloud deployment
- Generic for all documentation (not mdcontext-aware)
- Commercial pricing for high-traffic sites
- Less control over ranking logic

**mdcontext Advantages:**
- Self-hosted, privacy-preserving
- Zero-cost for local use
- Specialized for technical documentation
- Context-aware summarization

**Test Strategy:**
- Measure nDCG@10 for technical queries
- Compare latency under local vs. cloud constraints
- Test offline scenario (where Algolia fails)

### 6.3 Elasticsearch Semantic Query (ELSER)

**Strengths:**
- Enterprise-grade scalability
- Hybrid search (combines lexical + semantic)
- Advanced query DSL
- Multi-language support

**Weaknesses:**
- Complex setup (JVM, cluster management)
- Resource-intensive (RAM, CPU)
- Steep learning curve
- Overkill for small documentation projects

**mdcontext Advantages:**
- Zero-dependency installation (npm install)
- Designed for documentation at any scale
- Simple CLI interface
- Optimized for developer workflows

**Test Strategy:**
- Compare setup time (mdcontext: 1 min vs. ES: 1 hour+)
- Measure quality on small doc corpus (ES advantage diminishes)
- Test resource usage (memory, disk)

---

## 7. Success Criteria & Acceptance

### 7.1 Quantitative Thresholds

mdcontext **passes** semantic intelligence test if:

| Metric | Threshold | Rationale |
|--------|-----------|-----------|
| **nDCG@10** (overall) | ≥ 0.75 | Industry "good" performance (BEIR benchmarks) |
| **nDCG@10** (conceptual) | ≥ 0.80 | Semantic search should excel on zero-overlap queries |
| **MAP@10** | ≥ 0.70 | Precision across all recall levels |
| **MRR** | ≥ 0.75 | First result is usually relevant |
| **Recall@10** | ≥ 0.85 | Captures most relevant documents |
| **vs. BM25 Improvement** | +35% nDCG@10 | Justifies semantic overhead |
| **Synonym Recognition** | ≥ 90% top-3 agreement | Variant queries return same results |
| **Disambiguation Accuracy** | ≥ 85% | Context resolves polysemous terms |
| **Negative Query Precision@5** | 0.0 | No false positives on out-of-scope queries |

### 7.2 Qualitative Assessment

**"Wow Factor" Test:**
1. Show mdcontext results to 5 developers
2. Compare side-by-side with BM25/grep results
3. Ask: "Which search understands what I meant?"
4. Target: mdcontext preferred in 80%+ of cases

**Failure Analysis:**
- Document queries where mdcontext performs poorly
- Identify patterns (specific doc structures, query types)
- Propose improvements (query expansion, re-ranking tweaks)

### 7.3 Acceptance Criteria

Test is **successful** if:

1. All quantitative thresholds met ✅
2. mdcontext beats BM25 on 90%+ of conceptual queries ✅
3. Zero critical failures (nDCG@10 = 0 on easy queries) ✅
4. Competitive with GitHub Copilot on doc-specific queries ✅
5. Developer "wow factor" preference > 75% ✅

---

## 8. Expected Outcomes & Insights

### 8.1 Predicted Results

**Strong Performance Expected:**
- **Conceptual queries**: nDCG@10 ~ 0.85 (semantic strength)
- **Synonym queries**: 95%+ top-3 consistency
- **Code-seeking queries**: High recall (embeddings capture code semantics)

**Challenges Expected:**
- **Multi-hop reasoning**: Medium performance (nDCG@10 ~ 0.65)
  - Single-vector retrieval may miss complex inference chains
  - Potential solution: Graph-based retrieval (HopRAG approach)

- **Disambiguation**: 80-85% accuracy
  - Requires strong contextual embeddings
  - May need query expansion or context injection

### 8.2 Research Questions Answered

1. **Does semantic search justify the complexity?**
   - If improvement > 35% over BM25 → Yes
   - If improvement < 20% → Reconsider default behavior

2. **Which embedding model performs best?**
   - Compare: OpenAI text-embedding-3-small, Voyage, Nomic, ELSER
   - Measure: nDCG@10, latency, model size

3. **What's the optimal similarity threshold?**
   - Test: 0.25, 0.30, 0.35, 0.40, 0.50
   - Measure: Precision-Recall tradeoff per threshold

4. **Does re-ranking provide value?**
   - A/B test: semantic search with/without re-ranking
   - Measure: nDCG@10 improvement, latency increase

5. **Where does keyword search still win?**
   - Exact identifier search (function names, API endpoints)
   - Rare technical terms (product names, version numbers)

### 8.3 Actionable Improvements

Based on test results, propose:

1. **Hybrid Search Strategy**
   - Combine lexical + semantic ranking
   - Boost exact matches, use semantic for exploration

2. **Query Classification**
   - Detect query type (conceptual vs. exact)
   - Route to optimal search strategy

3. **Dynamic Thresholds**
   - Adjust similarity threshold based on query characteristics
   - Lower threshold for exploratory queries, higher for precise searches

4. **Contextual Re-ranking**
   - Use query-time context (user history, recent docs) to boost relevance
   - Implement lightweight learned-to-rank model

---

## 9. Conclusion

This proposal establishes a rigorous, benchmark-driven evaluation framework to prove mdcontext's semantic search intelligence. By testing across diverse query categories, measuring against industry-standard metrics (nDCG, MAP, MRR), and comparing to commercial systems (GitHub Copilot, Algolia, Elasticsearch), we create a definitive assessment of documentation search quality.

**Key Differentiators:**

- **Conceptual query handling**: Interprets user intent, not just keywords
- **Synonym robustness**: Recognizes equivalent concepts
- **Context-aware disambiguation**: Resolves polysemous terms correctly
- **Code-text bridging**: Matches natural language to code examples

**Expected Outcome:** mdcontext demonstrates 35%+ improvement over BM25, competitive with GitHub Copilot, and exceeds Algolia for technical documentation—proving semantic search is not just "nice-to-have," but **essential** for intelligent documentation navigation.

---

## 10. Appendix: Full Query Test Set

### A1. Conceptual Queries (8 queries)

```json
[
  {
    "id": "C01",
    "query": "How do I make my search smarter?",
    "category": "conceptual",
    "difficulty": "hard",
    "expected_sections": [
      "README.md#setting-up-semantic-search",
      "docs/CONFIG.md#embeddings-configuration"
    ]
  },
  {
    "id": "C02",
    "query": "Speed up document processing",
    "category": "conceptual",
    "difficulty": "medium",
    "expected_sections": [
      "README.md#index",
      "docs/CONFIG.md#index-configuration"
    ]
  },
  {
    "id": "C03",
    "query": "Find stuff by meaning instead of words",
    "category": "conceptual",
    "difficulty": "hard",
    "expected_sections": [
      "README.md#search",
      "README.md#semantic-search"
    ]
  },
  {
    "id": "C04",
    "query": "Save my preferences across runs",
    "category": "conceptual",
    "difficulty": "medium",
    "expected_sections": [
      "docs/CONFIG.md#quick-start",
      "docs/CONFIG.md#config-file-formats"
    ]
  },
  {
    "id": "C05",
    "query": "Stop indexing unnecessary files",
    "category": "conceptual",
    "difficulty": "medium",
    "expected_sections": [
      "docs/CONFIG.md#index-configuration",
      "README.md#index"
    ]
  },
  {
    "id": "C06",
    "query": "What providers can I use offline?",
    "category": "conceptual",
    "difficulty": "hard",
    "expected_sections": [
      "README.md#ollama",
      "README.md#lm-studio",
      "docs/CONFIG.md#embedding-providers"
    ]
  },
  {
    "id": "C07",
    "query": "Get AI explanations of my results",
    "category": "conceptual",
    "difficulty": "medium",
    "expected_sections": [
      "README.md#ai-summarization",
      "docs/summarization.md"
    ]
  },
  {
    "id": "C08",
    "query": "Understand my codebase structure",
    "category": "conceptual",
    "difficulty": "medium",
    "expected_sections": [
      "README.md#tree",
      "README.md#links"
    ]
  }
]
```

### A2. Synonym Queries (6 groups)

```json
[
  {
    "id": "S01",
    "query_variants": [
      "authentication setup",
      "login configuration",
      "credential handling"
    ],
    "category": "synonym",
    "expected_sections": [
      "docs/CONFIG.md#embedding-providers",
      "README.md#environment-variables"
    ]
  },
  {
    "id": "S02",
    "query_variants": [
      "error messages",
      "failures",
      "problems"
    ],
    "category": "synonym",
    "expected_sections": [
      "docs/ERRORS.md"
    ]
  },
  {
    "id": "S03",
    "query_variants": [
      "search results",
      "query output",
      "findings"
    ],
    "category": "synonym",
    "expected_sections": [
      "README.md#search",
      "README.md#context-lines"
    ]
  },
  {
    "id": "S04",
    "query_variants": [
      "file organization",
      "directory layout",
      "folder hierarchy"
    ],
    "category": "synonym",
    "expected_sections": [
      "README.md#tree",
      "docs/DESIGN.md#index-structure"
    ]
  },
  {
    "id": "S05",
    "query_variants": [
      "speed improvements",
      "performance tuning",
      "optimization tips"
    ],
    "category": "synonym",
    "expected_sections": [
      "README.md#performance",
      "README.md#quality-modes"
    ]
  },
  {
    "id": "S06",
    "query_variants": [
      "cost calculation",
      "pricing estimate",
      "expense tracking"
    ],
    "category": "synonym",
    "expected_sections": [
      "README.md#cost-transparency",
      "docs/summarization.md#providers"
    ]
  }
]
```

### A3. Disambiguation Queries (6 queries)

```json
[
  {
    "id": "D01",
    "query": "index my project",
    "context": "User wants to build search index",
    "category": "disambiguation",
    "correct_sense": "index_command",
    "expected_sections": [
      "README.md#index"
    ],
    "avoid_sections": [
      "docs/DESIGN.md#index-structure"
    ]
  },
  {
    "id": "D02",
    "query": "search quality modes",
    "context": "Speed vs. accuracy tradeoff",
    "category": "disambiguation",
    "correct_sense": "quality_settings",
    "expected_sections": [
      "README.md#quality-modes"
    ]
  },
  {
    "id": "D03",
    "query": "link analysis",
    "context": "Document relationship analysis",
    "category": "disambiguation",
    "correct_sense": "document_links",
    "expected_sections": [
      "README.md#links",
      "README.md#backlinks"
    ]
  },
  {
    "id": "D04",
    "query": "vector search",
    "context": "Semantic/embedding-based search",
    "category": "disambiguation",
    "correct_sense": "embeddings",
    "expected_sections": [
      "README.md#semantic-search",
      "docs/CONFIG.md#embeddings-configuration"
    ]
  },
  {
    "id": "D05",
    "query": "context window limits",
    "context": "LLM token constraints",
    "category": "disambiguation",
    "correct_sense": "token_budget",
    "expected_sections": [
      "README.md#context",
      "README.md#token-budget"
    ]
  },
  {
    "id": "D06",
    "query": "provider configuration",
    "context": "Embedding provider setup",
    "category": "disambiguation",
    "correct_sense": "embedding_providers",
    "expected_sections": [
      "docs/CONFIG.md#embeddings-configuration",
      "README.md#setting-up-semantic-search"
    ]
  }
]
```

### A4. Multi-Hop Queries (5 queries)

```json
[
  {
    "id": "M01",
    "query": "How to use semantic search without spending money?",
    "category": "multi-hop",
    "reasoning_chain": [
      "Semantic search requires embeddings",
      "Free embeddings = local providers",
      "Local providers = Ollama or LM Studio"
    ],
    "expected_sections": [
      "README.md#ollama",
      "README.md#lm-studio",
      "docs/CONFIG.md#embedding-providers"
    ]
  },
  {
    "id": "M02",
    "query": "What's needed to enable the smartest search?",
    "category": "multi-hop",
    "reasoning_chain": [
      "'Smartest' = semantic search",
      "Semantic requires embeddings",
      "Embeddings require provider setup"
    ],
    "expected_sections": [
      "README.md#index",
      "README.md#setting-up-semantic-search",
      "docs/CONFIG.md#embeddings-configuration"
    ]
  },
  {
    "id": "M03",
    "query": "Find documents about configuration options for search results",
    "category": "multi-hop",
    "reasoning_chain": [
      "Search results = search command output",
      "Configuration options = config file settings",
      "Search-specific config = search.* namespace"
    ],
    "expected_sections": [
      "docs/CONFIG.md#search-configuration",
      "README.md#search"
    ]
  },
  {
    "id": "M04",
    "query": "How to reduce token usage when querying",
    "category": "multi-hop",
    "reasoning_chain": [
      "Token usage = context command output",
      "Reduce tokens = use filters or limits",
      "Filters = token budget flag, section filtering"
    ],
    "expected_sections": [
      "README.md#context",
      "README.md#section-filtering",
      "README.md#token-budget"
    ]
  },
  {
    "id": "M05",
    "query": "Set up offline semantic search from scratch",
    "category": "multi-hop",
    "reasoning_chain": [
      "Offline = no internet = local provider",
      "Local provider = Ollama or LM Studio",
      "From scratch = installation + config + indexing"
    ],
    "expected_sections": [
      "README.md#installation",
      "README.md#ollama",
      "README.md#index",
      "docs/CONFIG.md#embedding-providers"
    ]
  }
]
```

### A5. Code-Seeking Queries (7 queries)

```json
[
  {
    "id": "K01",
    "query": "Show me how to index with embeddings",
    "category": "code-seeking",
    "expected_code": "mdcontext index --embed",
    "expected_sections": [
      "README.md#index",
      "README.md#setting-up-semantic-search"
    ]
  },
  {
    "id": "K02",
    "query": "Example of semantic search",
    "category": "code-seeking",
    "expected_code": "mdcontext search \"authentication\"",
    "expected_sections": [
      "README.md#search",
      "README.md#semantic-search"
    ]
  },
  {
    "id": "K03",
    "query": "Configure custom exclude patterns",
    "category": "code-seeking",
    "expected_code": "excludePatterns: ['node_modules', '.git']",
    "expected_sections": [
      "docs/CONFIG.md#index-configuration",
      "docs/CONFIG.md#quick-start"
    ]
  },
  {
    "id": "K04",
    "query": "Set up Ollama for embeddings",
    "category": "code-seeking",
    "expected_code": "ollama serve && ollama pull nomic-embed-text",
    "expected_sections": [
      "README.md#ollama",
      "docs/CONFIG.md#embedding-providers"
    ]
  },
  {
    "id": "K05",
    "query": "Get AI summary of results",
    "category": "code-seeking",
    "expected_code": "mdcontext search \"query\" --summarize",
    "expected_sections": [
      "README.md#ai-summarization",
      "docs/summarization.md"
    ]
  },
  {
    "id": "K06",
    "query": "Check config file syntax",
    "category": "code-seeking",
    "expected_code": "/** @type {import('mdcontext').PartialMdContextConfig} */",
    "expected_sections": [
      "docs/CONFIG.md#config-file-formats",
      "docs/CONFIG.md#javascript-config-with-types"
    ]
  },
  {
    "id": "K07",
    "query": "Filter search results by token budget",
    "category": "code-seeking",
    "expected_code": "mdcontext context -t 500 README.md",
    "expected_sections": [
      "README.md#context"
    ]
  }
]
```

### A6. Negative Queries (5 queries)

```json
[
  {
    "id": "N01",
    "query": "How to configure Elasticsearch with mdcontext?",
    "category": "negative",
    "expected_result": "no_results",
    "reasoning": "mdcontext does not integrate with Elasticsearch"
  },
  {
    "id": "N02",
    "query": "Delete my index permanently",
    "category": "negative",
    "expected_result": "weak_matches_only",
    "reasoning": "No destructive deletion command"
  },
  {
    "id": "N03",
    "query": "mdcontext machine learning model training",
    "category": "negative",
    "expected_result": "clarification",
    "reasoning": "Uses pre-trained models, doesn't train"
  },
  {
    "id": "N04",
    "query": "Deploy mdcontext to AWS Lambda",
    "category": "negative",
    "expected_result": "no_results",
    "reasoning": "Not a deployment tool, CLI-focused"
  },
  {
    "id": "N05",
    "query": "Python API for mdcontext",
    "category": "negative",
    "expected_result": "no_results",
    "reasoning": "CLI tool, no official Python bindings"
  }
]
```

---

## 11. References & Sources

### Academic Benchmarks

- [MS MARCO: Benchmarking Ranking Models in the Large-Data Regime](https://dl.acm.org/doi/abs/10.1145/3404835.3462804)
- [BEIR: A Heterogeneous Benchmark for Zero-shot Evaluation of Information Retrieval Models](https://arxiv.org/abs/2104.08663)
- [HopRAG: Multi-Hop Reasoning for Logic-Aware Retrieval-Augmented Generation](https://arxiv.org/abs/2502.12442)
- [MultiHop-RAG: Benchmarking Retrieval-Augmented Generation for Multi-Hop Queries](https://openreview.net/forum?id=t4eB3zYWBK)

### Industry Implementations

- [GitHub Copilot: Instant Semantic Code Search Indexing](https://github.blog/changelog/2025-03-12-instant-semantic-code-search-indexing-now-generally-available-for-github-copilot/)
- [Algolia DocSearch v4: Reimagined with Conversational AI](https://www.algolia.com/blog/product/docsearch-reimagined)
- [Elasticsearch Semantic Search Guide](https://www.elastic.co/docs/solutions/search/semantic-search)
- [Pinecone: RAG Evaluation Best Practices](https://www.pinecone.io/learn/series/vector-databases-in-production-for-busy-engineers/rag-evaluation/)

### Evaluation Methodologies

- [The BEIR Benchmark & Elasticsearch Search Relevance Evaluation](https://www.elastic.co/search-labs/blog/evaluating-search-relevance-part-1)
- [What Benchmarks Exist for Semantic Search Evaluation?](https://milvus.io/ai-quick-reference/what-benchmarks-exist-for-semantic-search-evaluation)
- [Query Reformulation Techniques in Semantic Search](https://milvus.io/ai-quick-reference/what-techniques-exist-for-query-reformulation-in-semantic-search)
- [Semantic Approaches for Query Expansion](https://pmc.ncbi.nlm.nih.gov/articles/PMC11935759/)

---

**END OF PROPOSAL**

**Next Steps:**
1. Review and approve test categories
2. Finalize query set with human relevance judgments
3. Implement test harness
4. Run baseline evaluations
5. Execute mdcontext semantic search tests
6. Comparative analysis with GitHub Copilot, Algolia, Elasticsearch
7. Publish results and recommendations
