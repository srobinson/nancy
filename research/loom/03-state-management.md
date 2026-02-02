# STATE MANAGEMENT IN LOOM

## Overview - State Management Philosophy

Loom implements a **distributed, multi-layered state management system** designed to handle agent conversations, tool execution, and server synchronization across multiple persistence boundaries. The architecture emphasizes:

1. **Event-driven state machines** - Agent states flow through well-defined transitions triggered by events
2. **Optimistic concurrency control** - Version-based conflict detection enables multi-client sync without locks
3. **Layered persistence** - Local JSON files, SQLite database, and server sync with fallback queues
4. **Snapshot serialization** - Complete state snapshots preserve agent execution context for recovery
5. **Async-first design** - Non-blocking background sync with local-first operation

## State Model - How State is Represented

### Agent State Machine (loom-common-core/src/state.rs)

The agent operates as a deterministic state machine with 7 primary states:

```rust
pub enum AgentState {
    WaitingForUserInput { conversation: ConversationContext },
    CallingLlm { conversation: ConversationContext, retries: u32 },
    ProcessingLlmResponse { conversation: ConversationContext, response: LlmResponse },
    ExecutingTools { conversation: ConversationContext, executions: Vec<ToolExecutionStatus> },
    PostToolsHook { conversation: ConversationContext, pending_llm_request, completed_tools },
    Error { conversation: ConversationContext, error, retries, origin },
    ShuttingDown,
}
```

**Key design patterns:**
- Every state except `ShuttingDown` preserves conversation history
- Retry counters track LLM failure recovery attempts
- Tool execution tracks 3 substates: Pending -> Running -> Completed
- Error state preserves the origin (Llm, Tool, Io) for retry logic

### Tool Execution Lifecycle (state.rs)

Tools transition through a non-Clone state machine:

```rust
pub enum ToolExecutionStatus {
    Pending { call_id, tool_name, requested_at: Instant },
    Running { call_id, tool_name, started_at, last_update_at, progress },
    Completed { call_id, tool_name, started_at, completed_at, outcome },
}
```

**Progress tracking:** Tools emit `ToolProgress` events with fraction (0.0-1.0), message, and units_processed fields. The agent collects these without state transitions.

### Thread State Snapshot (loom-common-thread/src/model.rs)

Threads represent persistent conversation sessions and serialize the **complete execution context**:

```rust
pub struct Thread {
    id: ThreadId,                          // T-{uuid7}
    version: u64,                          // Monotonic version for optimistic concurrency
    created_at, updated_at, last_activity_at: String,

    // Environment context
    workspace_root, cwd, loom_version: Option<String>,

    // Git metadata (for reproducibility)
    git_branch, git_remote_url: Option<String>,
    git_initial_branch, git_initial_commit_sha: Option<String>,
    git_current_commit_sha: Option<String>,
    git_start_dirty, git_end_dirty: Option<bool>,
    git_commits: Vec<String>,              // Chronological audit trail

    // LLM state
    provider, model: Option<String>,
    conversation: ConversationSnapshot,    // Complete message history
    agent_state: AgentStateSnapshot,       // Serialized state + pending tools

    // Access control
    visibility: ThreadVisibility,          // Organization|Private|Public
    is_private: bool,                      // Never syncs if true
    is_shared_with_support: bool,

    metadata: ThreadMetadata,              // User-defined tags, title, pinned status
}
```

**Snapshot design:** Every field that exists in runtime AgentState is captured, enabling perfect state reconstruction.

## Persistence - How State is Saved/Loaded

### Three-Layer Persistence Stack

```
+-------------------------------------------------------------+
|                     SERVER DATABASE                          |
|              (SQLite with JSON serialization)                |
|  - Optimistic versioning for conflict detection             |
|  - Denormalized columns (agent_state_kind, message_count)   |
|  - Full JSON blobs for backward compatibility               |
|  - Git metadata indices for searching by repo/branch        |
+-------------------------------------------------------------+
              ^ (SYNC - upsert)
              v (RETRY - pending_sync_queue)
+-------------------------------------------------------------+
|              PENDING SYNC QUEUE (Fallback)                  |
|  - Failed syncs tracked with retry count & error message    |
|  - Survives process restarts                                |
|  - JSON file: ~/.local/state/loom/sync/pending.json         |
+-------------------------------------------------------------+
              ^ (BACKGROUND SYNC or BLOCKING save_and_sync)
              v (LOCAL ONLY - JSON files)
+-------------------------------------------------------------+
|              LOCAL THREAD STORE (Atomic)                    |
|  - JSON files: ~/.local/share/loom/threads/{id}.json        |
|  - Atomic writes via temp-file + rename                     |
|  - Survives network outages completely                      |
|  - Private threads NEVER sync beyond this layer             |
+-------------------------------------------------------------+
```

### Local Persistence (loom-common-thread/src/store.rs)

**LocalThreadStore** provides atomic, reliable local persistence:

```rust
pub async fn save(&self, thread: &Thread) -> Result<(), ThreadStoreError> {
    tokio::fs::create_dir_all(&self.threads_dir).await?;
    let tmp_path = self.threads_dir.join(format!("{}.json.tmp", thread.id));
    let json = serde_json::to_string_pretty(thread)?;

    tokio::fs::write(&tmp_path, &json).await?;  // Write to temp
    tokio::fs::rename(&tmp_path, &path).await?;  // Atomic rename
    Ok(())
}
```

**Key patterns:**
- Write-then-rename ensures no partial file corruption
- Threads are stored as individual files, not a single DB
- Metadata extraction: `touch()` increments version + updates timestamps
- Search implemented via linear scan with title/tag/content matching

### Server Sync with Background Queue (sync.rs & pending_sync.rs)

**SyncingThreadStore** wraps LocalThreadStore with optional server sync:

```rust
pub async fn save(&self, thread: &Thread) -> Result<(), ThreadStoreError> {
    self.local.save(thread).await?;  // Always local first

    if !thread.is_private && self.sync_client.is_some() {
        tokio::spawn(async move {
            // Non-blocking background sync
            match client.upsert_thread(&thread).await {
                Ok(()) => { store.remove_pending(...).await; }
                Err(e) => { store.add_pending(..., Some(e.to_string())).await; }
            }
        });
    }
    Ok(())
}
```

**Private threads** (is_private=true) never sync beyond LocalThreadStore.

**Blocking sync** via `save_and_sync()` used for operations that exit immediately (e.g., share commands).

### Pending Sync Queue (pending_sync.rs)

Failed syncs are tracked with retry metadata:

```rust
pub struct PendingSyncEntry {
    thread_id: ThreadId,
    operation: SyncOperation,  // Upsert|Delete
    failed_at: String,         // RFC3339 timestamp
    retry_count: u32,
    last_error: Option<String>,
}
```

Queue is persisted to `~/.local/state/loom/sync/pending.json` and retried on:
1. Next `retry_pending()` call (manual retry)
2. Process restart (queue reloaded on startup)
3. Background sync task wakes

### Database Versioning (loom-server-db/src/thread.rs)

The server uses optimistic locking with version numbers:

```rust
pub async fn upsert(
    &self,
    thread: &Thread,
    expected_version: Option<u64>,
) -> Result<Thread, DbError> {
    if let Some(existing_thread) = self.get(&id).await? {
        if let Some(expected) = expected_version {
            if existing_thread.version != expected {
                return Err(DbError::Conflict(
                    format!("expected {}, found {}", expected, existing_thread.version)
                ));
            }
        }
        self.update(thread).await?;
    } else {
        self.insert(thread).await?;
    }
    Ok(self.get(&id).await?.unwrap())
}
```

**Storage strategy:**
- Denormalized columns for fast queries: agent_state_kind, message_count, title
- Full JSON blobs for complete history preservation
- Git metadata extracted into normalized tables for searching by repo/branch
- Soft deletes with `deleted_at IS NULL` filtering

## Recovery - Checkpoints, Rollback, Replay

### Agent State Recovery (agent.rs)

The agent is **fully recoverable from Thread snapshots** because:

1. **Conversation preservation:** All messages (User, Assistant, Tool) stored in ConversationSnapshot
2. **Tool execution tracking:** Pending tool calls captured in AgentStateSnapshot.pending_tool_calls
3. **Retry context:** Error state includes retry count and error details
4. **Deterministic transitions:** handle_event() is pure given the current state

**Recovery flow:**
```
Loaded Thread.agent_state -> reconstruct runtime AgentState
              |
         handle_event() continues from last state
              |
         Tool outputs re-injected via ToolCompleted events
              |
         Conversation continues as if uninterrupted
```

No explicit checkpoints needed - each save() call creates a checkpoint implicitly.

### Git Context for Audit & Reproducibility

Threads capture complete git state at session boundaries:

```rust
git_initial_branch: Option<String>,        // Branch when thread created
git_initial_commit_sha: Option<String>,    // Starting commit
git_current_commit_sha: Option<String>,    // Latest known commit
git_commits: Vec<String>,                  // All commits observed (chronological)
git_start_dirty: Option<bool>,             // Working tree state at start
git_end_dirty: Option<bool>,               // Working tree state at end
```

**Use cases:**
- Audit: Which code state did the AI agent observe?
- Reproducibility: Reset working tree to git_initial_commit_sha to recreate context
- Session analysis: Count commits via git_commits.len()
- Conflict detection: Detect uncommitted changes (git_start_dirty=true)

### No Explicit Rollback Mechanism

Loom **does not implement rollback** by design:

1. **Immutable history:** Conversations are append-only (messages never deleted)
2. **Version mismatch handling:** Optimistic concurrency detects conflicts but requires manual resolution
3. **Git as source of truth:** Code changes live in Git history, not Loom state
4. **Async recovery:** Background processes retry failed syncs indefinitely

Instead, **replay is built in:**
- Load any historical Thread snapshot via server API
- Reconstruct agent state from snapshot
- Resume conversation from that point

### Session Recovery on Restart

On application restart:

1. Load LocalThreadStore (all .json files in ~/.local/share/loom/threads/)
2. Reconstruct Agent from latest Thread
3. Resume from agent_state (may be WaitingForUserInput if idle, or CallingLlm if mid-request)
4. Retry pending syncs via PendingSyncStore.retry_pending()

Pending operations survive process crashes because:
- **Local saves are atomic** (write then rename)
- **Pending queue persists to disk** before returning from save()
- **Background sync tasks are spawned** but failures recorded

## Observations - What Stands Out

### 1. Local-First, Sync-Opportunistic Architecture
Every operation succeeds locally even if server is unreachable. Sync happens in background with automatic retry. This is radically different from many systems that fail synchronously on network errors.

**Impact for Nancy:** We can operate fully offline. Sync conflicts are handled gracefully, not as fatal errors.

### 2. Version Numbers for Optimistic Concurrency Without Locks
Thread.version increments on every touch(). Server detects conflicts via version mismatches, not via locking. This scales to high concurrency with zero blocking.

**Pattern:** Extremely clean conflict detection. No database transactions needed.

### 3. Git Metadata as Execution Context
Threads capture the *exact* git state during agent execution. This is extraordinarily valuable for:
- Proving which code the agent saw
- Reproducing the agent's environment
- Auditing code changes
- Session analysis

**Insight:** State without context (what branch? what commit?) is nearly useless for AI agents working on code.

### 4. Serialization Discipline
Every complex state (AgentState, ToolExecutionStatus) has corresponding snapshot types that implement Serialize/Deserialize. This enables:
- Database storage of runtime state
- API serialization
- Backward compatibility

**Key design:** Runtime types (with Instant fields) are NOT Clone, but snapshot types ARE fully serializable.

### 5. No Explicit Checkpoint/Rollback
Instead of checkpoints, Loom uses:
- Immutable conversation history (append-only)
- Version-based conflict detection
- Git history as ground truth
- Replay from any saved snapshot

**Philosophy:** Simplicity trumps explicit recovery. Never delete, just version.

### 6. Private Threads Never Leave Local
`is_private=true` threads never sync beyond LocalThreadStore. This is a hard boundary enforced at the sync layer:

```rust
if !thread.is_private {
    // sync to server
}
```

**Trust model:** Even if cloud sync fails, private threads stay private. No silent failures.

### 7. Pending Queue Survives Crashes
Failed syncs are recorded to disk immediately, indexed by (thread_id, operation). Process restart automatically retries. This is transparent fault recovery.

**Robustness:** Can't lose work, even under catastrophic failures.

## Insights - Patterns Worth Adopting

### 1. Three-Layer Persistence Stack
Rather than choosing "local OR server", use:
1. Fast local write (atomic JSON files)
2. Background async sync with fallback queue
3. Server as permanent storage

**For Nancy:**
- Session state -> local JSON
- Sync to server in background
- If offline, queue the sync
- If sync fails, retry indefinitely

### 2. Version-Based Optimistic Locking
Instead of pessimistic locks, use monotonically increasing version numbers on records. Clients send the version they expect; server rejects if it doesn't match.

**For Nancy:**
```rust
pub struct AgentSession {
    id: SessionId,
    version: u64,  // Increment on every save
    state: AgentState,
    conversation: Vec<Message>,
}

async fn save(session: &AgentSession, expected_version: u64) -> Result<(), Conflict> {
    if stored.version != expected_version {
        return Err(Conflict);
    }
    stored.version += 1;
    // ... update
}
```

### 3. Snapshot Serialization for Recovery
Create "snapshot" types parallel to runtime types. Runtime types stay simple (no Serialize). Snapshot types handle persistence.

**For Nancy:**
```rust
// Runtime (not Clone, complex)
pub enum AgentState { ... }

// Snapshot (fully serializable)
pub struct AgentStateSnapshot {
    kind: AgentStateKind,
    retries: u32,
    last_error: Option<String>,
}

impl From<&AgentState> for AgentStateSnapshot { ... }
```

### 4. Atomic Write-Then-Rename
When writing files, write to `.tmp` first, then rename. This prevents partial writes even if the process crashes mid-write.

**For Nancy:**
```rust
let tmp = path.with_extension("tmp");
tokio::fs::write(&tmp, &data).await?;
tokio::fs::rename(&tmp, &path).await?;
```

### 5. Execution Context in State Records
Store more than just agent state. Include:
- Git metadata (branch, commit, dirty status)
- Environment (workspace root, cwd, loom version)
- Timestamps (created, updated, last activity)
- Access control (visibility, is_private)

**For Nancy:** Beyond just state snapshots, store the *context* in which work happened.

### 6. Immutable Conversation History
Messages are append-only. Never delete or edit. Index with version numbers if needed.

**For Nancy:**
- User messages: never deleted
- Assistant responses: never deleted
- Tool results: never deleted
- Index by version to find "state at commit X"

### 7. Deterministic Event Handlers
State transitions should be pure functions of (current_state, event). No side effects. This enables:
- Replay from saved states
- Testing without mocks
- Deterministic recovery

**For Nancy:**
```rust
impl Agent {
    pub fn handle_event(&mut self, event: AgentEvent) -> AgentAction {
        // Pure function: state + event -> new state + action
        // No I/O, no randomness, no side effects
        match (&self.state, event) {
            (State::WaitingForUserInput, Event::UserInput(msg)) => {
                self.state = State::CallingLlm { ... };
                AgentAction::SendLlmRequest(...)
            }
            // ...
        }
    }
}
```

### 8. Automatic Retry Without Exponential Backoff
Loom retries failed syncs indefinitely. For network transients, this is better than giving up after N retries.

**For Nancy:** If sync fails, keep the pending entry and retry on next startup or manual trigger.

## Recommendations - State Management Ideas for Nancy

### 1. Adopt Thread as the Session Model
Repurpose Loom's Thread model for Nancy sessions:

```rust
pub struct NancySession {
    id: SessionId,              // Nancy-{uuid7}
    version: u64,

    // Execution context
    created_at, updated_at: String,
    project_name: Option<String>,
    directory: String,

    // Agent state
    state: AgentStateSnapshot,
    messages: Vec<MessageSnapshot>,

    // Sync metadata
    is_private: bool,
    visibility: SessionVisibility,  // Server|Local|Private
}
```

### 2. Implement Version-Optimistic Sync
Create a SyncingSessionStore similar to loom-common-thread/src/sync.rs:

```rust
pub struct SyncingSessionStore {
    local: LocalSessionStore,
    sync_client: Option<ServerSyncClient>,
    pending_store: PendingSyncStore,
}

impl SyncingSessionStore {
    async fn save(&self, session: &NancySession) -> Result<(), Error> {
        self.local.save(session).await?;

        if !session.is_private {
            tokio::spawn(background_sync(session.clone()));
        }

        Ok(())
    }
}
```

### 3. Track Execution Context
Beyond state, record:
- Directory at session start
- Git branch and commit (if applicable)
- Project metadata
- Environment variables (sanitized)
- Worker count and configuration

### 4. Use Atomic Writes for All Persistence
All file writes use write-then-rename pattern. This is cheap and eliminates corruption.

### 5. Implement Search via Git Metadata
Like Loom, extract and index:
- Branch name (for filtering sessions by branch)
- Commit SHA (for correlating sessions with code history)
- Directory (for filtering by project)

### 6. Never Delete, Always Version
- Session messages are append-only
- Snapshots are timestamped
- Version history enables "state at time T"
- Soft deletes with is_deleted flag

### 7. Recovery by Replay
Don't restore to exact state. Instead:
1. Load last saved session snapshot
2. Reconstruct agent from snapshot
3. Resume work from there
4. Conversation history preserved for audit

### 8. Pending Queue for Offline Work
Sessions can be created, modified, and deleted offline. Sync happens when possible. Pending queue survives crashes.

### 9. Conflict Resolution Strategy
When server version != expected version:
1. Fetch server version
2. Merge: keep conversation history, use server state for agent position
3. Retry sync with new version
4. Report conflict to user

### 10. Private Sessions Never Sync
Hard boundary: `is_private=true` never touches server. Users can opt sessions into sync explicitly.

---

**Summary:** Loom's state management is remarkably simple: immutable history + versioned snapshots + opportunistic sync with fallback. This is far more robust than traditional "atomic transactions" for distributed systems. Adopting these patterns in Nancy would give us offline-first operation, crash safety, and easy recovery.
