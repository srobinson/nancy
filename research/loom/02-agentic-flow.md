# AGENTIC FLOW SYSTEM RESEARCH DOCUMENT

## 1. OVERVIEW - What is the Agentic Flow System?

Loom implements a **state machine-driven agentic flow** centered on the `Agent` type in `loom-common-core`. The system orchestrates a conversation between:
- **User Input** (messages)
- **LLM Processing** (Anthropic/OpenAI)
- **Tool Execution** (file ops, bash, etc.)
- **Feedback Loop** (results back to LLM)

The flow is **event-driven** with explicit state transitions, making it reliable and observable. There's no implicit flow orchestration - every step is traced and logged.

**Core Philosophy**: Treat agent execution like a state machine where each state handles specific events and emits deterministic actions.

---

## 2. FLOW DEFINITION - How Flows are Specified

### Agent Configuration (Declarative)
**File**: `crates/loom-common-core/src/config.rs`

Flows are defined through `AgentConfig`:
```rust
pub struct AgentConfig {
    pub model_name: String,           // "claude-opus-4-20250514"
    pub max_retries: u32,             // 3
    pub tool_timeout: Duration,       // 30s
    pub llm_timeout: Duration,        // 120s
    pub max_tokens: u32,              // 4096
    pub temperature: Option<f32>,     // None (use default)
}
```

This is **pure configuration** - no DSL, no complex syntax. Flows are **code-driven** through the state machine API.

### Message Protocol (Structural)
Messages are role-based:
```rust
pub enum Role {
    System,       // System prompts
    User,         // User input
    Assistant,    // LLM responses
    Tool,         // Tool result outputs
}

pub struct Message {
    pub role: Role,
    pub content: String,
    pub tool_call_id: Option<String>,  // Links to ToolCall.id
    pub tool_calls: Vec<ToolCall>,     // Requested tool invocations
}

pub struct ToolCall {
    pub id: String,                    // Unique within response
    pub tool_name: String,             // "edit_file", "bash", etc.
    pub arguments_json: serde_json::Value,
}
```

**Key Design**: Conversation history is just `Vec<Message>` - no special structure. Tool results are Message objects with role=Tool and tool_call_id referencing the request.

---

## 3. EXECUTION MODEL - How Flows Run

### The Agent State Machine
**File**: `crates/loom-common-core/src/state.rs` + `src/agent.rs`

Seven states form the core flow:

```
WaitingForUserInput
    | [UserInput event]
CallingLlm
    | [TextDelta event] (streaming)
    | [Completed event]
ProcessingLlmResponse
    |-> ExecutingTools (if tool_calls present)
    |       | [ToolCompleted events]
    |       |-> PostToolsHook (if mutating tools)
    |       |   | [PostToolsHookCompleted]
    |       |   | [CallingLlm] (loop back)
    |       |-> CallingLlm (non-mutating tools)
    |-> WaitingForUserInput (no tools)
```

**Critical Detail**: Tool execution is **parallel-ready** but handled sequentially in the loop. The state tracks multiple `ToolExecutionStatus` (Pending -> Running -> Completed).

### Event-Driven Processing
**Type**: `AgentEvent` enum - fully enumerated possible transitions:
```rust
pub enum AgentEvent {
    UserInput(Message),
    LlmEvent(LlmEvent),                    // TextDelta, ToolCallDelta, Completed, Error
    ToolProgress(ToolProgressEvent),       // Progress tracking
    ToolCompleted { call_id, outcome },    // Success or Error
    PostToolsHookCompleted { action_taken },
    RetryTimeoutFired,
    ShutdownRequested,
}
```

**Every state transition is deterministic** - given (State, Event) -> returns (Action, NewState).

### Streaming & Feedback
**File**: `src/llm.rs`

```rust
pub enum LlmEvent {
    TextDelta { content: String },         // Streaming text
    ToolCallDelta { call_id, tool_name, arguments_fragment },
    Completed(LlmResponse),                // Final response
    Error(LlmError),                       // LLM failure
}

pub trait LlmClient {
    async fn complete(&self, request: LlmRequest) -> Result<LlmResponse, LlmError>;
    async fn complete_streaming(&self, request: LlmRequest) -> Result<LlmStream, LlmError>;
}
```

**Streaming is first-class** - UI receives text deltas immediately, tool calls are built incrementally.

---

## 4. AGENT PRIMITIVES - Core Building Blocks

### Conversation Context
```rust
pub struct ConversationContext {
    pub id: uuid::Uuid,           // Unique per conversation
    pub messages: Vec<Message>,   // Full history
}
```

Every state carries the conversation context + metadata (retries, pending requests, tool executions).

### Tool Execution Lifecycle
```rust
pub enum ToolExecutionStatus {
    Pending { call_id, tool_name, requested_at },
    Running { call_id, tool_name, started_at, progress: Option<ToolProgress> },
    Completed { call_id, tool_name, started_at, completed_at, outcome },
}

pub enum ToolExecutionOutcome {
    Success { call_id, output: serde_json::Value },
    Error { call_id, error: ToolError },
}
```

**Key feature**: Tools track timestamps and optional progress updates (fraction, message, units_processed).

### Error & Retry Strategy
```rust
pub enum ErrorOrigin {
    Llm,
    Tool,
    Io,
}

pub struct AgentState::Error {
    conversation: ConversationContext,
    error: AgentError,
    retries: u32,        // Current retry count
    origin: ErrorOrigin, // Determines retry policy
}
```

Retries are bounded by `config.max_retries` - hitting the limit returns to WaitingForUserInput with error displayed.

### Post-Tools Hook
**Innovation**: After mutating tools (edit_file, bash) succeed, agent transitions to PostToolsHook before calling LLM again.

```rust
pub struct AgentState::PostToolsHook {
    conversation: ConversationContext,
    pending_llm_request: LlmRequest,     // Queued for after hook
    completed_tools: Vec<CompletedToolInfo>,  // What was executed
}
```

This enables auto-commit, linting, or other side-effects before LLM sees results.

---

## 5. OBSERVATIONS - What Stands Out

### Observation 1: Explicit Over Implicit
- **No automatic tool selection** - LLM explicitly requests tools by name
- **No implicit retry loops** - Retries are explicit events (RetryTimeoutFired)
- **No hidden state mutations** - All state transitions logged with tool `tracing` crate

### Observation 2: Separation of Concerns
- `Agent` handles state machine only
- `LlmClient` trait abstracts LLM providers
- `ToolRegistry` abstracts tool implementations
- `ThreadStore` abstracts persistence
- `ACP Agent` bridges to editor protocol

**Testing benefit**: Each layer can be tested independently with mocks.

### Observation 3: Streaming-First Design
- Text deltas arrive immediately (not waiting for full response)
- Tool calls are constructed incrementally
- UI receives updates in real-time
- Stream can error mid-flight (handled gracefully)

### Observation 4: ACP (Agent Client Protocol) Integration
**File**: `crates/loom-cli-acp/src/agent.rs`

Loom implements the ACP Agent trait, making it a drop-in agent for Zed, VS Code, etc. The ACP wrapper:
- Maps editor sessions -> Loom threads
- Forwards tool outputs as session notifications
- Persists conversations to thread store
- Handles server queries (file reads, env vars, workspace context)

**Architecture**: Editor -> ACP Protocol -> LoomAcpAgent -> Core Agent State Machine -> LLM/Tools

### Observation 5: Tool Execution is Synchronous, But Error-Safe
- Tools execute in sequence (not truly parallel)
- Each tool completion triggers a check: "all done?"
- Only after all complete does agent transition to next state
- Mutating tools trigger hook before continuing

---

## 6. INSIGHTS - Patterns Worth Adopting

### Insight 1: State Machine as Source of Truth
Instead of implicit flow (agents "just work"), Loom uses explicit state and events. Benefits:
- **Debuggability**: Print state, see exactly where agent is
- **Testing**: Verify state transitions with property tests (proptest used extensively)
- **Observability**: Tracing emits state changes with context
- **Recovery**: Can pause/resume from any state (ThreadStore persists full state)

**For Nancy**: Track agent execution as state transitions, not implicit function calls.

### Insight 2: Configuration Over Code
AgentConfig is **serializable/deserializable** (serde). Can store in:
- YAML/TOML config files
- Environment variables
- Database records
- Sent over wire to remote executors

No hardcoded behavior - all tunable.

### Insight 3: Error Handling is Pragmatic
- Retries have limits (max_retries)
- Tools errors are returned, not panicked
- LLM errors transition to Error state (can retry)
- Invalid state transitions return WaitForInput (safe default)

**No silent failures** - errors are always visible to user.

### Insight 4: Hooks as Extension Points
PostToolsHook is a **pluggable opportunity** to run code after tools execute. Other systems could add:
- PreToolsHook
- PreLlmHook
- OnErrorHook

Nancy could hook auto-analysis, caching, batching, etc.

### Insight 5: Message History is Immutable API
Once a Message is added to conversation, it's not modified. Conversation grows only by append. This makes:
- Conversation history deterministic
- Replay/debug possible
- Thread persistence straightforward
- Concurrent reads safe

---

## 7. RECOMMENDATIONS - How Nancy Could Use Loom

### Recommendation 1: Adopt the State Machine Pattern
Nancy's flow orchestrator should be state-based:
```
WaitingForTask
  | [TaskReceived]
InitializingAgent
  | [AgentReady]
ExecutingFlow
  |-> WaitingForUserInput
  |-> CallingLlm
  |-> ExecutingTools
  |-> HandlingError
  | [FlowComplete]
ArchivingResults
```

Each state is explicit, transitions are logged, no magic.

### Recommendation 2: Implement Loom as a Flow Service
Instead of embedding Loom directly, use it as a **remote agent service**:
- Nancy sends structured flow specifications to Loom HTTP API
- Loom processes them, returns streaming results
- Nancy aggregates results and manages higher-level orchestration

**Benefits**:
- Decoupled from Loom version changes
- Can run Loom in sandboxed/remote environment
- Multiple Loom instances (load balance)
- Nancy focuses on flow composition, Loom focuses on agent execution

### Recommendation 3: Use ACP Protocol for Integration
Loom already implements ACP for editor integration. Nancy could:
- Implement ACP Server (accept agents from Loom)
- Nancy = Editor (sends prompts, receives results)
- Loom = Agent (executes tasks)

This would use existing, stable protocol instead of custom integration.

### Recommendation 4: Adopt Tool Registry Pattern
Nancy's tools should follow Loom's `Tool` trait:
```rust
pub trait Tool {
    async fn invoke(
        &self,
        args: serde_json::Value,
        ctx: &ToolContext,
    ) -> Result<serde_json::Value, ToolError>;
}
```

Tools are:
- Name + description (for LLM)
- JSON schema for inputs
- Executable async function
- Return JSON output

Register them in a `ToolRegistry` and pass to agents. Reusable across multiple agents/flows.

### Recommendation 5: Configuration-Driven Flows
Nancy flows should be **primarily YAML/JSON**, not code:

```yaml
name: "code-review-flow"
description: "Review pull requests"
agents:
  - name: "analyzer"
    config:
      model: "claude-opus"
      max_retries: 2
    tools:
      - "read_file"
      - "bash"
steps:
  - name: "analyze"
    trigger: "pr_received"
    agent: "analyzer"
  - name: "report"
    trigger: "analyze_complete"
    action: "send_comment"
```

Execute via Nancy's orchestrator, which delegates actual agent work to Loom.

### Recommendation 6: Leverage Thread Store Pattern
Loom's `ThreadStore` persists conversations. Nancy should adopt similar for:
- Experiment logs
- Task execution history
- User feedback/corrections
- Analytics data

Full audit trail of every decision and tool output.

### Recommendation 7: Streaming Output First
Nancy's UI should receive **streaming updates**, not batch results:
- Agent text appears as it streams
- Tool execution progress shown in real-time
- Errors displayed immediately
- No "loading..." spinners waiting for batch results

Use Server-Sent Events (SSE) or WebSockets for live updates.

---

## TECHNICAL SUMMARY

**Key Files to Reference**:
- `/Users/alphab/Dev/LLM/DEV/loom/crates/loom-common-core/src/agent.rs` - Core state machine (1416 lines, heavily tested)
- `/Users/alphab/Dev/LLM/DEV/loom/crates/loom-common-core/src/state.rs` - State & event types
- `/Users/alphab/Dev/LLM/DEV/loom/crates/loom-cli-acp/src/agent.rs` - ACP integration (700 lines)
- `/Users/alphab/Dev/LLM/DEV/loom/crates/loom-common-core/src/llm.rs` - LLM abstraction

**Dependencies to Consider**:
- `async_trait` - LLM/Tool async interfaces
- `tokio` - Async runtime
- `tracing` - Structured logging
- `serde_json` - Message/config serialization
- `proptest` - Property-based testing (used extensively)

**Maturity Level**: Loom's agent system is **production-ready** with:
- 1400+ lines of tests (unit + property tests)
- Comprehensive error handling
- Graceful shutdown support
- Session persistence
- Full streaming support

---

This research document demonstrates that Loom's agentic flow system is **fundamentally sound** and **highly portable**. Nancy can either:
1. **Embed Loom** (import crates directly)
2. **Use Loom as Service** (HTTP API or ACP protocol)
3. **Adopt Loom's Patterns** (state machine, tools, config, streaming)

All three approaches are viable depending on Nancy's architecture goals.
