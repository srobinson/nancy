# RAG Benchmark Comparison: mdcontext vs. Traditional RAG Systems

**Version:** 1.0
**Date:** 2026-01-26
**Status:** Proposal

---

## Executive Summary

This proposal outlines a comprehensive benchmark to validate mdcontext's structural extraction approach against traditional RAG (Retrieval-Augmented Generation) systems. mdcontext claims **80%+ token reduction** while preserving semantic completeness—this benchmark will prove whether structural intelligence beats vector similarity for documentation retrieval.

**The Stakes:** If mdcontext wins, it demonstrates that understanding document structure outperforms semantic chunking for technical documentation. If it loses, we learn where hybrid approaches add value.

---

## 1. Vision: Why Benchmark Against RAG?

### The Core Hypothesis

Traditional RAG systems treat documentation as undifferentiated text:
- **Chunk blindly** (512-1024 tokens)
- **Embed everything** (high cost, high latency)
- **Retrieve by similarity** (no structural awareness)
- **Dump context** (wastes tokens on formatting)

mdcontext takes a different approach:
- **Parse structure** (sections, headings, code blocks)
- **Index intelligently** (BM25 + optional embeddings)
- **Retrieve precisely** (section-level granularity)
- **Compress aggressively** (extract structure, not text)

### Why This Matters

1. **Token Economics**: LLM costs are proportional to tokens. 80% reduction = 5x cost savings.
2. **Context Window Efficiency**: Smaller context = more room for conversation history and multi-document reasoning.
3. **Latency**: Less to read = faster LLM response times.
4. **Accuracy**: Structured context may reduce hallucination by providing clearer document boundaries.

### What We'll Learn

- Does structure-aware retrieval beat semantic chunking for technical docs?
- Where do traditional RAG embeddings add value mdcontext misses?
- What's the cost/latency/quality tradeoff in production?

---

## 2. Competitors: Who We're Testing Against

### Tier 1: Production RAG Frameworks

| Framework | Why Include | Expected Strengths | Expected Weaknesses |
|-----------|-------------|-------------------|---------------------|
| **LangChain** | Industry standard, highest adoption | Rich ecosystem, proven patterns | High overhead (~10ms), high token usage (~2.4k tokens) |
| **LlamaIndex** | Optimized for docs, strong retrieval | Good performance (~6ms overhead, ~1.6k tokens) | Less flexible than LangChain |
| **Haystack** | Lowest overhead, enterprise focus | Best performance (~5.9ms, ~1.57k tokens) | Steeper learning curve |

*Source: [RAG Frameworks in 2026 Benchmark](https://research.aimultiple.com/rag-frameworks/)*

### Tier 2: Specialized Document RAG

| System | Why Include | Expected Strengths |
|--------|-------------|-------------------|
| **Document GraphRAG** | Structure-aware (like mdcontext) | Knowledge graph integration, relationship modeling |
| **LlamaIndex Document Store** | Document-optimized indexing | Metadata filtering, multi-document reasoning |

### Baseline Configurations

Each competitor will be tested in 3 configurations:

1. **Vanilla RAG**: Simple chunking (512 tokens) + OpenAI embeddings + top-k retrieval
2. **Advanced RAG**: Smart chunking + re-ranking + HyDE query expansion
3. **Production RAG**: Hybrid search (dense + sparse) + caching + result fusion

### mdcontext Configurations

1. **Keyword-only** (BM25, no embeddings)
2. **Semantic** (with OpenAI embeddings)
3. **Advanced** (semantic + re-ranking + HyDE)

---

## 3. Metrics: What Makes a RAG System "Good"?

### 3.1 Retrieval Quality (Primary)

Based on RAGAS and TruLens frameworks:

#### Context Precision (Order-Aware)
- **Definition**: Are the top-k results actually relevant? Are the best results ranked highest?
- **Measurement**: Precision@k with position weighting (NDCG-style)
- **Formula**: `(# relevant in top-k) / k × position_weight`
- **Target**: >0.90 @ k=5

#### Context Recall (Completeness)
- **Definition**: Did we retrieve all relevant information that exists?
- **Measurement**: `(relevant sections retrieved) / (total relevant sections)`
- **Target**: >0.85

#### Mean Reciprocal Rank (MRR)
- **Definition**: How quickly does the user find the answer?
- **Measurement**: `1 / rank_of_first_relevant_result`
- **Target**: >0.75 (relevant result in top 2 on average)

*Source: [RAG Retrieval Quality Metrics](https://deconvoluteai.com/blog/rag/metrics-retrieval)*

### 3.2 Generation Quality (End-to-End)

#### Answer Relevance
- **Definition**: Does the LLM's answer actually address the query?
- **Measurement**: Semantic similarity between query intent and answer (0-1)
- **Target**: >0.85

#### Faithfulness (Grounding)
- **Definition**: Is the answer factually consistent with retrieved context?
- **Measurement**: LLM-as-judge: claim extraction → fact verification against context
- **Target**: >0.95 (enterprise requirement)

#### Answer Similarity (with Ground Truth)
- **Definition**: How close is the generated answer to the expert-written answer?
- **Measurement**: Semantic embedding cosine similarity
- **Target**: >0.80

*Source: [RAGAS Evaluation Framework](https://arxiv.org/abs/2309.15217)*

### 3.3 Operational Efficiency

#### Token Efficiency
- **Context Size**: Median tokens per query (lower = better)
- **Compression Ratio**: `raw_tokens / context_tokens` (higher = better)
- **Target**: mdcontext should achieve 5x compression vs. vanilla RAG

#### Latency (p50, p95, p99)
- **Retrieval**: Time from query to context ready
- **E2E**: Time from query to first LLM token
- **Target**: <100ms retrieval, <2s E2E @ p95

#### Cost per Query
- **Embedding cost**: Indexing + query encoding
- **LLM cost**: Context tokens × provider rate
- **Infrastructure**: Vector DB / index storage
- **Target**: mdcontext <$0.01 per query (vs. $0.05-0.10 for traditional RAG)

*Source: [RAG Performance Benchmarking](https://research.aimultiple.com/rag-monitoring/)*

### 3.4 Specialized Metrics for Documentation

#### Section Boundary Preservation
- **Definition**: Does the retrieved context respect logical document structure?
- **Measurement**: Manual evaluation—do chunks split mid-concept?
- **Hypothesis**: mdcontext excels here due to AST-based parsing

#### Code Block Integrity
- **Definition**: Are code examples retrieved completely (not truncated)?
- **Measurement**: % of queries where code blocks are complete
- **Hypothesis**: mdcontext preserves code blocks via structural extraction

#### Link Graph Utilization
- **Definition**: Does the system leverage cross-references between docs?
- **Measurement**: % improvement when backlinks/forward links are available
- **Hypothesis**: mdcontext's link analysis provides unique value

---

## 4. Test Dataset: agentic-flow Documentation Corpus

### 4.1 Corpus Characteristics

**Source**: agentic-flow project documentation (2000+ markdown files)

**Statistics**:
- Total files: 2000+
- Total tokens: ~500K (estimated based on "50K tokens of markdown" × scale factor)
- File types: README, API docs, guides, tutorials, architecture docs
- Structure: Deep hierarchy with cross-references

**Why This Corpus?**
- Real-world complexity (not synthetic)
- Multiple document types (tutorials, API refs, conceptual)
- Rich internal linking structure
- Large enough to stress-test retrieval
- Representative of modern documentation sites

### 4.2 Query Categories (100 Test Queries)

Inspired by FreshStack and DesignQA research on technical documentation retrieval.

#### Category 1: Direct Fact Lookup (20 queries)
**Purpose**: Test precision for simple retrieval

Examples:
- "What is the default timeout for agent execution?"
- "Which environment variable configures the OpenAI API key?"
- "What's the minimum Node.js version required?"

**Ground Truth**: Single section containing exact answer

---

#### Category 2: Conceptual Explanation (20 queries)
**Purpose**: Test recall and multi-section aggregation

Examples:
- "How does the checkpoint system work?"
- "Explain the difference between stateful and stateless agents"
- "What is the agent lifecycle from initialization to completion?"

**Ground Truth**: Multiple related sections (2-5) spanning concept explanation

---

#### Category 3: How-To / Procedural (20 queries)
**Purpose**: Test sequential information retrieval

Examples:
- "How do I set up authentication for production deployment?"
- "Walk me through creating a custom agent from scratch"
- "What are the steps to debug a failing agent execution?"

**Ground Truth**: Step-by-step procedures (potentially across multiple docs)

---

#### Category 4: Troubleshooting / Error Resolution (15 queries)
**Purpose**: Test cross-document navigation and diagnosis

Examples:
- "Why is my agent timing out during execution?"
- "How do I fix 'checkpoint not found' errors?"
- "Agent returns undefined—what are common causes?"

**Ground Truth**: Error documentation + related configuration + debugging guides

---

#### Category 5: API Reference (15 queries)
**Purpose**: Test structured data retrieval (parameters, return types)

Examples:
- "What parameters does the AgentExecutor.run() method accept?"
- "What's the return type of checkpoint.save()?"
- "List all configuration options for the checkpointing system"

**Ground Truth**: API documentation sections with type information

---

#### Category 6: Architecture / Design Decisions (10 queries)
**Purpose**: Test deep conceptual understanding and "why" questions

Examples:
- "Why did the project choose to separate agent definition from execution?"
- "What are the tradeoffs between different checkpointing strategies?"
- "How does the system handle concurrent agent execution?"

**Ground Truth**: Architecture docs, design rationale, potentially GitHub discussions

---

### 4.3 Ground Truth Annotation

**Process**:
1. **Expert Annotation**: Developer familiar with agentic-flow writes ideal answers
2. **Source Mapping**: Annotator marks which sections were needed
3. **Relevance Grading**: Each source section scored 0-3
   - 0: Irrelevant
   - 1: Tangentially related
   - 2: Useful supporting info
   - 3: Essential (directly answers query)

**Output Format** (JSON):
```json
{
  "query_id": "Q027",
  "query": "How does the checkpoint system work?",
  "category": "conceptual_explanation",
  "ground_truth_answer": "The checkpoint system allows agents to persist state...",
  "relevant_sections": [
    {
      "file": "docs/architecture/checkpointing.md",
      "section": "## Checkpoint Lifecycle",
      "relevance": 3,
      "tokens": 342
    },
    {
      "file": "docs/api/checkpoint.md",
      "section": "### checkpoint.save()",
      "relevance": 2,
      "tokens": 156
    }
  ],
  "required_tokens": 498,
  "complexity": "medium"
}
```

### 4.4 Dataset Splits

- **Development Set**: 20 queries (for tuning thresholds, re-ranking weights)
- **Test Set**: 80 queries (for final evaluation, never seen during tuning)

### 4.5 Validation Against Existing Benchmarks

To ensure our dataset has academic rigor, we'll align our annotation methodology with:
- **BEIR** evaluation protocols (graded relevance)
- **MS MARCO** passage ranking metrics
- **FreshStack** technical document retrieval patterns
- **RAGBench** industry-specific domain coverage

*Sources:*
- [BEIR Benchmark](https://www.elastic.co/search-labs/blog/evaluating-search-relevance-part-1)
- [FreshStack Technical Docs](https://arxiv.org/html/2504.13128)
- [RAGBench Industry Domains](https://arxiv.org/abs/2407.11005)

---

## 5. Evaluation Protocol: Running a Fair Comparison

### 5.1 Hardware & Environment

**Standardized Setup**:
- MacBook Pro M3 Max (16-core CPU, 128GB RAM)
- Node.js 22 LTS
- Python 3.11 (for competitor frameworks)
- OpenAI API (gpt-4-turbo for generation, text-embedding-3-large for embeddings)

**Isolation**:
- Cold start measurements (clear caches between runs)
- Warm cache measurements (3 consecutive runs, report median)
- Network latency mocked/controlled for API calls

---

### 5.2 Indexing Phase (One-Time Setup)

Each system indexes the 2000+ markdown files:

#### mdcontext
```bash
mdcontext index /path/to/agentic-flow/docs --embed --provider openai
```

**Measurements**:
- Index build time
- Index size on disk
- Embedding API calls & cost
- Memory peak during indexing

#### LangChain (Vanilla RAG)
```python
from langchain_community.document_loaders import DirectoryLoader
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain_openai import OpenAIEmbeddings
from langchain_community.vectorstores import FAISS

loader = DirectoryLoader("/path/to/agentic-flow/docs", glob="**/*.md")
docs = loader.load()
text_splitter = RecursiveCharacterTextSplitter(chunk_size=512, chunk_overlap=50)
splits = text_splitter.split_documents(docs)
embeddings = OpenAIEmbeddings(model="text-embedding-3-large")
vectorstore = FAISS.from_documents(splits, embeddings)
```

#### LlamaIndex (Document Store)
```python
from llama_index import VectorStoreIndex, SimpleDirectoryReader
from llama_index.node_parser import SimpleNodeParser

documents = SimpleDirectoryReader("/path/to/agentic-flow/docs").load_data()
parser = SimpleNodeParser.from_defaults(chunk_size=512, chunk_overlap=20)
nodes = parser.get_nodes_from_documents(documents)
index = VectorStoreIndex(nodes)
```

#### Haystack (Hybrid Pipeline)
```python
from haystack import Pipeline
from haystack.document_stores import InMemoryDocumentStore
from haystack.components.embedders import SentenceTransformersDocumentEmbedder

document_store = InMemoryDocumentStore()
embedder = SentenceTransformersDocumentEmbedder(model="all-MiniLM-L6-v2")
# ... pipeline construction
```

**Normalization**: All systems use same embedding model (text-embedding-3-large) for fair comparison.

---

### 5.3 Query Phase (Per-Query Evaluation)

For each of 100 test queries:

#### Step 1: Retrieval
- System retrieves top-k documents/sections (k=5 for primary eval, vary 3-10 for sensitivity)
- Measure retrieval latency (p50, p95, p99 across all queries)
- Log retrieved content (file, section, tokens)

#### Step 2: Context Preparation
- mdcontext: Use `mdcontext context` to generate LLM-ready summary
- Competitors: Concatenate retrieved chunks with separators

**Token Counting**: Use tiktoken (cl100k_base) to measure context size

#### Step 3: Generation (LLM Call)
- Same prompt template for all systems:
  ```
  You are a helpful assistant. Answer the user's question based ONLY on the provided context.

  Context:
  {retrieved_context}

  Question: {query}

  Answer:
  ```
- Model: gpt-4-turbo (consistent across all systems)
- Temperature: 0 (deterministic)
- Measure E2E latency

#### Step 4: Evaluation
- **Automated Metrics**: Precision, Recall, MRR, Answer Similarity
- **LLM-as-Judge**: Faithfulness, Answer Relevance (GPT-4 evaluates each answer)
- **Manual Spot Checks**: 10% of queries reviewed by human expert

---

### 5.4 Experimental Design

#### Experiment 1: Baseline Comparison
**Goal**: Establish performance floor

- mdcontext (keyword-only, BM25)
- LangChain (vanilla RAG, no re-ranking)
- LlamaIndex (default config)
- Haystack (basic BM25)

**Metrics Focus**: Retrieval quality, token efficiency

---

#### Experiment 2: Semantic Search
**Goal**: Test embedding-based retrieval

- mdcontext (with embeddings)
- LangChain (FAISS vector search)
- LlamaIndex (vector index)
- Haystack (dense retrieval)

**Metrics Focus**: Answer quality, recall on complex queries

---

#### Experiment 3: Advanced Techniques
**Goal**: Push all systems to their best

- mdcontext (embeddings + re-ranking + HyDE)
- LangChain (hybrid search + re-ranking)
- LlamaIndex (query engine with fusion)
- Haystack (pipeline with extractive QA)

**Metrics Focus**: Peak performance, cost-quality tradeoff

---

#### Experiment 4: Ablation Studies
**Goal**: Understand mdcontext's secret sauce

Test mdcontext with features disabled:
- No structure parsing (treat as raw text)
- No section-level retrieval (chunk like competitors)
- No link graph
- No token compression

**Hypothesis**: Structure awareness is the key differentiator

---

#### Experiment 5: Scalability
**Goal**: Stress test at production scale

- 10x corpus (20,000 docs via duplication + synthetic variations)
- 1000 queries (10x test set via paraphrasing)
- Measure latency degradation, index size growth

---

### 5.5 Statistical Rigor

**Sample Size**: 100 queries × 6 systems = 600 evaluations (primary)

**Significance Testing**: Paired t-tests for metric comparisons (e.g., mdcontext precision vs. LangChain precision)

**Confidence Intervals**: Report 95% CI for all primary metrics

**Multiple Comparisons**: Bonferroni correction when comparing multiple systems

---

## 6. Expected Results & Success Criteria

### 6.1 Hypothesis: mdcontext Wins on Efficiency, Ties on Quality

**Token Efficiency**:
- mdcontext: 400-600 tokens per query (80% reduction vs. raw markdown)
- Competitors: 2000-2500 tokens per query (standard chunking)
- **Win Condition**: mdcontext achieves ≥4x token reduction

**Retrieval Quality**:
- mdcontext: Precision@5 = 0.88, Recall = 0.82, MRR = 0.74
- Competitors: Precision@5 = 0.85, Recall = 0.80, MRR = 0.70
- **Win Condition**: mdcontext matches or exceeds on ≥2 of 3 metrics

**Answer Quality**:
- All systems: Faithfulness ≥0.92 (high-quality retrieval helps everyone)
- mdcontext: Answer Relevance = 0.84 (slight edge due to less noise)
- **Win Condition**: mdcontext within 5% of best competitor

**Latency**:
- mdcontext: Retrieval 60ms @ p95 (local index, no vector DB)
- Competitors: Retrieval 120-200ms @ p95 (FAISS/pinecone overhead)
- **Win Condition**: mdcontext ≤50% latency of competitors

**Cost**:
- mdcontext: $0.008 per query (4x fewer LLM tokens)
- Competitors: $0.040 per query (standard context size)
- **Win Condition**: mdcontext ≤25% cost of competitors

---

### 6.2 Where mdcontext Might Lose (And That's OK)

#### Complex Multi-Hop Queries
- **Challenge**: "Compare the checkpoint strategies in docs A, B, C and recommend the best for scenario X"
- **Why Competitors Might Win**: GraphRAG's relationship modeling may excel here
- **Learning**: Should mdcontext add graph-aware retrieval?

#### Ambiguous/Vague Queries
- **Challenge**: "Tell me about agents" (too broad)
- **Why Competitors Might Win**: Dense retrieval captures semantic similarity better than keyword BM25
- **Learning**: HyDE and query expansion help—but at what cost?

#### Queries Requiring Deep Context
- **Challenge**: Needs 5+ sections spanning multiple files
- **Why Competitors Might Win**: Larger context windows may provide more complete answers
- **Learning**: Does structural compression lose critical details?

---

### 6.3 Success Criteria (Go/No-Go for mdcontext)

**Tier 1 (Must-Have)**:
- Token efficiency: ≥3x reduction vs. best competitor ✅
- Retrieval precision: Within 10% of best competitor ✅
- Cost per query: ≤50% of best competitor ✅

**Tier 2 (Strong Validation)**:
- Answer quality: Within 5% of best competitor on faithfulness
- Latency: ≤50% of best competitor (p95)
- Recall: ≥0.80 on complex queries

**Tier 3 (Competitive Advantage)**:
- Wins on section boundary preservation
- Wins on code block integrity
- Demonstrates unique value via link graph utilization

**Failure Mode**: If mdcontext doesn't meet Tier 1 criteria, the structural approach needs rethinking.

---

## 7. Execution Plan

### Phase 1: Dataset Creation (2 weeks)
- [ ] Index agentic-flow corpus with mdcontext
- [ ] Sample 100 diverse queries across 6 categories
- [ ] Expert annotation of ground truth answers
- [ ] Map relevant sections for each query
- [ ] Validate against BEIR/RAGBench annotation standards

### Phase 2: System Setup (1 week)
- [ ] Implement LangChain baseline
- [ ] Implement LlamaIndex baseline
- [ ] Implement Haystack baseline
- [ ] Standardize embedding model across all systems
- [ ] Dockerize environments for reproducibility

### Phase 3: Experiment Execution (2 weeks)
- [ ] Run Experiment 1: Baseline Comparison
- [ ] Run Experiment 2: Semantic Search
- [ ] Run Experiment 3: Advanced Techniques
- [ ] Run Experiment 4: Ablation Studies
- [ ] Run Experiment 5: Scalability Test

### Phase 4: Analysis & Reporting (1 week)
- [ ] Aggregate metrics across all experiments
- [ ] Statistical significance testing
- [ ] Identify failure modes for each system
- [ ] Generate visualizations (precision-recall curves, latency histograms, cost breakdowns)
- [ ] Write academic-style paper (8-10 pages)

**Total Timeline**: 6 weeks

---

## 8. Deliverables

### 8.1 Public Benchmark Dataset
- `agentic-flow-rag-bench/`
  - `queries.json` (100 annotated queries)
  - `ground_truth.json` (expert answers + relevant sections)
  - `corpus/` (2000+ markdown files, anonymized if needed)
  - `eval_scripts/` (automated metric calculation)

**Goal**: Open-source for community to reproduce and extend

---

### 8.2 Benchmark Results Dashboard
Interactive HTML report with:
- **Leaderboard**: Systems ranked by metric
- **Per-Query Breakdown**: Drill into specific failures/successes
- **Cost Calculator**: "Your corpus has X tokens, here's your monthly cost"
- **Interactive Plots**: Latency vs. Quality tradeoffs

**Tech Stack**: Observable Framework or Streamlit

---

### 8.3 Research Paper
Title: *"Structure Beats Similarity: Evaluating Document-Aware Retrieval for Technical Documentation"*

**Sections**:
1. Introduction (RAG limitations, mdcontext approach)
2. Related Work (RAGAS, TruLens, BEIR, FreshStack)
3. Methodology (dataset, metrics, competitors)
4. Results (tables, graphs, statistical tests)
5. Analysis (where mdcontext wins/loses, why)
6. Implications (when to use structural vs. semantic retrieval)
7. Future Work (hybrid approaches, graph integration)

**Target Venue**: arXiv pre-print + submit to EMNLP/ACL workshop

---

### 8.4 Product Insights
- **Feature Roadmap**: Which mdcontext features matter most?
- **Competitive Positioning**: How to market against LangChain/LlamaIndex
- **Pricing Model**: Cost savings calculator for enterprise customers

---

## 9. Open Questions & Risks

### 9.1 Dataset Risks
- **Bias**: agentic-flow may favor mdcontext (it was built for this use case)
  - *Mitigation*: Include 2nd corpus (e.g., React docs, FastAPI docs) for generalization test
- **Annotation Quality**: Human bias in ground truth
  - *Mitigation*: Multi-annotator agreement metrics (Cohen's kappa ≥0.7)

### 9.2 Technical Challenges
- **Embedding Costs**: Indexing 2000+ docs with OpenAI embeddings = $$
  - *Mitigation*: Use Ollama (local, free) for development, OpenAI for final eval
- **LLM API Rate Limits**: 600+ generation calls may hit quotas
  - *Mitigation*: Batch requests, use multiple API keys, or self-host with vLLM

### 9.3 Competitor Setup Complexity
- **Risk**: Misconfigured competitor = unfair comparison
  - *Mitigation*: Consult each framework's official docs, use recommended defaults
- **Risk**: Framework updates mid-benchmark
  - *Mitigation*: Pin versions, document dependencies (requirements.txt, package.json)

---

## 10. Why This Will Make mdcontext Legendary

### 10.1 Academic Credibility
- First rigorous benchmark comparing structural vs. semantic retrieval
- Open dataset others can build on (citations = visibility)
- Aligns with 2026 RAG evaluation best practices (RAGAS, TruLens)

### 10.2 Marketing Gold
- "5x more efficient than LangChain" (with receipts)
- "Beats LlamaIndex on technical docs" (specific, defensible claim)
- "Open benchmark—run it yourself" (transparency builds trust)

### 10.3 Product Roadmap Clarity
- Know exactly where to invest (e.g., if embeddings don't help much, deprioritize)
- Identify hybrid opportunities (structure + graph = next-gen RAG?)
- Competitive moat (if we publish first, we define the narrative)

### 10.4 Community Building
- Invite researchers to contribute queries/corpora
- Host Kaggle competition ("Beat mdcontext on our benchmark")
- Annual leaderboard (like HELM, Chatbot Arena)

---

## 11. Next Steps

1. **Get Buy-In**: Review this proposal with stakeholders
2. **Recruit Annotators**: Need 1-2 agentic-flow experts for ground truth
3. **Secure Compute**: Provision GPU/API credits for experiments
4. **Build v0.1 Dataset**: Start with 20 queries, validate methodology
5. **Run Pilot**: Compare mdcontext vs. LangChain on 20 queries (1 week)
6. **Iterate**: Refine metrics, adjust competitors based on pilot learnings
7. **Full Execution**: Scale to 100 queries, all experiments (weeks 2-6)

---

## Appendix: References

### RAG Evaluation Frameworks
- [RAGAS: Automated Evaluation of RAG](https://arxiv.org/abs/2309.15217) - arXiv, 2023
- [RAG Triad - TruLens](https://www.trulens.org/getting_started/core_concepts/rag_triad/) - TruLens Documentation, 2026
- [RAG Evaluation Tools Comparison](https://research.aimultiple.com/rag-evaluation-tools/) - AIMultiple Research, 2026

### RAG Best Practices
- [LlamaIndex Evaluation Guide](https://docs.llamaindex.ai/en/stable/module_guides/evaluating/) - LlamaIndex Docs, 2026
- [Complete Guide to RAG Evaluation](https://www.evidentlyai.com/llm-guide/rag-evaluation) - EvidentlyAI, 2026
- [RAG Evaluation Metrics Best Practices](https://www.patronus.ai/llm-testing/rag-evaluation-metrics) - Patronus AI, 2026

### RAG Benchmarks
- [BEIR Benchmark](https://www.elastic.co/search-labs/blog/evaluating-search-relevance-part-1) - Elastic, 2026
- [RAGBench: Explainable Benchmark](https://arxiv.org/abs/2407.11005) - arXiv, 2024
- [FreshStack: Technical Documentation Benchmark](https://arxiv.org/html/2504.13128) - arXiv, 2025

### Framework Comparisons
- [RAG Frameworks in 2026](https://research.aimultiple.com/rag-frameworks/) - AIMultiple Research, 2026
- [LangChain Performance Tuning](https://langchain-tutorials.github.io/langchain-performance-tuning-2026/) - LangChain Tutorials, 2026
- [Production RAG: LangChain vs LlamaIndex](https://rahulkolekar.com/production-rag-in-2026-langchain-vs-llamaindex/) - Rahul Kolekar, 2026

### Retrieval Metrics
- [Metrics for Retrieval in RAG Systems](https://deconvoluteai.com/blog/rag/metrics-retrieval) - DeconvoluteAI, 2026
- [RAG Evaluation: 2026 Metrics and Benchmarks](https://labelyourdata.com/articles/llm-fine-tuning/rag-evaluation) - Label Your Data, 2026
- [Evaluating Precision and Recall](https://www.sciencepublishinggroup.com/article/10.11648/j.ajcst.20250804.11) - American Journal of Computer Science, 2025

### Documentation-Specific Research
- [MMDocRAG Multimodal Benchmark](https://arxiv.org/html/2505.16470v1) - arXiv, 2025
- [FreshStack Technical Documents](https://arxiv.org/html/2504.13128) - arXiv, 2025
- [Document GraphRAG](https://www.mdpi.com/2079-9292/14/11/2102) - Electronics MDPI, 2025

---

## Appendix: Example Test Queries

### Category: Direct Fact Lookup
```json
{
  "query_id": "Q001",
  "query": "What is the default similarity threshold for semantic search?",
  "category": "fact_lookup",
  "expected_tokens": 50,
  "difficulty": "easy"
}
```

### Category: Conceptual Explanation
```json
{
  "query_id": "Q023",
  "query": "Explain how mdcontext reduces token usage compared to raw markdown",
  "category": "conceptual_explanation",
  "expected_tokens": 300,
  "difficulty": "medium"
}
```

### Category: How-To
```json
{
  "query_id": "Q047",
  "query": "How do I configure HyDE query expansion with Ollama embeddings?",
  "category": "how_to",
  "expected_tokens": 200,
  "difficulty": "hard"
}
```

### Category: Troubleshooting
```json
{
  "query_id": "Q068",
  "query": "Search returns empty results despite documents existing—what should I check?",
  "category": "troubleshooting",
  "expected_tokens": 250,
  "difficulty": "medium"
}
```

### Category: API Reference
```json
{
  "query_id": "Q082",
  "query": "What are all the configuration options for the embeddings.hnsw setting?",
  "category": "api_reference",
  "expected_tokens": 150,
  "difficulty": "easy"
}
```

### Category: Architecture
```json
{
  "query_id": "Q095",
  "query": "Why does mdcontext use BM25 for keyword search instead of TF-IDF?",
  "category": "architecture",
  "expected_tokens": 350,
  "difficulty": "hard"
}
```

---

**End of Proposal**

*This document represents a complete, executable plan to validate mdcontext's core value proposition through rigorous scientific evaluation. Let's prove that structure beats similarity.*
