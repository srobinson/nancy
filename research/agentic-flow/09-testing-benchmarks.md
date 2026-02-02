# Agentic-Flow Testing & Benchmarks Deep Dive

**Analysis Date**: 2026-01-22
**Source**: `/Users/alphab/Dev/LLM/DEV/agentic-flow`
**Version**: 2.0.1-alpha

---

## Executive Summary

Agentic-Flow has a comprehensive testing and benchmarking infrastructure that validates performance claims for its AI agent orchestration platform. The architecture includes:

- **Jest + ts-jest** for TypeScript unit/integration testing
- **Vitest** for QUIC transport tests
- **Custom benchmark framework** with high-precision timers
- **GNN (Graph Neural Network) performance tests** via `@ruvector/gnn`
- **Swarm coordination E2B tests** achieving 100% pass rate
- **Performance targets** with regression detection

---

## 1. Testing Architecture

### 1.1 Test Framework Configuration

**Primary Jest Config** (`/jest.config.js`):
```javascript
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/tests', '<rootDir>/src'],
  testMatch: ['**/__tests__/**/*.ts', '**/?(*.)+(spec|test).ts'],
  coverageThreshold: {
    global: {
      branches: 90,
      functions: 90,
      lines: 90,
      statements: 90,
    },
  },
  testTimeout: 10000,
};
```

**Secondary Config** (`/config/jest.config.js`):
- Targets 80% coverage thresholds
- Separate path mappings for `@/` imports
- Excludes CLI and benchmark files from coverage

**Vitest Config** (for QUIC tests):
- Uses separate `vitest.config.ts`
- Mocks console methods to reduce noise
- Sets QUIC environment variables

### 1.2 Test Directory Structure

```
tests/
├── archived/              # Historical test files (GNN tests)
├── docker/               # Docker-based test environments
├── e2b/                  # E2B cloud sandbox tests
├── e2b-sandbox/          # Swarm coordination tests
├── e2b-specialized-agents/ # Agent type tests
├── e2e/                  # End-to-end workflow tests
├── hooks/                # Git/lifecycle hook tests
├── integration/          # Integration tests
│   └── core/             # AgentDB wrapper tests
├── mocks/                # Mock implementations
├── parallel/             # Parallel execution benchmarks
├── safety/               # Safety validation
├── security/             # Security tests
├── sona/                 # Sona package tests
├── transport/            # QUIC transport unit tests
├── unit/                 # Unit tests
│   └── core/             # Core module tests
├── validation/           # Quick validation tests
└── verification/         # Verification scripts
```

### 1.3 Test Utilities

**Test Helper** (`/tests/test-helper.ts`):
- Common test utilities
- Mock agent creation
- Assertion helpers

**Test Setup** (`/tests/setup.ts`):
```typescript
beforeAll(() => {
  process.env.NODE_ENV = 'test';
  process.env.QUIC_SERVER = 'localhost:8443';
  process.env.QUIC_0RTT = 'true';
  process.env.QUIC_MAX_STREAMS = '1000';
  process.env.QUIC_FALLBACK = 'true';
});
```

---

## 2. Benchmark Methodology

### 2.1 Benchmark Framework

**Custom High-Precision Timer** (`/benchmarks/utils/benchmark.ts`):

```typescript
interface BenchmarkOptions {
  iterations?: number;    // Default: 1000
  warmup?: number;        // Default: 100
  name?: string;
  silent?: boolean;
  minSamples?: number;    // Default: 5
  maxTime?: number;       // Default: 30000ms
}

interface BenchmarkResult {
  name: string;
  iterations: number;
  samples: number[];
  mean: number;
  median: number;
  p50: number;    // 50th percentile
  p75: number;    // 75th percentile
  p90: number;    // 90th percentile
  p95: number;    // 95th percentile
  p99: number;    // 99th percentile
  p999: number;   // 99.9th percentile
  min: number;
  max: number;
  stdDev: number;
  opsPerSecond: number;
  totalTime: number;
}
```

**Key Features**:
- Uses `performance.now()` for high-precision timing
- Configurable warmup phase to eliminate JIT effects
- Statistical analysis with percentile calculations
- Regression detection against baseline results
- Automatic result saving to JSON

### 2.2 Performance Targets

| Metric | v1.0 Baseline | v2.0 Target | Improvement |
|--------|---------------|-------------|-------------|
| Vector search (1M) | ~1500ms P50 | <10ms P50 | 150x faster |
| Agent spawn | ~100ms P50 | <10ms P50 | 10x faster |
| Memory insert | ~250ms P50 | <2ms P50 | 125x faster |
| Task orchestration | ~250ms P50 | <50ms P50 | 5x faster |
| Attention (512 tokens) | N/A | <20ms P50 | New feature |
| GNN forward pass | N/A | <50ms P50 | New feature |

### 2.3 Benchmark Suite Organization

```
benchmarks/
├── src/
│   ├── vector-search.bench.ts      # Vector search benchmarks
│   ├── agent-operations.bench.ts   # Agent lifecycle benchmarks
│   ├── memory-operations.bench.ts  # Memory store benchmarks
│   ├── task-orchestration.bench.ts # Task scheduling benchmarks
│   ├── attention.bench.ts          # Attention mechanism benchmarks
│   ├── gnn.bench.ts               # GNN forward pass benchmarks
│   └── regression.bench.ts        # Regression detection
├── utils/
│   ├── benchmark.ts               # Core benchmark runner
│   └── report-generator.ts        # HTML report generator
├── data/
│   └── baseline-v1.0.json         # Baseline results
├── attention-gnn-benchmark.js     # Combined attention/GNN benchmark
└── run-all.ts                     # Suite runner
```

### 2.4 NPM Scripts for Benchmarks

```json
{
  "bench:quic": "node benchmarks/quic-transport.bench.js",
  "bench:report": "node scripts/generate-benchmark-report.js",
  "bench:parallel": "BENCHMARK_MODE=true ITERATIONS=10 node tests/parallel/benchmark-suite.js",
  "bench:attention": "node benchmarks/attention-gnn-benchmark.js",
  "bench:sona": "npx tsx tests/sona/sona-performance.bench.ts",
  "bench:sona:gc": "node --expose-gc --loader tsx tests/sona/benchmark-runner.ts --gc"
}
```

---

## 3. GNN Tests Analysis

### 3.1 GNN Test Files

The project includes four key GNN test files at the root level:

1. **`test-gnn-performance.cjs`** - Core performance validation
2. **`test-gnn-float32-performance.cjs`** - Float32Array-specific tests
3. **`test-gnn-remaining-functions.cjs`** - Function coverage tests
4. **`test-gnn-typed-arrays.cjs`** - Array type compatibility tests

### 3.2 GNN Package: `@ruvector/gnn`

**Key Functions Tested**:
- `differentiableSearch(query, candidates, k, temperature)` - Core differentiable search
- `hierarchicalForward(input, weights, inputDim, outputDim)` - Hierarchical layer forward pass
- `RuvectorLayer` - Neural network layer constructor
- `TensorCompress` - Tensor compression (half, pq8, pq4, binary)
- `getCompressionLevel(level)` - Compression configuration

### 3.3 GNN Performance Test Structure

```javascript
// test-gnn-performance.cjs
async function testGNN() {
  const dimensions = 128;
  const numVectors = 1000;
  const k = 10;

  // Test 1: Single query
  const result1 = gnn.differentiableSearch(query, candidates, k, 0.5);

  // Test 2: Batch queries (10 queries)
  for (let i = 0; i < 10; i++) {
    gnn.differentiableSearch(query, candidates, k, 0.5);
  }

  // Test 3: Brute force comparison
  // Cosine similarity baseline

  // Test 4: Larger dataset (10K vectors)
  // Stress test
}
```

### 3.4 GNN Benchmark Results Structure

The GNN benchmarks measure:
- **Speedup vs brute force**: Target is 125x
- **Latency**: P50 target <50ms
- **Throughput**: queries/second
- **Per-vector overhead**: ms per vector

**Critical Finding**:
```javascript
// GNN REQUIRES Float32Array (regular arrays fail)
// API documentation shows regular arrays but they don't work
// This is an alpha package with Rust/NAPI bindings in development
```

### 3.5 GNN in Benchmarks Suite

**`/benchmarks/src/gnn.bench.ts`**:

```typescript
class GNNLayer {
  async forward(graph: Graph): Promise<number[][]> {
    const aggregated = await this.aggregate(graph);
    return await this.transform(aggregated);
  }
}

class GNN {
  async forward(graph: Graph): Promise<number[][]> {
    // Multi-layer forward pass with message passing
  }
}

// Benchmark functions:
// - runGNNForwardPassBenchmark() - Target: <50ms P50
// - runVariableGraphSizeBenchmark() - 100 to 10K nodes
// - runVariableDepthBenchmark() - 1 to 4 layers
// - runGraphTopologyBenchmark() - Random, scale-free graphs
// - runBatchGraphBenchmark() - 1 to 16 batch size
```

---

## 4. Attention Mechanism Benchmarks

### 4.1 Attention Types Tested

| Mechanism | Target P50 | Description |
|-----------|------------|-------------|
| Flash Attention | <5ms | Memory-efficient, O(N) complexity |
| Multi-Head | <20ms | Standard transformer attention |
| Linear | <20ms | O(N) approximation |
| Hyperbolic | <10ms | Poincare ball distance-based |
| MoE (Mixture of Experts) | <25ms | Sparse expert routing |

### 4.2 Attention Benchmark Structure

**`/benchmarks/src/attention.bench.ts`**:

```typescript
class AttentionMechanism {
  async computeAttention(query, key, value): Promise<number[][]> {
    // Q * K^T / sqrt(d_k)
    // Softmax
    // Weighted sum: attention_weights * V
  }
}

// Test functions:
// - runAttentionBenchmark() - 512 tokens, <20ms P50
// - runVariableSequenceBenchmark() - 64 to 1024 tokens
// - runMultiHeadBenchmark() - 1 to 16 heads
// - runBatchAttentionBenchmark() - 1 to 32 batch size
// - runHyperbolicAttentionBenchmark() - Standard vs hyperbolic comparison
```

### 4.3 Combined Attention-GNN Benchmark

**`/benchmarks/attention-gnn-benchmark.js`**:

Validates:
- Flash Attention: 4x speedup target (or 1.5x for WASM)
- Memory reduction: 75% target
- GNN recall improvement: +12.4% target
- Multi-agent coordination performance

---

## 5. Swarm Coordination Tests

### 5.1 E2B Sandbox Results

**Summary** (from `/benchmark-results/SWARM_COORDINATION_SUMMARY.md`):

| Metric | Result |
|--------|--------|
| Total Tests | 44 |
| Pass Rate | 100% |
| Coordinators Tested | 3 (Hierarchical, Mesh, Adaptive) |
| Integration Tests | 12 |
| Performance Benchmarks | 8 |

### 5.2 Coordination Performance

| Coordinator | Speed | Key Strength |
|-------------|-------|--------------|
| Hierarchical | 0.21ms | 476x better than 100ms target |
| Mesh | 1.92ms | 33% Byzantine tolerance |
| Adaptive | 0.05ms | Fastest - MoE sparse routing |

### 5.3 Flash Attention O(N) Validation

```
Agents | Time   | Expected O(N^2) | Actual O(N) | Status
-------|--------|-----------------|-------------|--------
100    | 0.40ms | Baseline        | Baseline    | PASS
200    | 0.33ms | 4x (1.60ms)     | 0.8x        | PASS
400    | 0.64ms | 16x (6.4ms)     | 1.6x        | PASS
800    | 1.15ms | 64x (25.6ms)    | 2.9x        | PASS

Linear scaling CONFIRMED
```

---

## 6. What Could Be Lifted/Shipped

### 6.1 Benchmark Framework

**Highly Reusable Components**:

1. **High-Precision Timer** (`/benchmarks/utils/benchmark.ts`)
   - Warmup + iteration pattern
   - Percentile calculations (P50, P95, P99)
   - Regression detection
   - JSON result saving

2. **Benchmark Suite Runner**
   - Parallel benchmark execution
   - Summary table generation
   - HTML report generation

### 6.2 Test Patterns

**Adaptable for Nancy**:

1. **Simple Test Wrapper**
```javascript
function test(name, fn) {
  process.stdout.write(`\n📝 ${name}... `);
  try {
    fn();
    console.log('✅ PASS');
    passedTests++;
  } catch (error) {
    console.log(`❌ FAIL: ${error.message}`);
    failedTests++;
  }
}
```

2. **Mock Agent Creation**
```typescript
export const createMockAgent = (type: string) => ({
  id: `agent-${Math.random().toString(36).substring(7)}`,
  type,
  status: 'active',
  createdAt: Date.now(),
});
```

3. **Network Delay Simulation**
```typescript
export const simulateNetworkDelay = (min = 10, max = 50) =>
  wait(Math.random() * (max - min) + min);
```

### 6.3 Performance Target Patterns

```markdown
| Metric | Target | Status | Improvement |
|--------|--------|--------|-------------|
| Operation X | <10ms P50 | PASS | 10x faster |
```

---

## 7. Recommendations for Nancy

### 7.1 Testing Infrastructure

1. **Adopt the Benchmark Framework**
   - Port `/benchmarks/utils/benchmark.ts` for bash timing tests
   - Use warmup iterations to eliminate cold-start effects
   - Calculate percentiles for latency measurements

2. **Use Simple CJS Test Format**
   - The `.cjs` test files are standalone and don't require build steps
   - Good for bash integration testing

3. **Define Performance Targets**
   - Set explicit P50/P95 targets for key operations
   - Implement regression detection

### 7.2 Suggested Test Categories for Nancy

| Category | Description | Target |
|----------|-------------|--------|
| Session startup | Time to initialize nancy | <100ms |
| Skill loading | Time to load skill markdown | <50ms |
| Message parsing | Time to parse orchestrator messages | <10ms |
| Notification latency | Time from trigger to notification | <200ms |
| Token counting | Accuracy and speed | 99% accurate, <50ms |

### 7.3 Benchmark Script Template

```bash
#!/usr/bin/env bash
# benchmark-template.sh

ITERATIONS=100
WARMUP=10
results=()

# Warmup
for ((i=0; i<WARMUP; i++)); do
  nancy_operation > /dev/null 2>&1
done

# Benchmark
for ((i=0; i<ITERATIONS; i++)); do
  start=$(gdate +%s%3N)  # milliseconds
  nancy_operation > /dev/null 2>&1
  end=$(gdate +%s%3N)
  duration=$((end - start))
  results+=($duration)
done

# Calculate P50
sorted=($(printf '%s\n' "${results[@]}" | sort -n))
p50_idx=$((ITERATIONS / 2))
echo "P50: ${sorted[$p50_idx]}ms"
```

### 7.4 CI/CD Integration

From agentic-flow's approach:
- Run benchmarks on PRs with regression detection
- Run comprehensive suite nightly
- Upload results as artifacts
- Generate HTML reports for visualization

---

## 8. Performance Insights

### 8.1 GNN Performance Characteristics

- **Float32Array Required**: Native GNN bindings require typed arrays
- **Speedup Scales with Dataset Size**: 10K vectors shows higher speedup than 1K
- **Temperature Parameter**: Affects search softness (0.5 typical)

### 8.2 Attention Mechanism Trade-offs

| Mechanism | Speed | Quality | Memory | Best Use Case |
|-----------|-------|---------|--------|---------------|
| Flash | Fastest | High | Lowest | Large sequences |
| Multi-Head | Medium | Highest | High | Precision-critical |
| Linear | Fast | Medium | Low | Real-time inference |
| Hyperbolic | Fast | High | Low | Hierarchical data |
| MoE | Variable | High | Medium | Sparse routing |

### 8.3 Scalability Findings

- Flash Attention achieves **O(N) complexity** vs O(N^2) for standard attention
- Hierarchical coordination scales better than mesh for >50 agents
- Adaptive coordination combines benefits with 94% mechanism selection accuracy

---

## 9. Key Takeaways

1. **Comprehensive Benchmark Suite**: The framework is production-grade with regression detection
2. **GNN Integration Challenges**: Alpha stage with Float32Array requirements
3. **Attention Mechanisms Work**: Multiple mechanisms tested and validated
4. **Swarm Coordination Proven**: 476x better than targets for hierarchical
5. **Reusable Components**: Benchmark framework, test patterns, and mock utilities can be adapted

---

## 10. Files of Interest

### Root Level
- `/test-gnn-performance.cjs` - Core GNN performance test
- `/test-gnn-float32-performance.cjs` - Float32Array tests
- `/test-all-fixes.cjs` - Comprehensive fix validation
- `/test-agent-booster-real.cjs` - Agent Booster integration test

### Benchmark Directory
- `/benchmarks/utils/benchmark.ts` - Reusable benchmark framework
- `/benchmarks/src/gnn.bench.ts` - GNN benchmarks
- `/benchmarks/src/attention.bench.ts` - Attention benchmarks
- `/benchmarks/attention-gnn-benchmark.js` - Combined benchmark

### Test Directory
- `/tests/setup.ts` - Global test setup
- `/tests/jest.config.ts` - Jest configuration
- `/tests/COVERAGE_REPORT.md` - Coverage documentation

### Configuration
- `/jest.config.js` - Primary Jest config
- `/config/jest.config.js` - Alternative config
- `/package.json` - Scripts and dependencies

---

*Document generated for Nancy project reference*
