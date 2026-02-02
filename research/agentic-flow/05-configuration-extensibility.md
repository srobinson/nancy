# Agentic-Flow: Configuration & Extensibility Deep Dive

**Analysis Date:** 2026-01-22
**Source:** `/Users/alphab/Dev/LLM/DEV/agentic-flow`
**Version:** v2.0.0-alpha

---

## Executive Summary

Agentic-flow features a sophisticated, multi-layered configuration architecture designed for enterprise-grade multi-model LLM orchestration. The system provides extensive customization through hierarchical configuration files, environment variables, plugins, hooks, and adapters. This analysis covers the configuration architecture, extension mechanisms, and identifies patterns that could be valuable for Nancy.

---

## 1. Configuration Architecture

### 1.1 Configuration Hierarchy

Agentic-flow implements a cascading configuration system with multiple resolution layers:

```
Priority (highest to lowest):
1. Programmatic overrides (constructor parameters)
2. Environment variables
3. User config (~/.agentic-flow/*)
4. Project config (./config/* or ./*.config.json)
5. Example/default configs
```

**Key Files:**
- `/config/` - Root-level code quality configurations
- `/agentic-flow/config/` - Core framework configs
- `/docker/configs/` - Deployment-specific configs
- `~/.agentic-flow/` - User-level configs

### 1.2 Router Configuration (`router.config.json`)

The multi-model router is the heart of agentic-flow's configuration system:

```json
{
  "version": "1.0",
  "defaultProvider": "anthropic",
  "fallbackChain": ["anthropic", "onnx", "openrouter"],
  "providers": {
    "anthropic": { ... },
    "openai": { ... },
    "openrouter": { ... },
    "ollama": { ... },
    "litellm": { ... },
    "onnx": { ... }
  },
  "routing": {
    "mode": "cost-optimized",  // manual | cost-optimized | performance-optimized | rule-based
    "rules": [ ... ],
    "costOptimization": { ... },
    "performance": { ... }
  },
  "toolCalling": { ... },
  "monitoring": { ... },
  "cache": { ... }
}
```

**Routing Modes:**
- `manual` - Use default provider only
- `cost-optimized` - Prefer cheaper providers
- `performance-optimized` - Select based on latency metrics
- `rule-based` - Match conditions to provider/model selection

**Rule-Based Routing Example:**
```json
{
  "condition": {
    "agentType": ["researcher", "planner"],
    "complexity": "low"
  },
  "action": {
    "provider": "openrouter",
    "model": "anthropic/claude-3-haiku",
    "temperature": 0.7
  },
  "reason": "Simple research tasks use cheaper models via OpenRouter"
}
```

### 1.3 Environment Variable System

Agentic-flow uses a comprehensive environment variable system with template substitution:

**Location:** `/agentic-flow/config/.env.example`

```bash
# Core API Keys
ANTHROPIC_API_KEY=sk-ant-...
OPENROUTER_API_KEY=sk-or-...
OPENAI_API_KEY=sk-...

# Router Configuration
ROUTER_DEFAULT_PROVIDER=anthropic
ROUTER_MODE=cost-optimized

# ONNX Runtime (Local Inference)
ONNX_MODEL_ID=Xenova/Phi-3-mini-4k-instruct
ONNX_EXECUTION_PROVIDERS=cpu
ONNX_GPU_ACCELERATION=false
ONNX_MAX_TOKENS=512

# Feature Flags
ENABLE_CLAUDE_FLOW_MCP=true
ENABLE_FLOW_NEXUS_MCP=false
```

**Template Substitution Pattern:**
```json
{
  "apiKey": "${ANTHROPIC_API_KEY}",
  "baseUrl": "${OLLAMA_BASE_URL:-http://localhost:11434}"
}
```

This supports default values with the `:-` syntax.

### 1.4 TypeScript Configuration Pattern

Configuration modules follow a consistent pattern:

**Location:** `/agentic-flow/src/config/`

```typescript
// Example: quic.ts
export interface QuicConfigSchema extends QuicConfig {
  enabled: boolean;
  autoDetect: boolean;
  fallbackToHttp2: boolean;
  healthCheck: { enabled: boolean; interval: number; timeout: number };
  monitoring: { enabled: boolean; logInterval: number };
}

export const DEFAULT_QUIC_CONFIG: QuicConfigSchema = {
  enabled: false,
  autoDetect: true,
  // ... defaults
};

export function loadQuicConfig(overrides: Partial<QuicConfigSchema> = {}): QuicConfigSchema {
  const config = { ...DEFAULT_QUIC_CONFIG, ...overrides };

  // Environment variable overrides
  if (process.env.AGENTIC_FLOW_ENABLE_QUIC !== undefined) {
    config.enabled = process.env.AGENTIC_FLOW_ENABLE_QUIC === 'true';
  }

  validateQuicConfig(config);
  return config;
}
```

**Pattern Benefits:**
- Type-safe configuration
- Validation at load time
- Environment override support
- Default fallbacks
- Programmatic overrides

---

## 2. Extension Points

### 2.1 Plugin System

**Location:** `/agentic-flow/src/sdk/plugins.ts`

The plugin system supports four loading mechanisms:

```typescript
export type PluginConfig =
  | LocalPluginConfig   // { type: 'local', path: string }
  | NpmPluginConfig     // { type: 'npm', package: string, version?: string }
  | RemotePluginConfig  // { type: 'remote', url: string, checksum?: string }
  | InlinePluginConfig; // { type: 'inline', name: string, tools: PluginTool[] }

export interface PluginTool {
  name: string;
  description: string;
  inputSchema: Record<string, any>;
  handler: (input: any) => Promise<any>;
}

export interface LoadedPlugin {
  name: string;
  version: string;
  source: string;
  tools: PluginTool[];
  enabled: boolean;
  loadedAt: number;
}
```

**Plugin Registry Operations:**
```typescript
// Load plugin
await loadPlugin({ type: 'npm', package: 'my-plugin' });

// Get all loaded plugins
const plugins = getLoadedPlugins();

// Enable/disable plugins
setPluginEnabled('my-plugin', false);

// Execute plugin tool
const result = await executePluginTool('my-tool', input);

// Create inline plugin
createPlugin('my-inline-plugin', [
  defineTool({
    name: 'myTool',
    description: 'Does something',
    inputSchema: { /* JSON Schema */ },
    handler: async (input) => { /* ... */ }
  })
]);
```

**Security Feature:**
Remote plugins support SHA-256 checksum verification.

### 2.2 Hooks System

**Location:** `/agentic-flow/src/sdk/hooks-bridge.ts`

The hooks bridge integrates with Claude Agent SDK events:

```typescript
export type HookEvent =
  | 'PreToolUse'
  | 'PostToolUse'
  | 'PostToolUseFailure'
  | 'Notification'
  | 'UserPromptSubmit'
  | 'SessionStart'
  | 'SessionEnd'
  | 'Stop'
  | 'SubagentStart'
  | 'SubagentStop'
  | 'PreCompact'
  | 'PermissionRequest';

export type HookCallback = (
  input: HookInput,
  toolUseId: string | undefined,
  options: { signal: AbortSignal }
) => Promise<HookJSONOutput>;

export interface HookJSONOutput {
  continue?: boolean;
  suppressOutput?: boolean;
  stopReason?: string;
  decision?: 'approve' | 'block';
  systemMessage?: string;
  reason?: string;
  hookSpecificOutput?: { ... };
}
```

**Hook Registration:**
```typescript
// Get all SDK hooks
export function getSdkHooks(): Partial<Record<HookEvent, HookCallbackMatcher[]>> {
  return {
    PreToolUse: [{ hooks: [preToolUseHook] }],
    PostToolUse: [{ hooks: [postToolUseHook] }],
    SessionStart: [{ hooks: [sessionStartHook] }],
    // ...
  };
}

// Tool-specific hooks
export function getToolSpecificHooks(toolMatcher: string) {
  return {
    PreToolUse: [{ matcher: toolMatcher, hooks: [preToolUseHook] }],
    // ...
  };
}
```

**Trajectory Tracking:**
Hooks implement trajectory tracking with TTL (5-minute max) for task learning.

### 2.3 Provider System

**Location:** `/agentic-flow/src/router/providers/`

Providers implement the `LLMProvider` interface:

```typescript
export interface LLMProvider {
  name: string;
  type: ProviderType;
  supportsStreaming: boolean;
  supportsTools: boolean;
  supportsMCP: boolean;
  chat(params: ChatParams): Promise<ChatResponse>;
  stream?(params: ChatParams): AsyncGenerator<StreamChunk>;
  validateCapabilities(features: string[]): boolean;
}
```

**Available Providers:**
- `AnthropicProvider` - Native Claude support with MCP
- `OpenRouterProvider` - Multi-model gateway
- `ONNXLocalProvider` - Local inference (CPU/GPU)
- `GeminiProvider` - Google Gemini models
- Ollama, LiteLLM (TODO)

**Adding a Custom Provider:**
```typescript
export class CustomProvider implements LLMProvider {
  name = 'custom';
  type = 'custom' as const;
  supportsStreaming = true;
  supportsTools = false;
  supportsMCP = false;

  constructor(config: ProviderConfig) {
    // Initialize with config
  }

  async chat(params: ChatParams): Promise<ChatResponse> {
    // Implementation
  }

  async *stream(params: ChatParams): AsyncGenerator<StreamChunk> {
    // Streaming implementation
  }

  validateCapabilities(features: string[]): boolean {
    // Check supported features
  }
}
```

### 2.4 Agent Definitions

**Location:** `/.claude/agents/`

Agents are defined in Markdown with YAML frontmatter:

```markdown
---
name: coder
type: developer
color: "#FF6B35"
description: Implementation specialist for writing clean, efficient code
capabilities:
  - code_generation
  - refactoring
  - optimization
priority: high
hooks:
  pre: |
    echo "Coder agent implementing: $TASK"
  post: |
    echo "Implementation complete"
    npm run lint --if-present
---

# Code Implementation Agent

You are a senior software engineer...
```

**Agent Categories (54+ agents):**
- `core/` - coder, reviewer, tester, planner, researcher
- `swarm/` - hierarchical, mesh, adaptive coordinators
- `consensus/` - byzantine, raft, gossip, quorum managers
- `github/` - PR manager, issue tracker, release manager
- `sparc/` - specification, pseudocode, architecture, refinement

### 2.5 Permission Handler Extension

**Location:** `/agentic-flow/src/sdk/permission-handler.ts`

Three permission modes with pattern-based security:

```typescript
// Dangerous patterns blocked
const DANGEROUS_PATTERNS = [
  /rm\s+-rf\s+[\/~]/,
  /curl.*\|\s*(bash|sh|zsh)/,
  /DROP\s+TABLE/i,
  /git\s+push\s+.*--force/,
  // ...
];

// Blocked file paths
const BLOCKED_PATHS = [
  /^\/etc\/passwd$/,
  /\.ssh\/id_/,
  /\.env$/,
  // ...
];

// Permission modes
export function getPermissionHandler(mode: 'default' | 'strict' | 'bypass') {
  switch (mode) {
    case 'default': return customPermissionHandler;
    case 'strict': return strictPermissionHandler;
    case 'bypass': return undefined;
  }
}
```

**Custom Permission Handler Example:**
```typescript
export async function customPermissionHandler(
  toolName: string,
  input: ToolInput,
  options: PermissionHandlerOptions
): Promise<PermissionResult> {
  // Read-only tools always allowed
  if (['Read', 'Glob', 'Grep'].includes(toolName)) {
    return { behavior: 'allow', updatedInput: input };
  }

  // Check dangerous patterns for Bash
  if (toolName === 'Bash') {
    const { dangerous, pattern } = isDangerousCommand(input.command);
    if (dangerous) {
      return { behavior: 'deny', message: `Blocked: ${pattern}` };
    }
  }

  return { behavior: 'allow', updatedInput: input };
}
```

### 2.6 MCP Server Configuration

**Location:** `/agentic-flow/config/.mcp.json`

```json
{
  "mcpServers": {
    "claude-flow": {
      "command": "npx",
      "args": ["claude-flow@alpha", "mcp", "start"],
      "type": "stdio"
    }
  }
}
```

**User-level MCP Config (`~/.agentic-flow/mcp-config.json`):**
```json
{
  "servers": {
    "custom-server": {
      "enabled": true,
      "command": "/path/to/server",
      "args": ["--port", "8080"],
      "env": { "API_KEY": "xxx" }
    }
  }
}
```

---

## 3. ReasoningBank Configuration

**Location:** `/agentic-flow/src/reasoningbank/config/reasoningbank.yaml`

Sophisticated memory/learning configuration with algorithms for:

```yaml
reasoningbank:
  version: "1.0.0"

  # Retrieval Configuration (Algorithm 1)
  retrieve:
    k: 3                    # Top-k memories to inject
    alpha: 0.65             # Semantic similarity weight
    beta: 0.15              # Recency weight
    gamma: 0.20             # Reliability weight
    delta: 0.10             # Diversity penalty (MMR)

  # Embedding Configuration
  embeddings:
    provider: "local"       # claude | openai | huggingface | local
    model: "Xenova/all-MiniLM-L6-v2"
    dimensions: 384

  # Judge Configuration (Algorithm 2)
  judge:
    model: "claude-sonnet-4-5-20250929"
    temperature: 0

  # Distillation Configuration (Algorithm 3)
  distill:
    max_items_per_trajectory: 3
    redact_pii: true
    redact_patterns:
      - '\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'  # emails
      - '\b(?:sk-[a-zA-Z0-9]{48})\b'  # API keys

  # Consolidation Configuration (Algorithm 4)
  consolidate:
    enabled: true
    contradiction_threshold: 0.60

  # MaTTS Configuration (Algorithm 5)
  matts:
    parallel:
      k: 6                  # Parallel rollouts
    sequential:
      r: 3                  # Refinement iterations

  # Feature Flags
  features:
    enable_pre_task_hook: true
    enable_post_task_hook: true
    enable_contradiction_detection: true
```

---

## 4. Docker/Deployment Configuration

**Location:** `/docker/configs/`

Model-specific configurations for deployment:

```yaml
# claude.yaml
name: claude-sonnet-4
provider: anthropic

model:
  id: claude-sonnet-4
  temperature: 0.7
  max_tokens: 4096

cloudrun:
  memory: 2Gi
  cpu: 2
  timeout: 3600
  max_instances: 10
  min_instances: 0

secrets:
  - name: ANTHROPIC_API_KEY
    key: anthropic-api-key
    version: latest

mcp:
  enabled: true
  servers:
    - claude-flow
    - flow-nexus

cost:
  input_cost_per_1k: 0.003
  output_cost_per_1k: 0.015
```

---

## 5. Code Quality Configuration

**Location:** `/config/`

Strict code quality enforcement:

```javascript
// .eslintrc.strict.cjs
module.exports = {
  rules: {
    '@typescript-eslint/no-explicit-any': 'error',
    '@typescript-eslint/explicit-function-return-type': 'error',
    'complexity': ['error', { max: 15 }],
    'max-lines-per-function': ['error', { max: 150 }],
    'max-params': ['error', 5],
    'no-eval': 'error',
    // ...
  }
};
```

---

## 6. What Could Be Lifted/Shipped for Nancy

### 6.1 High-Value Patterns

| Component | Value for Nancy | Effort |
|-----------|----------------|--------|
| **Router Configuration** | Multi-model routing with fallback chains | Medium |
| **Plugin System** | Extensible tool loading (local, npm, remote) | Medium |
| **Hooks Bridge** | SDK event integration | High |
| **Permission Handler** | Pattern-based security | Low |
| **Agent Definitions** | Markdown + YAML frontmatter | Low |
| **Environment Templates** | Variable substitution with defaults | Low |

### 6.2 Specific Components to Adopt

**1. Configuration Loading Pattern:**
```typescript
// Cascading config resolution
const paths = [
  configPath,                                    // Explicit
  process.env.NANCY_CONFIG,                      // Environment
  join(homedir(), '.nancy', 'config.json'),      // User
  join(process.cwd(), 'nancy.config.json'),      // Project
];

// Environment substitution
function substituteEnvVars(obj: any): any {
  if (typeof obj === 'string') {
    return obj.replace(/\$\{([^}]+)\}/g, (_, key) => {
      const [varName, defaultValue] = key.split(':-');
      return process.env[varName] || defaultValue || '';
    });
  }
  // ... recurse for objects/arrays
}
```

**2. Plugin Architecture:**
- Support local, npm, and inline plugins
- Plugin tool schema validation
- Enable/disable without unloading
- Registry with lifecycle management

**3. Permission Patterns:**
- Dangerous command detection (regex patterns)
- Blocked path lists
- Audit logging
- Multiple permission modes

**4. Agent Definition Format:**
```markdown
---
name: skill-name
type: developer
description: Short description
capabilities:
  - capability_1
  - capability_2
hooks:
  pre: |
    # Pre-execution hook
  post: |
    # Post-execution hook
---

# System Prompt Content
```

### 6.3 Implementation Recommendations

1. **Start with Environment Config:**
   - Implement `${VAR:-default}` syntax
   - Support cascading file resolution
   - Add validation at load time

2. **Add Plugin System:**
   - Begin with inline plugins only
   - Add npm loading later
   - Remote plugins last (with checksum)

3. **Hooks Integration:**
   - Map to nancy's existing skill system
   - Focus on PreToolUse and PostToolUse
   - Add trajectory tracking for learning

4. **Permission Handler:**
   - Port dangerous pattern list
   - Add audit logging to existing logging
   - Support bypass mode for automation

---

## 7. Strengths & Weaknesses

### 7.1 Strengths

1. **Comprehensive Configuration System**
   - Multiple resolution layers
   - Environment variable substitution with defaults
   - Type-safe TypeScript interfaces
   - Validation at load time

2. **Flexible Extension Model**
   - Four plugin loading mechanisms
   - Tool-based extension API
   - Hooks for all SDK events
   - Provider abstraction layer

3. **Security-Conscious Design**
   - Pattern-based dangerous command detection
   - Blocked path lists
   - Audit logging
   - Multiple permission modes
   - Checksum verification for remote plugins

4. **Multi-Model Support**
   - Six providers out of box
   - Rule-based routing
   - Cost optimization
   - Performance tracking
   - Fallback chains

5. **Operator-Friendly**
   - Docker deployment configs
   - Cloud Run integration
   - Health checks
   - Metrics collection

### 7.2 Weaknesses

1. **Complexity**
   - Many configuration files across directories
   - Overlapping configuration mechanisms
   - Steep learning curve

2. **Documentation Gaps**
   - Plugin API not fully documented
   - Some config options undocumented
   - Examples scattered across codebase

3. **Coupling**
   - Heavy dependency on Claude SDK
   - Tight coupling with MCP servers
   - Some circular import handling needed

4. **Incomplete Features**
   - Some providers marked TODO
   - WASM modules placeholder
   - Some hooks not fully implemented

5. **Testing Coverage**
   - Many test files but unclear coverage
   - Some integration tests incomplete
   - Plugin system lacks test examples

---

## 8. Key Insights for Nancy

### 8.1 Architecture Patterns

1. **Layered Configuration** - Agentic-flow's cascading config is excellent. Nancy should adopt:
   - Project-level config
   - User-level config (~/.nancy/)
   - Environment overrides
   - Programmatic overrides

2. **Plugin vs Skills** - The plugin/tool model maps well to nancy's skills:
   - Plugins = Skills
   - PluginTools = Skill actions
   - Enable/disable = Skill activation

3. **Hooks as Extension Points** - Nancy already has hooks; could enhance with:
   - Trajectory tracking
   - Pattern learning
   - Tool-specific hooks

### 8.2 What Nancy Does Better

1. **Simplicity** - Nancy's bash-first approach is more accessible
2. **Session Management** - Nancy has stronger session persistence
3. **Planning System** - Nancy's SPEC/PLAN/ROADMAP is more structured
4. **Git Integration** - Nancy's git workflow is more opinionated/helpful

### 8.3 What to Adopt

1. **Environment variable substitution** with `${VAR:-default}` syntax
2. **Permission patterns** for dangerous command detection
3. **Agent definition format** (YAML frontmatter + markdown)
4. **Multi-provider configuration** structure (even if not multi-model yet)
5. **Audit logging** pattern for security compliance

---

## 9. File Reference

| File | Purpose |
|------|---------|
| `/config/README.md` | Code quality config overview |
| `/config/.env.example` | Healthcare system env template |
| `/config/healthcare-system.config.ts` | Domain-specific config example |
| `/agentic-flow/config/router.config.json` | Multi-model routing config |
| `/agentic-flow/config/.mcp.json` | MCP server definitions |
| `/agentic-flow/config/.env.example` | Core environment template |
| `/agentic-flow/src/config/claudeFlow.ts` | Claude Flow integration config |
| `/agentic-flow/src/config/tools.ts` | Tool configuration |
| `/agentic-flow/src/config/quic.ts` | QUIC transport config |
| `/agentic-flow/src/sdk/plugins.ts` | Plugin system implementation |
| `/agentic-flow/src/sdk/hooks-bridge.ts` | SDK hooks integration |
| `/agentic-flow/src/sdk/permission-handler.ts` | Permission control |
| `/agentic-flow/src/router/router.ts` | Multi-model router core |
| `/agentic-flow/src/router/types.ts` | Router type definitions |
| `/agentic-flow/src/router/providers/*.ts` | Provider implementations |
| `/agentic-flow/src/reasoningbank/config/reasoningbank.yaml` | Learning config |
| `/.claude/agents/**/*.md` | Agent definitions |
| `/docker/configs/*.yaml` | Deployment configs |

---

## 10. Summary

Agentic-flow provides a mature, enterprise-grade configuration and extensibility system. The key takeaways for Nancy are:

1. **Adopt the cascading config pattern** with environment substitution
2. **Port the permission handler patterns** for improved security
3. **Consider the agent definition format** for skill definitions
4. **Evaluate the plugin architecture** for future extensibility
5. **Learn from the provider abstraction** for potential multi-model support

The system is complex but well-designed. Nancy should cherry-pick specific patterns rather than wholesale adoption, focusing on areas that enhance its bash-first, simplicity-oriented design philosophy.
