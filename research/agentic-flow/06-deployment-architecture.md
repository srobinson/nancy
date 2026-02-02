# Agentic-Flow: Docker and Deployment Architecture Deep Dive

## Executive Summary

Agentic-Flow demonstrates a mature, production-ready Docker and deployment architecture with multi-cloud support, sophisticated CI/CD pipelines, and a comprehensive suite of containerized services. The project showcases best practices in containerization while supporting diverse deployment targets from local development to enterprise Kubernetes clusters.

---

## 1. Docker Architecture

### 1.1 Multi-Stage Build Pattern

The project consistently uses multi-stage Docker builds across all Dockerfiles, demonstrating a well-architected approach to image optimization.

**Base Pattern (from `docker/base/Dockerfile`):**
```dockerfile
# Stage 1: Builder
FROM node:20-alpine AS builder
RUN apk add --no-cache python3 make g++ git
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force
COPY src ./src
RUN npm run build

# Stage 2: Production
FROM node:20-alpine
RUN apk add --no-cache curl ca-certificates tini
RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001
WORKDIR /app
COPY --from=builder --chown=nodejs:nodejs /app/dist ./dist
USER nodejs
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "dist/index.js"]
```

**Key Strengths:**
- Clean separation between build-time and runtime dependencies
- Minimal production images using Alpine base
- Non-root user execution (security best practice)
- Signal handling via tini/dumb-init
- Consistent healthcheck patterns across all images

### 1.2 Core Container Images

The architecture defines four primary container images:

| Image | Purpose | Port | Dockerfile |
|-------|---------|------|------------|
| `agentic-flow` | Main orchestration platform | 3000/8080 | `Dockerfile.agentic-flow` |
| `agentic-flow-agentdb` | Vector database with ReasoningBank | 5432 | `Dockerfile.agentdb` |
| `agentic-flow-mcp` | MCP tools server (213 tools) | 8080 | `Dockerfile.mcp-server` |
| `agentic-flow-swarm` | Multi-agent swarm coordinator | 9000 | `Dockerfile.swarm` |

### 1.3 Docker Compose Orchestration

**Main Service Stack (`docker/docker-compose.yml`):**
```yaml
services:
  agentic-flow:
    build:
      context: ..
      dockerfile: docker/base/Dockerfile
    volumes:
      - agent-memory:/app/.claude-flow/memory
      - agent-metrics:/app/.claude-flow/metrics
    healthcheck:
      test: ["CMD", "node", "dist/health.js"]
      interval: 30s
      timeout: 3s
      retries: 3
      start_period: 5s
    restart: unless-stopped

  # Provider-specific variants
  agentic-flow-claude:  # Port 8081
  agentic-flow-llama:   # Port 8082 (OpenRouter)
  agentic-flow-deepseek: # Port 8083 (OpenRouter)

volumes:
  agent-memory:
  agent-metrics:
```

**Strengths:**
- Service extension pattern for provider variants
- Persistent volumes for memory and metrics
- Health checks with appropriate timing
- Restart policies for resilience

### 1.4 Federation Architecture

The project includes a sophisticated multi-agent federation system (`agentic-flow/docker/federation-test/docker-compose.production.yml`):

```yaml
services:
  federation-hub:
    # Central coordination server
    ports: ["8443:8443", "8444:8444"]
    environment:
      - FEDERATION_MAX_AGENTS=1000
    volumes:
      - hub-data:/data
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:8444/health || exit 1"]

  agent-researcher:  # Tenant: test-collaboration
  agent-coder:       # Tenant: test-collaboration
  agent-tester:      # Tenant: test-collaboration
  agent-reviewer:    # Tenant: test-collaboration
  agent-isolated:    # Tenant: different-tenant (isolation test)
```

**Key Features:**
- Hub-and-spoke architecture with WebSocket communication
- Multi-tenancy support with tenant isolation
- Dependency ordering via `depends_on` with health conditions
- Restart policies with backoff (`max_attempts: 3`, `delay: 5s`)

---

## 2. Deployment Configurations

### 2.1 Google Cloud Platform (Primary Target)

**Cloud Run Deployment (`docker/cloud-run/deploy.sh`):**

```bash
# Configuration variables
PROJECT_ID="${GCP_PROJECT_ID:-}"
REGION="${GCP_REGION:-us-central1}"
MEMORY="${MEMORY:-2Gi}"
CPU="${CPU:-2}"
MAX_INSTANCES="${MAX_INSTANCES:-10}"
MIN_INSTANCES="${MIN_INSTANCES:-0}"
CONCURRENCY="${CONCURRENCY:-80}"

# Provider-aware secret injection
case "$MODEL_PROVIDER" in
    anthropic) SECRET_ENVS="--set-secrets=ANTHROPIC_API_KEY=ANTHROPIC_API_KEY:latest" ;;
    openrouter) SECRET_ENVS="--set-secrets=OPENROUTER_API_KEY=OPENROUTER_API_KEY:latest" ;;
    onnx) SECRET_ENVS="" ;;  # Local models, no API keys
esac

# Deploy with GCP Secret Manager integration
gcloud run deploy "${SERVICE_NAME}" \
    --image="${IMAGE_NAME}:latest" \
    --memory="${MEMORY}" \
    --cpu="${CPU}" \
    --max-instances="${MAX_INSTANCES}" \
    --min-instances="${MIN_INSTANCES}" \
    ${SECRET_ENVS}
```

**Cloud Build Configuration (`docker/cloud-run/cloudbuild.yaml`):**
```yaml
steps:
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'build'
      - '-t'
      - 'gcr.io/$PROJECT_ID/agentic-flow:$SHORT_SHA'
      - '-t'
      - 'gcr.io/$PROJECT_ID/agentic-flow:latest'
      - '--cache-from'
      - 'gcr.io/$PROJECT_ID/agentic-flow:latest'
      - '--build-arg'
      - 'BUILDKIT_INLINE_CACHE=1'
      - '.'

options:
  machineType: 'N1_HIGHCPU_8'
  diskSizeGb: 100
```

**GCP Services Integration:**
- Cloud Run for serverless container hosting
- Secret Manager for credentials
- Container Registry for image storage
- Cloud Build for automated builds
- Cloud Logging and Monitoring

### 2.2 Resource Tiers

The project defines clear resource tiers:

| Tier | Memory | CPU | Max Instances | Use Case |
|------|--------|-----|---------------|----------|
| Small | 1Gi | 1 | 3 | Development |
| Medium | 2Gi | 2 | 10 | Production |
| Large | 4Gi | 4 | 50 | Enterprise |

### 2.3 Model Provider Support

**Cost Comparison (per 1000 tasks):**

| Provider | Model | Cost | Savings |
|----------|-------|------|---------|
| Anthropic | Claude 3.5 Sonnet | $80.00 | 0% |
| OpenRouter | Llama 3.1 8B | $0.30 | 99.6% |
| OpenRouter | DeepSeek | $0.50 | 99.4% |
| OpenRouter | Gemini 2.5 Flash | $1.00 | 98.8% |
| ONNX | Phi-4 (local) | $0.00 | 100% |

---

## 3. Kubernetes Potential

### 3.1 Existing Helm Chart

The project includes a Helm chart for the Jujutsu GitOps controller (`charts/jujutsu-gitops-controller/`):

**values.yaml highlights:**
```yaml
replicaCount: 2

image:
  repository: agentic-jujutsu/controller
  pullPolicy: IfNotPresent

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi

autoscaling:
  enabled: false
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 80

affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          topologyKey: kubernetes.io/hostname

controller:
  reconcileInterval: "30s"
  leaderElection:
    enabled: true
```

### 3.2 Production K8s Patterns (climate-prediction example)

**Deployment with HPA (`examples/climate-prediction/deployment/kubernetes/deployment.yaml`):**
```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
      containers:
      - name: climate-prediction
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop: ["ALL"]
        livenessProbe:
          httpGet:
            path: /health
            port: http
          initialDelaySeconds: 30
        readinessProbe:
          httpGet:
            path: /health
            port: http
          initialDelaySeconds: 10
        startupProbe:
          httpGet:
            path: /health
            port: http
          failureThreshold: 30

---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
spec:
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
    scaleUp:
      stabilizationWindowSeconds: 0
```

**Network Security (`ingress.yaml`):**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/rate-limit: "100"
    nginx.ingress.kubernetes.io/limit-rps: "10"
    nginx.ingress.kubernetes.io/enable-cors: "true"
spec:
  tls:
  - hosts:
    - climate-prediction.example.com
    secretName: climate-prediction-tls

---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
spec:
  policyTypes: [Ingress, Egress]
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
  egress:
  - to:
    ports:
    - protocol: TCP
      port: 5432  # PostgreSQL
    - protocol: TCP
      port: 6379  # Redis
```

### 3.3 Advanced Deployment Patterns

The project defines sophisticated deployment patterns in `src/controller/config/deployment-patterns.yaml`:

**1. Self-Learning Pattern:**
```yaml
reasoningBank:
  enabled: true
  memoryRetention: 30d
  trajectoryTracking: true
  verdictJudgment: true
learning:
  algorithms: [decision-transformer, q-learning, actor-critic]
  experienceReplay:
    bufferSize: 10000
    batchSize: 32
```

**2. Continuous Operations Pattern:**
```yaml
highAvailability:
  replicas: 3
  leaderElection: true
deployment:
  strategy: blue-green
  progressiveDelivery:
    canary:
      steps:
        - weight: 10, pause: 5m
        - weight: 25, pause: 10m
        - weight: 50, pause: 15m
        - weight: 75, pause: 20m
        - weight: 100
```

**3. Security-First Pattern:**
```yaml
supplyChain:
  sigstore:
    enabled: true
    keyless: true
  cosign:
    verify: true
  sbom:
    generate: true
    format: spdx
policy:
  kyverno:
    policies:
      - require-signed-images
      - disallow-latest-tag
      - require-non-root
      - require-read-only-root-fs
```

**4. AI Autonomous Scaling:**
```yaml
autoscaling:
  type: predictive
  ai:
    model: lstm
    predictionWindow: 30m
    trainingData: 7d
prediction:
  metrics: [cpu, memory, request_rate, response_time, queue_depth]
  algorithms: [time-series-forecast, pattern-recognition, anomaly-detection]
proactive:
  scaleUpAhead: 5m
  scaleDownDelay: 10m
```

**5. QUIC Multi-Agent Pattern:**
```yaml
quic:
  maxStreams: 1000
  connectionMigration: true
  zeroRTT: true
coordination:
  protocol: quic
  latency:
    target: "<50ms"
agentdb:
  sync:
    protocol: quic
    interval: 100ms
```

---

## 4. CI/CD Patterns

### 4.1 Docker Publish Workflow

**`.github/workflows/docker-publish.yml`:**

```yaml
name: Docker Build and Publish

on:
  push:
    branches: [main, develop]
    tags: ['v*']
  workflow_dispatch:

jobs:
  build-and-push:
    strategy:
      matrix:
        include:
          - name: ""
            image: agentic-flow
            platforms: linux/amd64,linux/arm64
          - name: "-agentdb"
            image: agentic-flow-agentdb
            platforms: linux/amd64,linux/arm64
          - name: "-mcp"
            image: agentic-flow-mcp
            platforms: linux/amd64,linux/arm64
          - name: "-swarm"
            image: agentic-flow-swarm
            platforms: linux/amd64,linux/arm64

    steps:
      - uses: docker/setup-qemu-action@v3
      - uses: docker/setup-buildx-action@v3
      - uses: docker/login-action@v3
      - uses: docker/metadata-action@v5
        with:
          tags: |
            type=ref,event=branch
            type=semver,pattern={{version}}
            type=sha,prefix=sha-
            type=raw,value=latest,enable={{is_default_branch}}
      - uses: docker/build-push-action@v5
        with:
          platforms: ${{ matrix.platforms }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  security-scan:
    needs: build-and-push
    steps:
      - uses: aquasecurity/trivy-action@master
        with:
          format: 'sarif'
      - uses: github/codeql-action/upload-sarif@v2

  integration-test:
    needs: build-and-push
    steps:
      - run: docker-compose --env-file .env.test up -d
      - run: |
          curl -f http://localhost:3000/health
          curl -f http://localhost:8080/health
          curl -f http://localhost:9000/health
```

**Key CI/CD Features:**
- Multi-architecture builds (amd64, arm64)
- GitHub Actions cache for faster builds
- Trivy security scanning with SARIF reports
- Integration tests against running containers
- Docker Hub description auto-update

### 4.2 Testing Infrastructure

**Parallel Test Execution (`tests/docker/docker-compose.parallel.yml`):**
```yaml
services:
  parallel-test:
    environment:
      - ENABLE_PARALLEL_EXECUTION=true
    command: npm run test:parallel

  mesh-swarm:
    environment:
      - SWARM_TOPOLOGY=mesh
      - MAX_AGENTS=10
      - BATCH_SIZE=5

  hierarchical-swarm:
    environment:
      - SWARM_TOPOLOGY=hierarchical
      - MAX_AGENTS=8

  ring-swarm:
    environment:
      - SWARM_TOPOLOGY=ring
      - MAX_AGENTS=6

  benchmark:
    environment:
      - BENCHMARK_MODE=true
      - ITERATIONS=10
```

---

## 5. Scaling Considerations

### 5.1 Horizontal Scaling

**Cloud Run:**
- `MIN_INSTANCES=0` for cost optimization (scale to zero)
- `MAX_INSTANCES=50` for enterprise workloads
- `CONCURRENCY=80-160` based on tier

**Kubernetes:**
- HPA with CPU (70%) and memory (80%) targets
- Scale-up: immediate, scale-down: 5-minute stabilization
- Pod anti-affinity for distribution across nodes

### 5.2 Vertical Scaling

| Component | Min Resources | Max Resources |
|-----------|---------------|---------------|
| Main App | 1Gi/1CPU | 4Gi/4CPU |
| AgentDB | 256Mi | 2Gi |
| MCP Server | 512Mi | 2Gi |
| Swarm | 512Mi | 4Gi |

### 5.3 State Management

- **Memory**: Persistent volumes (`agent-memory`, `agent-metrics`)
- **AgentDB**: SQLite with persistent volume, 150x vector performance claim
- **Federation Hub**: Persistent hub database (`hub-data:/data`)
- **Swarm**: Persistent swarm and memory data directories

---

## 6. What Could Be Lifted/Shipped (Recommendations for Nancy)

### 6.1 High-Value Patterns to Adopt

**1. Multi-Stage Dockerfile Template:**
```dockerfile
# Directly applicable to Nancy
FROM node:20-alpine AS builder
RUN apk add --no-cache python3 make g++
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY src ./src
RUN npm run build

FROM node:20-alpine AS production
RUN apk add --no-cache dumb-init && \
    addgroup -g 1001 -S appuser && \
    adduser -S appuser -u 1001
WORKDIR /app
COPY --from=builder --chown=appuser:appuser /app/dist ./dist
USER appuser
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["node", "dist/index.js"]
```

**2. Health Check Script (`health-check.sh`):**
The comprehensive health check script checking containers, HTTP endpoints, volumes, and networks is directly reusable:
- Container status verification
- HTTP endpoint health checks with retries
- Volume existence validation
- Network connectivity checks
- Resource usage reporting

**3. Cloud Run Deployment Pattern:**
The `deploy.sh` pattern with:
- Prerequisites checking
- API enabling
- Secret creation from .env
- Provider-aware configuration
- Service URL retrieval

**4. GitHub Actions Workflow:**
- Multi-architecture builds
- Security scanning with Trivy
- Integration testing
- Docker Hub description sync

### 6.2 Configuration Templates

**Environment Templates Pattern:**
```bash
# configs/
# ├── claude.env.template
# ├── openrouter.env.template
# └── multi-model.env.template
```

These template files provide excellent UX for different deployment scenarios.

### 6.3 Deployment Patterns Library

The `deployment-patterns.yaml` file is particularly valuable, defining:
- Self-learning agents
- Continuous operations
- Security-first deployments
- AI-driven autoscaling
- QUIC-based multi-agent coordination
- Cost optimization strategies
- Performance optimization

---

## 7. Strengths

### 7.1 Architecture Strengths

1. **Modular Container Design**: Clean separation of concerns with dedicated containers for different functions (main app, database, MCP tools, swarm coordination)

2. **Security-First Approach**:
   - Non-root users in all containers
   - Read-only root filesystems
   - Capability dropping
   - Network policies
   - Supply chain security (Sigstore, Cosign)

3. **Multi-Cloud Ready**: GCP Cloud Run as primary, with patterns for Kubernetes that work on any cloud

4. **Cost Optimization**: Explicit support for cost-effective model providers (99%+ savings with OpenRouter), scale-to-zero, spot instances

5. **Comprehensive Testing**: Parallel test infrastructure, topology-specific swarm tests, benchmark suites

6. **Production Hardening**:
   - Health checks with appropriate timing
   - Restart policies with backoff
   - Progressive deployment (canary, blue-green)
   - Automatic rollback capabilities

### 7.2 Developer Experience

1. **Quick Deploy Scripts**: One-command deployments to Cloud Run
2. **Environment Templates**: Pre-configured templates for different providers
3. **Diagnostic Tools**: Health check and diagnostic scripts
4. **Clear Documentation**: Comprehensive README with examples

---

## 8. Weaknesses and Gaps

### 8.1 Technical Gaps

1. **Kubernetes Support Incomplete**:
   - "Coming soon" for `docker/kubernetes/` directory
   - Helm chart exists only for GitOps controller, not main agentic-flow
   - No official agentic-flow Helm chart

2. **Multi-Region Strategy**:
   - Basic multi-region example in docs
   - No built-in state replication across regions
   - Global load balancing mentioned but not implemented

3. **Secret Rotation**:
   - Secret creation automated, but rotation is manual
   - No automatic secret refresh without redeployment

4. **Database Scaling**:
   - AgentDB appears to be single-instance SQLite
   - No clear path to distributed database for high scale

5. **Service Mesh**:
   - Mentioned in patterns but not implemented
   - No Istio/Linkerd integration examples

### 8.2 Operational Gaps

1. **Observability**:
   - Basic health checks implemented
   - Prometheus mentioned but not fully integrated
   - No distributed tracing (OpenTelemetry)

2. **Backup/Recovery**:
   - Defined in patterns but not implemented in compose files
   - No point-in-time recovery for AgentDB

3. **Rate Limiting**:
   - Only in K8s ingress examples
   - No application-level rate limiting in compose setup

4. **Circuit Breakers**:
   - Not implemented
   - Important for resilience with external LLM providers

### 8.3 Documentation Gaps

1. **Capacity Planning**: No guidance on sizing for specific workloads
2. **Disaster Recovery**: No documented DR procedures
3. **Upgrade Procedures**: No documented rolling upgrade process

---

## 9. Recommendations for Nancy

### 9.1 Immediate Adoption (High Value, Low Effort)

1. **Adopt Multi-Stage Dockerfile Pattern**: Reduces image size, improves security
2. **Implement Health Check Script**: Comprehensive diagnostics for local development
3. **Use Environment Templates**: Improves developer onboarding
4. **Add GitHub Actions Workflow**: CI/CD with security scanning

### 9.2 Medium-Term Adoption

1. **Create Cloud Run Deployment Script**: Serverless deployment for Nancy CLI
2. **Implement Docker Compose Stack**: Local development environment
3. **Add Trivy Security Scanning**: Catch vulnerabilities early

### 9.3 Long-Term Considerations

1. **Helm Chart**: If Kubernetes deployment is desired
2. **Deployment Patterns Library**: Adapt relevant patterns (continuous-operations, security-first)
3. **Federation Architecture**: If multi-agent orchestration is needed

### 9.4 Specific Patterns to Avoid

1. **Over-Engineering**: Nancy is a CLI tool; full federation/swarm may be overkill
2. **GCP Lock-in**: Consider cloud-agnostic patterns unless GCP is the target
3. **SQLite for Scale**: If Nancy needs persistence at scale, consider alternatives

---

## 10. Summary

Agentic-Flow provides a mature, well-architected Docker and deployment infrastructure that balances sophistication with practicality. The multi-stage builds, security hardening, and comprehensive CI/CD pipelines represent production-ready patterns. The project's strength lies in its flexibility (multiple model providers, deployment targets) and cost-awareness (99% savings with alternative providers).

For Nancy, the most immediately valuable elements are:
- Multi-stage Dockerfile patterns
- Health check infrastructure
- GitHub Actions workflow with security scanning
- Environment templates for configuration management
- Cloud Run deployment patterns (if serverless deployment is desired)

The gaps (incomplete K8s support, single-instance database, missing observability) are understandable given the project's evolution and provide a roadmap for future improvements.

---

## Appendix: File References

| File | Purpose |
|------|---------|
| `/Users/alphab/Dev/LLM/DEV/agentic-flow/docker/README.md` | Main deployment documentation |
| `/Users/alphab/Dev/LLM/DEV/agentic-flow/docker/docker-compose.yml` | Service orchestration |
| `/Users/alphab/Dev/LLM/DEV/agentic-flow/docker/base/Dockerfile` | Base image definition |
| `/Users/alphab/Dev/LLM/DEV/agentic-flow/docker/Dockerfile.agentic-flow` | Main application image |
| `/Users/alphab/Dev/LLM/DEV/agentic-flow/docker/Dockerfile.agentdb` | Vector database image |
| `/Users/alphab/Dev/LLM/DEV/agentic-flow/docker/Dockerfile.mcp-server` | MCP tools server image |
| `/Users/alphab/Dev/LLM/DEV/agentic-flow/docker/Dockerfile.swarm` | Swarm coordinator image |
| `/Users/alphab/Dev/LLM/DEV/agentic-flow/docker/cloud-run/deploy.sh` | GCP deployment script |
| `/Users/alphab/Dev/LLM/DEV/agentic-flow/docker/cloud-run/cloudbuild.yaml` | Cloud Build configuration |
| `/Users/alphab/Dev/LLM/DEV/agentic-flow/docker/scripts/health-check.sh` | Comprehensive health checks |
| `/Users/alphab/Dev/LLM/DEV/agentic-flow/.github/workflows/docker-publish.yml` | CI/CD workflow |
| `/Users/alphab/Dev/LLM/DEV/agentic-flow/charts/jujutsu-gitops-controller/` | Helm chart |
| `/Users/alphab/Dev/LLM/DEV/agentic-flow/examples/climate-prediction/deployment/kubernetes/` | K8s examples |
| `/Users/alphab/Dev/LLM/DEV/agentic-flow/src/controller/config/deployment-patterns.yaml` | Advanced patterns |
| `/Users/alphab/Dev/LLM/DEV/agentic-flow/agentic-flow/docker/federation-test/docker-compose.production.yml` | Federation architecture |
| `/Users/alphab/Dev/LLM/DEV/agentic-flow/tests/docker/docker-compose.parallel.yml` | Testing infrastructure |
