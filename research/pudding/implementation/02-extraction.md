# Data Extraction & Processing Pipeline
## Knowledge Graph Construction from 2066 Markdown Files

**Generated:** 2026-01-26
**Target Dataset:** agentic-flow documentation (10 markdown files observed, scalable to 2066)
**mdcontext Version:** 0.1.0

---

## Executive Summary

This document defines the **data extraction and processing pipeline** that transforms raw markdown documentation into structured entities and relationships for knowledge graph construction. The pipeline leverages mdcontext's existing indexing infrastructure while adding concept extraction, relationship discovery, and semantic analysis capabilities.

**Key Insight:** mdcontext already extracts 90% of what we need. The indexing system produces:
- Document metadata (title, path, tokens, sections)
- Section hierarchy (headings, levels, content, line numbers)
- Link graph (forward/backward references, broken links)
- Code blocks (language, content, location)
- Embeddings (semantic vectors via HNSW index)
- BM25 index (keyword search via wink-bm25)

**What We Add:** Concept extraction, relationship discovery, and entity normalization on top of mdcontext's foundation.

---

## 1. Input Sources

### 1.1 mdcontext Index Files

The `.mdcontext/` directory contains all structured data:

```
.mdcontext/
├── indexes/
│   ├── documents.json      # Document-level metadata
│   ├── sections.json       # Section hierarchy
│   ├── links.json          # Link graph
│   └── bm25.json          # Keyword index
└── vectors.bin            # HNSW embeddings (if enabled)
```

#### documents.json Structure

```json
{
  "version": 1,
  "rootPath": "/path/to/docs",
  "documents": {
    "01-core-architecture.md": {
      "id": "abc123def456",
      "path": "01-core-architecture.md",
      "title": "Agentic Flow - Core Architecture Deep Dive",
      "mtime": 1706016900000,
      "hash": "d41d8cd98f00b204e9800998ecf8427e",
      "tokenCount": 5234,
      "sectionCount": 28
    }
  }
}
```

**Extract:**
- Document ID (unique identifier)
- File path (relative to root)
- Title (for graph node labels)
- Token count (for importance weighting)
- Section count (structural complexity indicator)
- Modification time (for temporal analysis)

#### sections.json Structure

```json
{
  "version": 1,
  "sections": {
    "abc123-core-architecture": {
      "id": "abc123-core-architecture",
      "documentId": "abc123def456",
      "documentPath": "01-core-architecture.md",
      "heading": "Core Architecture",
      "level": 2,
      "startLine": 23,
      "endLine": 150,
      "tokenCount": 800,
      "hasCode": true,
      "hasList": true,
      "hasTable": false
    }
  },
  "byHeading": {
    "core architecture": ["abc123-core-architecture", "xyz789-architecture-overview"],
    "agent loading": ["def456-agent-loading"]
  },
  "byDocument": {
    "abc123def456": ["abc123-intro", "abc123-core-architecture", "abc123-patterns"]
  }
}
```

**Extract:**
- Section ID (for entity linking)
- Heading text (concept source)
- Hierarchy level (importance weighting)
- Line numbers (for content extraction)
- Metadata flags (code/list/table presence)
- Document mapping (for graph edges)

#### links.json Structure

```json
{
  "version": 1,
  "forward": {
    "01-core-architecture.md": [
      "02-agent-system-design.md",
      "04-state-persistence.md"
    ]
  },
  "backward": {
    "02-agent-system-design.md": [
      "01-core-architecture.md",
      "03-orchestration-patterns.md"
    ]
  },
  "broken": ["nonexistent-guide.md"]
}
```

**Extract:**
- Explicit document relationships (LINKS_TO edges)
- Bidirectional link graph (for PageRank/centrality)
- Broken links (data quality signal)

### 1.2 Raw Markdown Files

For concept extraction and content analysis, read original markdown:

```typescript
import { parse } from 'mdcontext/parser';

// Parse single file
const doc = await parse(fileContent, {
  path: 'docs/architecture.md',
  lastModified: new Date()
});

// Access structured data
doc.sections.forEach(section => {
  console.log(section.heading, section.content, section.plainText);
});

doc.codeBlocks.forEach(code => {
  console.log(code.language, code.content);
});

doc.links.forEach(link => {
  console.log(link.type, link.href, link.text);
});
```

**Parser Capabilities (from `/Users/alphab/Dev/LLM/DEV/mdcontext/src/parser/parser.ts`):**
- Remark/unified with GFM support
- YAML frontmatter extraction
- Section hierarchy with nesting
- Plain text extraction (removes markdown formatting)
- Link classification (internal/external/image)
- Code block extraction with language tags
- Token/word counts per section

### 1.3 Embedding Vectors (Optional but Recommended)

If semantic search is enabled, vectors.bin contains:

```typescript
import { createVectorStore } from 'mdcontext/embeddings';

const store = createVectorStore(rootPath, dimensions);
await store.load();

// Search for similar sections
const results = await store.search(queryVector, limit=20, threshold=0.65);
// Returns: { sectionId, documentPath, heading, similarity }
```

**Use Cases:**
- Find semantically similar sections (SIMILAR_TO edges)
- Topic clustering (k-means on embeddings)
- Concept disambiguation (related concepts have similar embeddings)

---

## 2. Entity Extraction

### 2.1 Document-Level Entities

**Source:** `documents.json`
**Entity Type:** `Document`
**Properties:**

```typescript
interface DocumentEntity {
  id: string;                    // From index
  path: string;                  // Relative path
  title: string;                 // Extracted title
  tokenCount: number;            // Token budget
  sectionCount: number;          // Structural complexity
  category?: string;             // Inferred from path/title
  topicCluster?: string;         // From embedding clustering
  pageRank?: number;             // From link analysis
}
```

**Extraction Logic:**

```typescript
function extractDocuments(docsIndex: DocumentIndex): DocumentEntity[] {
  return Object.values(docsIndex.documents).map(doc => ({
    id: doc.id,
    path: doc.path,
    title: doc.title,
    tokenCount: doc.tokenCount,
    sectionCount: doc.sectionCount,
    category: inferCategory(doc.path, doc.title),
    topicCluster: null, // Computed later via clustering
    pageRank: null      // Computed later via link analysis
  }));
}

function inferCategory(path: string, title: string): string {
  // Pattern matching on path/title
  if (path.includes('architecture')) return 'Architecture';
  if (path.includes('agent')) return 'Agent System';
  if (path.includes('deploy')) return 'Deployment';
  if (title.toLowerCase().includes('example')) return 'Examples';
  return 'General';
}
```

### 2.2 Section-Level Entities

**Source:** `sections.json` + raw markdown content
**Entity Type:** `Section`
**Properties:**

```typescript
interface SectionEntity {
  id: string;                    // From index
  documentId: string;            // Parent document
  heading: string;               // Section title
  level: number;                 // 1-6 (H1-H6)
  content: string;               // Full markdown content
  plainText: string;             // Text-only content
  tokenCount: number;            // Section size
  hasCode: boolean;              // Contains code blocks
  hasList: boolean;              // Contains lists
  hasTable: boolean;             // Contains tables
  keywords: string[];            // Extracted keywords (see 2.4)
}
```

**Extraction Logic:**

```typescript
async function extractSections(
  sectionsIndex: SectionIndex,
  rootPath: string
): Promise<SectionEntity[]> {
  const sections: SectionEntity[] = [];

  // Group sections by document for efficient reading
  const byDoc = new Map<string, SectionEntry[]>();
  for (const section of Object.values(sectionsIndex.sections)) {
    const existing = byDoc.get(section.documentPath) || [];
    existing.push(section);
    byDoc.set(section.documentPath, existing);
  }

  // Read each document once, extract all sections
  for (const [docPath, sectionList] of byDoc) {
    const filePath = path.join(rootPath, docPath);
    const content = await fs.readFile(filePath, 'utf-8');
    const lines = content.split('\n');

    for (const section of sectionList) {
      const sectionContent = lines.slice(
        section.startLine - 1,
        section.endLine
      ).join('\n');

      const plainText = extractPlainText(sectionContent);
      const keywords = extractKeywords(plainText); // See 2.4

      sections.push({
        id: section.id,
        documentId: section.documentId,
        heading: section.heading,
        level: section.level,
        content: sectionContent,
        plainText: plainText,
        tokenCount: section.tokenCount,
        hasCode: section.hasCode,
        hasList: section.hasList,
        hasTable: section.hasTable,
        keywords: keywords
      });
    }
  }

  return sections;
}

function extractPlainText(markdown: string): string {
  // Remove markdown formatting
  return markdown
    .replace(/^#{1,6}\s+/gm, '')      // Remove headers
    .replace(/\*\*(.+?)\*\*/g, '$1')  // Remove bold
    .replace(/\*(.+?)\*/g, '$1')      // Remove italic
    .replace(/`(.+?)`/g, '$1')        // Remove inline code
    .replace(/\[(.+?)\]\(.+?\)/g, '$1') // Links -> text
    .replace(/^\s*[-*+]\s+/gm, '')    // Remove list markers
    .trim();
}
```

### 2.3 Concept Extraction

**Goal:** Identify technical terms, APIs, features, patterns that appear across documents.

**Concept Types:**
- **Feature:** "authentication", "rate limiting", "caching"
- **Configuration:** "API_KEY", "max_retries", "timeout"
- **API:** "Agent.query()", "loadAgent()", "initSwarm()"
- **Pattern:** "orchestration", "state persistence", "fallback chain"
- **Error:** "ParseError", "IndexCorruptedError", "VectorStoreError"

**Extraction Methods:**

#### Method 1: Title/Heading Analysis

```typescript
interface ConceptEntity {
  name: string;                  // Canonical name
  type: ConceptType;             // feature|config|api|pattern|error
  frequency: number;             // Mention count
  firstMention: string;          // Document ID where first seen
  variants: string[];            // Alternative spellings
  documentFrequency: number;     // Number of docs mentioning it
}

function extractConceptsFromHeadings(sections: SectionEntity[]): ConceptEntity[] {
  const conceptMap = new Map<string, ConceptEntity>();

  for (const section of sections) {
    // Split heading into words, filter stop words
    const terms = section.heading
      .toLowerCase()
      .split(/\W+/)
      .filter(word => word.length > 3 && !STOP_WORDS.has(word));

    for (const term of terms) {
      if (!conceptMap.has(term)) {
        conceptMap.set(term, {
          name: term,
          type: inferConceptType(term, section.content),
          frequency: 1,
          firstMention: section.documentId,
          variants: [term],
          documentFrequency: 1
        });
      } else {
        const concept = conceptMap.get(term)!;
        concept.frequency += 1;
      }
    }
  }

  return Array.from(conceptMap.values());
}

function inferConceptType(term: string, context: string): ConceptType {
  // Pattern-based classification
  if (term.includes('error') || term.includes('exception')) return 'error';
  if (term.match(/[A-Z_]+/)) return 'config';  // ALL_CAPS
  if (term.includes('()')) return 'api';       // function-like
  if (context.toLowerCase().includes('pattern')) return 'pattern';
  return 'feature';
}
```

#### Method 2: Code Block Analysis

```typescript
function extractConceptsFromCode(doc: MdDocument): ConceptEntity[] {
  const concepts: ConceptEntity[] = [];

  for (const block of doc.codeBlocks) {
    if (block.language === 'typescript' || block.language === 'javascript') {
      // Extract function names
      const functions = block.content.match(/function\s+(\w+)/g);
      const classes = block.content.match(/class\s+(\w+)/g);
      const consts = block.content.match(/const\s+(\w+)/g);

      // Add as API concepts
      [functions, classes, consts].forEach(matches => {
        matches?.forEach(match => {
          const name = match.split(/\s+/)[1];
          concepts.push({
            name: name,
            type: 'api',
            frequency: 1,
            firstMention: doc.id,
            variants: [name],
            documentFrequency: 1
          });
        });
      });
    }
  }

  return concepts;
}
```

#### Method 3: TF-IDF Keyword Extraction

```typescript
import { stemmer } from 'stemmer';

interface TfIdfResult {
  term: string;
  score: number;
}

function extractKeywordsTfIdf(
  sections: SectionEntity[],
  topN: number = 10
): Map<string, TfIdfResult[]> {
  // Build document frequency map
  const df = new Map<string, number>();
  const totalDocs = sections.length;

  for (const section of sections) {
    const terms = new Set(
      section.plainText
        .toLowerCase()
        .split(/\W+/)
        .filter(w => w.length > 3)
        .map(w => stemmer(w))
    );

    terms.forEach(term => {
      df.set(term, (df.get(term) || 0) + 1);
    });
  }

  // Compute TF-IDF for each section
  const results = new Map<string, TfIdfResult[]>();

  for (const section of sections) {
    const terms = section.plainText
      .toLowerCase()
      .split(/\W+/)
      .filter(w => w.length > 3)
      .map(w => stemmer(w));

    const tf = new Map<string, number>();
    terms.forEach(t => tf.set(t, (tf.get(t) || 0) + 1));

    const tfidf: TfIdfResult[] = [];
    for (const [term, termFreq] of tf) {
      const docFreq = df.get(term) || 1;
      const idf = Math.log(totalDocs / docFreq);
      tfidf.push({ term, score: termFreq * idf });
    }

    // Sort by score, take top N
    tfidf.sort((a, b) => b.score - a.score);
    results.set(section.id, tfidf.slice(0, topN));
  }

  return results;
}
```

**Using mdcontext's BM25 Index:**

mdcontext already has BM25 built-in. Leverage it:

```typescript
import { createBM25Store } from 'mdcontext/search';

async function extractKeywordsBM25(
  rootPath: string
): Promise<Map<string, string[]>> {
  const store = createBM25Store(rootPath);
  await store.load();

  // BM25 store contains tokenized content
  // We can extract high-scoring terms per section
  const keywords = new Map<string, string[]>();

  // Note: BM25 store doesn't expose internal term frequencies directly
  // Alternative: Use the keyword extraction from plainText (TF-IDF above)
  // or parse the stored BM25 JSON structure

  return keywords;
}
```

### 2.4 Keyword Extraction (Simplified)

For rapid prototyping, use a simpler keyword extractor:

```typescript
const STOP_WORDS = new Set([
  'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for',
  'of', 'with', 'by', 'from', 'about', 'into', 'through', 'during',
  'this', 'that', 'these', 'those', 'is', 'are', 'was', 'were', 'be',
  'been', 'being', 'have', 'has', 'had', 'do', 'does', 'did', 'will',
  'would', 'should', 'could', 'may', 'might', 'can'
]);

function extractKeywords(text: string, topN: number = 10): string[] {
  // Simple frequency-based extraction
  const words = text
    .toLowerCase()
    .split(/\W+/)
    .filter(w => w.length > 3 && !STOP_WORDS.has(w));

  const freq = new Map<string, number>();
  words.forEach(w => freq.set(w, (freq.get(w) || 0) + 1));

  return Array.from(freq.entries())
    .sort((a, b) => b[1] - a[1])
    .slice(0, topN)
    .map(([word]) => word);
}
```

---

## 3. Relationship Discovery

### 3.1 Explicit Links (LINKS_TO)

**Source:** `links.json`
**Edge Type:** `LINKS_TO`
**Properties:**

```typescript
interface LinkEdge {
  from: string;           // Source document ID
  to: string;             // Target document ID
  linkType: 'explicit';   // Markdown link
  weight: number;         // Always 1.0 for explicit links
  context?: string;       // Surrounding text (optional)
}

function extractExplicitLinks(linksIndex: LinkIndex): LinkEdge[] {
  const edges: LinkEdge[] = [];

  for (const [sourcePath, targets] of Object.entries(linksIndex.forward)) {
    const sourceDoc = findDocumentByPath(sourcePath);

    for (const targetPath of targets) {
      const targetDoc = findDocumentByPath(targetPath);

      edges.push({
        from: sourceDoc.id,
        to: targetDoc.id,
        linkType: 'explicit',
        weight: 1.0
      });
    }
  }

  return edges;
}
```

### 3.2 Semantic Similarity (SIMILAR_TO)

**Source:** HNSW embeddings
**Edge Type:** `SIMILAR_TO`
**Threshold:** 0.65+ cosine similarity

```typescript
interface SimilarityEdge {
  from: string;              // Section ID
  to: string;                // Section ID
  cosineSimilarity: number;  // 0.65-1.0
  sharedConcepts: string[];  // Overlapping keywords
}

async function extractSimilarityEdges(
  sections: SectionEntity[],
  vectorStore: VectorStore,
  threshold: number = 0.65
): Promise<SimilarityEdge[]> {
  const edges: SimilarityEdge[] = [];

  for (const section of sections) {
    // Load embedding for this section
    const embedding = await vectorStore.getEmbedding(section.id);
    if (!embedding) continue;

    // Find similar sections
    const similar = await vectorStore.search(
      embedding,
      limit: 20,
      threshold: threshold
    );

    for (const result of similar) {
      if (result.sectionId === section.id) continue; // Skip self

      const targetSection = sections.find(s => s.id === result.sectionId);
      if (!targetSection) continue;

      // Find shared concepts
      const sharedConcepts = section.keywords.filter(k =>
        targetSection.keywords.includes(k)
      );

      edges.push({
        from: section.id,
        to: result.sectionId,
        cosineSimilarity: result.similarity,
        sharedConcepts: sharedConcepts
      });
    }
  }

  return edges;
}
```

### 3.3 Concept Co-occurrence (MENTIONS / RELATED_TO)

**Goal:** Find concepts that appear together frequently.

```typescript
interface ConceptCooccurrence {
  concept1: string;
  concept2: string;
  cooccurrenceCount: number;
  pmi: number;  // Pointwise Mutual Information
}

function extractConceptCooccurrence(
  sections: SectionEntity[],
  concepts: ConceptEntity[]
): ConceptCooccurrence[] {
  const cooccurrences = new Map<string, number>();
  const conceptCounts = new Map<string, number>();

  // Count co-occurrences
  for (const section of sections) {
    const sectionConcepts = new Set(section.keywords);

    // Count individual concepts
    sectionConcepts.forEach(c => {
      conceptCounts.set(c, (conceptCounts.get(c) || 0) + 1);
    });

    // Count pairs
    const conceptList = Array.from(sectionConcepts);
    for (let i = 0; i < conceptList.length; i++) {
      for (let j = i + 1; j < conceptList.length; j++) {
        const key = [conceptList[i], conceptList[j]].sort().join('::');
        cooccurrences.set(key, (cooccurrences.get(key) || 0) + 1);
      }
    }
  }

  // Compute PMI (Pointwise Mutual Information)
  const totalSections = sections.length;
  const results: ConceptCooccurrence[] = [];

  for (const [key, count] of cooccurrences) {
    const [c1, c2] = key.split('::');
    const p_c1 = (conceptCounts.get(c1) || 0) / totalSections;
    const p_c2 = (conceptCounts.get(c2) || 0) / totalSections;
    const p_c1_c2 = count / totalSections;

    const pmi = Math.log(p_c1_c2 / (p_c1 * p_c2));

    results.push({
      concept1: c1,
      concept2: c2,
      cooccurrenceCount: count,
      pmi: pmi
    });
  }

  // Filter by PMI > 0 (positive association)
  return results.filter(r => r.pmi > 0).sort((a, b) => b.pmi - a.pmi);
}
```

### 3.4 Section-to-Concept Relationships (MENTIONS)

```typescript
interface MentionsEdge {
  sectionId: string;
  conceptName: string;
  mentionCount: number;
  tfidfScore: number;
  positions: number[];  // Character offsets
}

function extractMentions(
  sections: SectionEntity[],
  concepts: ConceptEntity[]
): MentionsEdge[] {
  const edges: MentionsEdge[] = [];
  const conceptNames = new Set(concepts.map(c => c.name));

  for (const section of sections) {
    const text = section.plainText.toLowerCase();

    for (const conceptName of conceptNames) {
      const regex = new RegExp(`\\b${conceptName}\\b`, 'gi');
      const matches = Array.from(text.matchAll(regex));

      if (matches.length > 0) {
        edges.push({
          sectionId: section.id,
          conceptName: conceptName,
          mentionCount: matches.length,
          tfidfScore: 0, // Compute separately if needed
          positions: matches.map(m => m.index!)
        });
      }
    }
  }

  return edges;
}
```

---

## 4. Processing Pipeline

### 4.1 Step-by-Step Flow

```
┌─────────────────────────────────────────────────────────────┐
│ Phase 1: Index Loading                                      │
├─────────────────────────────────────────────────────────────┤
│ 1. Load documents.json → DocumentEntity[]                   │
│ 2. Load sections.json → SectionEntity[]                     │
│ 3. Load links.json → LinkEdge[]                             │
│ 4. Load vectors.bin (optional) → VectorStore                │
│ 5. Load bm25.json (optional) → BM25Store                    │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Phase 2: Content Extraction                                 │
├─────────────────────────────────────────────────────────────┤
│ 1. Read markdown files for sections                         │
│ 2. Extract plainText from content                           │
│ 3. Extract keywords via TF-IDF                              │
│ 4. Parse code blocks for API concepts                       │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Phase 3: Concept Extraction                                 │
├─────────────────────────────────────────────────────────────┤
│ 1. Extract from headings → ConceptEntity[]                  │
│ 2. Extract from code blocks → API concepts                  │
│ 3. Compute TF-IDF keywords → Concept candidates             │
│ 4. Classify concepts by type (feature/api/config/etc)       │
│ 5. Deduplicate and normalize names                          │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Phase 4: Relationship Discovery                             │
├─────────────────────────────────────────────────────────────┤
│ 1. Explicit links (from links.json)                         │
│ 2. Semantic similarity (from embeddings)                    │
│ 3. Concept co-occurrence (from section content)             │
│ 4. Section-concept mentions (text matching)                 │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Phase 5: Graph Construction                                 │
├─────────────────────────────────────────────────────────────┤
│ 1. Create nodes (documents, sections, concepts)             │
│ 2. Create edges (links, similarity, mentions)               │
│ 3. Compute graph metrics (PageRank, centrality)             │
│ 4. Detect communities (topic clusters)                      │
│ 5. Export to graph format (see 05-validation.md)            │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 Parallelization Strategy

**Goal:** Process 2066 files efficiently.

**Parallelizable Operations:**

1. **File Reading** (I/O bound)
   - Use `Promise.all()` with concurrency limit
   - Read sections from same document together

2. **Concept Extraction** (CPU bound)
   - Process each section independently
   - Use worker threads for large corpora

3. **Embedding Similarity** (I/O + CPU)
   - Query vector store in batches
   - Cache results to avoid duplicate queries

**Concurrency Control:**

```typescript
async function processInBatches<T, R>(
  items: T[],
  batchSize: number,
  processor: (item: T) => Promise<R>
): Promise<R[]> {
  const results: R[] = [];

  for (let i = 0; i < items.length; i += batchSize) {
    const batch = items.slice(i, i + batchSize);
    const batchResults = await Promise.all(batch.map(processor));
    results.push(...batchResults);

    // Progress reporting
    console.log(`Processed ${i + batchSize}/${items.length}`);
  }

  return results;
}

// Example: Process sections in batches of 50
const sections = await processInBatches(
  sectionList,
  50,
  async (section) => extractSection(section)
);
```

### 4.3 Error Handling

**Common Errors:**

1. **Malformed Markdown**
   - Parser fails on unusual syntax
   - **Solution:** Wrap in try/catch, log warning, skip file

2. **Missing Files**
   - Index references file that was deleted
   - **Solution:** Check file existence before reading

3. **Embedding Dimension Mismatch**
   - Index built with 384-dim vectors, current provider is 1536-dim
   - **Solution:** Rebuild embeddings or skip semantic similarity

4. **Memory Exhaustion**
   - Loading all 2066 files into memory at once
   - **Solution:** Stream processing, batch by batch

**Error Handler Template:**

```typescript
class ExtractionError extends Error {
  constructor(
    public phase: string,
    public filePath: string,
    public originalError: Error
  ) {
    super(`[${phase}] Failed to process ${filePath}: ${originalError.message}`);
  }
}

async function safeExtractSection(
  section: SectionEntry,
  rootPath: string
): Promise<SectionEntity | null> {
  try {
    const filePath = path.join(rootPath, section.documentPath);
    const content = await fs.readFile(filePath, 'utf-8');
    // ... extraction logic
    return sectionEntity;
  } catch (error) {
    console.error(
      new ExtractionError(
        'section-extraction',
        section.documentPath,
        error as Error
      )
    );
    return null; // Skip this section
  }
}

// Filter nulls after processing
const sections = (await Promise.all(
  sectionList.map(s => safeExtractSection(s, rootPath))
)).filter(s => s !== null);
```

---

## 5. Output Format

### 5.1 Intermediate Representation (JSON)

Export extracted entities and relationships to JSON for graph construction:

```json
{
  "metadata": {
    "extractedAt": "2026-01-26T21:30:00Z",
    "rootPath": "/path/to/docs",
    "documentCount": 10,
    "sectionCount": 280,
    "conceptCount": 450,
    "linkCount": 125
  },
  "documents": [
    {
      "id": "abc123",
      "path": "01-core-architecture.md",
      "title": "Core Architecture",
      "tokenCount": 5234,
      "sectionCount": 28,
      "category": "Architecture"
    }
  ],
  "sections": [
    {
      "id": "abc123-intro",
      "documentId": "abc123",
      "heading": "Introduction",
      "level": 2,
      "tokenCount": 150,
      "keywords": ["architecture", "overview", "system"]
    }
  ],
  "concepts": [
    {
      "name": "agent loading",
      "type": "feature",
      "frequency": 12,
      "documentFrequency": 4
    }
  ],
  "edges": {
    "links": [
      { "from": "abc123", "to": "def456", "type": "explicit", "weight": 1.0 }
    ],
    "similarity": [
      { "from": "abc123-intro", "to": "def456-overview", "similarity": 0.78 }
    ],
    "mentions": [
      { "sectionId": "abc123-intro", "concept": "agent loading", "count": 3 }
    ]
  }
}
```

### 5.2 Graph Format (GraphML/JSON)

For Neo4j or other graph databases:

```json
{
  "nodes": [
    {
      "id": "doc:abc123",
      "labels": ["Document"],
      "properties": {
        "path": "01-core-architecture.md",
        "title": "Core Architecture",
        "tokenCount": 5234
      }
    },
    {
      "id": "section:abc123-intro",
      "labels": ["Section"],
      "properties": {
        "heading": "Introduction",
        "level": 2
      }
    },
    {
      "id": "concept:agent-loading",
      "labels": ["Concept"],
      "properties": {
        "name": "agent loading",
        "type": "feature"
      }
    }
  ],
  "relationships": [
    {
      "type": "CONTAINS",
      "startNode": "doc:abc123",
      "endNode": "section:abc123-intro",
      "properties": { "order": 1 }
    },
    {
      "type": "MENTIONS",
      "startNode": "section:abc123-intro",
      "endNode": "concept:agent-loading",
      "properties": { "count": 3 }
    }
  ]
}
```

### 5.3 CSV Format (for bulk imports)

**nodes_documents.csv:**
```csv
id,path,title,tokenCount,category
abc123,"01-core-architecture.md","Core Architecture",5234,"Architecture"
```

**nodes_concepts.csv:**
```csv
name,type,frequency,documentFrequency
"agent loading","feature",12,4
```

**edges_links.csv:**
```csv
from,to,type,weight
abc123,def456,explicit,1.0
```

---

## 6. Code Examples

### 6.1 Complete Extraction Pipeline

```typescript
import { Effect } from 'effect';
import { createStorage, loadDocumentIndex, loadSectionIndex, loadLinkIndex } from 'mdcontext/index';
import { createVectorStore } from 'mdcontext/embeddings';
import * as fs from 'node:fs/promises';
import * as path from 'node:path';

interface ExtractionResult {
  documents: DocumentEntity[];
  sections: SectionEntity[];
  concepts: ConceptEntity[];
  edges: {
    links: LinkEdge[];
    similarity: SimilarityEdge[];
    mentions: MentionsEdge[];
  };
}

async function extractKnowledgeGraph(
  rootPath: string
): Promise<ExtractionResult> {
  console.log('Loading indexes...');
  const storage = createStorage(rootPath);

  // Phase 1: Load indexes
  const docIndex = await Effect.runPromise(loadDocumentIndex(storage));
  const sectionIndex = await Effect.runPromise(loadSectionIndex(storage));
  const linkIndex = await Effect.runPromise(loadLinkIndex(storage));

  if (!docIndex || !sectionIndex || !linkIndex) {
    throw new Error('Indexes not found. Run `mdcontext index` first.');
  }

  console.log(`Loaded ${Object.keys(docIndex.documents).length} documents`);

  // Phase 2: Extract documents
  const documents = extractDocuments(docIndex);

  // Phase 3: Extract sections with content
  console.log('Extracting sections...');
  const sections = await extractSections(sectionIndex, rootPath);
  console.log(`Extracted ${sections.length} sections`);

  // Phase 4: Extract concepts
  console.log('Extracting concepts...');
  const headingConcepts = extractConceptsFromHeadings(sections);
  const codeConcepts = await extractConceptsFromCode(rootPath, docIndex);
  const concepts = deduplicateConcepts([...headingConcepts, ...codeConcepts]);
  console.log(`Extracted ${concepts.length} unique concepts`);

  // Phase 5: Extract relationships
  console.log('Discovering relationships...');
  const linkEdges = extractExplicitLinks(linkIndex, docIndex);

  // Semantic similarity (optional, requires embeddings)
  let similarityEdges: SimilarityEdge[] = [];
  try {
    const vectorStore = createVectorStore(rootPath, 384);
    await Effect.runPromise(vectorStore.load());
    similarityEdges = await extractSimilarityEdges(sections, vectorStore);
    console.log(`Found ${similarityEdges.length} similarity edges`);
  } catch (error) {
    console.warn('Skipping semantic similarity (no embeddings)');
  }

  const mentionEdges = extractMentions(sections, concepts);
  console.log(`Found ${mentionEdges.length} concept mentions`);

  return {
    documents,
    sections,
    concepts,
    edges: {
      links: linkEdges,
      similarity: similarityEdges,
      mentions: mentionEdges
    }
  };
}

function deduplicateConcepts(concepts: ConceptEntity[]): ConceptEntity[] {
  const map = new Map<string, ConceptEntity>();

  for (const concept of concepts) {
    const key = concept.name.toLowerCase();
    if (!map.has(key)) {
      map.set(key, concept);
    } else {
      const existing = map.get(key)!;
      existing.frequency += concept.frequency;
      existing.variants.push(...concept.variants);
    }
  }

  return Array.from(map.values());
}

// Run extraction
const result = await extractKnowledgeGraph('/path/to/docs');
console.log('Extraction complete!');
console.log(`- ${result.documents.length} documents`);
console.log(`- ${result.sections.length} sections`);
console.log(`- ${result.concepts.length} concepts`);
console.log(`- ${result.edges.links.length} explicit links`);
console.log(`- ${result.edges.similarity.length} similarity edges`);
console.log(`- ${result.edges.mentions.length} mention edges`);

// Save to JSON
await fs.writeFile(
  'knowledge-graph-data.json',
  JSON.stringify(result, null, 2)
);
console.log('Saved to knowledge-graph-data.json');
```

### 6.2 Single File Processing Example

```typescript
import { parseFile } from 'mdcontext/parser';
import { Effect } from 'effect';

// Parse a single markdown file
const filePath = '/path/to/docs/01-core-architecture.md';
const doc = await Effect.runPromise(parseFile(filePath));

console.log('Document:', doc.title);
console.log('Sections:', doc.sections.length);

// Extract concepts from this document
doc.sections.forEach(section => {
  console.log(`\n[${section.heading}]`);
  const keywords = extractKeywords(section.plainText, 5);
  console.log('Keywords:', keywords.join(', '));

  // Find code blocks in this section
  const sectionCode = doc.codeBlocks.filter(
    cb => cb.sectionId === section.id
  );
  if (sectionCode.length > 0) {
    console.log(`Code blocks: ${sectionCode.length}`);
  }
});

// Extract links
console.log('\nLinks:');
doc.links.forEach(link => {
  if (link.type === 'internal') {
    console.log(`  → ${link.href} (${link.text})`);
  }
});
```

---

## 7. Validation Checks

**Pre-flight Checks:**

```typescript
async function validateIndexes(rootPath: string): Promise<boolean> {
  const storage = createStorage(rootPath);
  const indexDir = path.join(rootPath, '.mdcontext', 'indexes');

  // Check if indexes exist
  const requiredFiles = [
    'documents.json',
    'sections.json',
    'links.json'
  ];

  for (const file of requiredFiles) {
    const filePath = path.join(indexDir, file);
    try {
      await fs.access(filePath);
    } catch {
      console.error(`Missing index file: ${file}`);
      console.error('Run: mdcontext index --force');
      return false;
    }
  }

  // Load and validate structure
  const docIndex = await Effect.runPromise(loadDocumentIndex(storage));
  if (!docIndex || Object.keys(docIndex.documents).length === 0) {
    console.error('Document index is empty or corrupted');
    return false;
  }

  console.log('✓ Indexes validated');
  return true;
}
```

**Post-extraction Validation:**

```typescript
function validateExtraction(result: ExtractionResult): string[] {
  const errors: string[] = [];

  // Check for empty results
  if (result.documents.length === 0) {
    errors.push('No documents extracted');
  }
  if (result.sections.length === 0) {
    errors.push('No sections extracted');
  }

  // Check section-document mapping
  const docIds = new Set(result.documents.map(d => d.id));
  for (const section of result.sections) {
    if (!docIds.has(section.documentId)) {
      errors.push(`Section ${section.id} references non-existent document ${section.documentId}`);
    }
  }

  // Check concept mentions reference valid concepts
  const conceptNames = new Set(result.concepts.map(c => c.name));
  for (const mention of result.edges.mentions) {
    if (!conceptNames.has(mention.conceptName)) {
      errors.push(`Mention references unknown concept: ${mention.conceptName}`);
    }
  }

  return errors;
}
```

---

## 8. Performance Benchmarks

**Expected Performance (on MacBook Pro M1, 2066 files):**

| Operation | Time | Notes |
|-----------|------|-------|
| Load indexes | <1s | JSON parsing |
| Extract sections | 5-10s | File I/O dominant |
| Extract concepts (headings) | 1-2s | In-memory processing |
| Extract concepts (TF-IDF) | 10-15s | CPU-bound |
| Compute similarity edges | 30-60s | Vector search (if enabled) |
| Extract mentions | 20-30s | Regex matching |
| **Total** | **~2 minutes** | Without embeddings: ~45s |

**Optimization Tips:**

1. **Cache section content:** Read each file once, cache content by section ID
2. **Batch vector queries:** Query 100 sections at once instead of 1 by 1
3. **Use BM25 for keyword extraction:** Faster than TF-IDF from scratch
4. **Skip similarity edges initially:** Start with explicit links only

---

## 9. Next Steps

After extraction completes, proceed to:

1. **Graph Construction** (`03-graph-building.md`)
   - Import entities/edges into Neo4j or networkx
   - Compute graph metrics (PageRank, centrality)
   - Detect communities (topic clusters)

2. **Query Interface** (`04-query-interface.md`)
   - Cypher query examples
   - GraphQL API design
   - Natural language query translation

3. **Validation** (`05-validation.md`)
   - Query correctness tests
   - Coverage analysis (are all documents reachable?)
   - Graph quality metrics (connectedness, modularity)

---

## 10. Real Example: agentic-flow Docs

**Sample Run on 10 agentic-flow markdown files:**

```bash
cd /Users/alphab/Dev/LLM/DEV/TMP/nancy/research/agentic-flow
mdcontext index --embed

# Wait for indexing...
# Now run extraction:

node extract-knowledge-graph.js
```

**Expected Output:**

```
Loading indexes...
Loaded 10 documents
Extracting sections...
Extracted 280 sections
Extracting concepts...
Extracted 450 unique concepts
Discovering relationships...
Found 35 explicit links
Found 1200 similarity edges (threshold: 0.65)
Found 3500 concept mentions

Extraction complete!
- 10 documents
- 280 sections
- 450 concepts
- 35 explicit links
- 1200 similarity edges
- 3500 mention edges

Saved to knowledge-graph-data.json
```

**Sample Concepts Extracted:**

- **Features:** "agent loading", "orchestration", "memory system", "swarm coordination"
- **APIs:** "loadAgent()", "initSwarm()", "query()", "claudeAgent()"
- **Config:** "API_KEY", "CLAUDE_MODEL", "max_tokens", "temperature"
- **Patterns:** "fallback chain", "proxy routing", "state persistence"
- **Errors:** "ParseError", "IndexCorruptedError", "VectorStoreError"

**Sample Relationships:**

- `01-core-architecture.md` → `02-agent-system-design.md` (explicit link)
- Section "Agent Loading" ↔ Section "Agent Manager" (similarity: 0.78)
- Section "Architecture Overview" mentions "orchestration" (3 times)
- Concept "agent loading" related to "claudeAgent" (PMI: 2.4)

---

## Appendix: Dependencies

**Required npm packages:**

```json
{
  "dependencies": {
    "mdcontext": "^0.1.0",
    "effect": "^3.19.15",
    "stemmer": "^2.0.1"
  },
  "devDependencies": {
    "@types/node": "^25.0.10",
    "typescript": "^5.9.3"
  }
}
```

**Optional (for enhanced extraction):**

```bash
# Natural language processing
npm install natural compromise

# Advanced keyword extraction
npm install keyword-extractor rake-js

# Graph algorithms
npm install graphlib networkx-js
```

---

## Conclusion

This extraction pipeline transforms mdcontext's structural indexes into rich entity-relationship data suitable for knowledge graph construction. By leveraging mdcontext's existing capabilities (parsing, indexing, embeddings, link analysis) and adding concept extraction and relationship discovery, we create a comprehensive data foundation for the validation harness.

**Key Takeaways:**

1. **mdcontext does most of the heavy lifting** - Use its indexes directly
2. **Concept extraction is the value-add** - Focus effort here
3. **Parallelization matters at scale** - Batch operations for 2066 files
4. **Validation is critical** - Check data quality at every step

**Next Document:** `03-graph-building.md` - Constructing and querying the knowledge graph.
