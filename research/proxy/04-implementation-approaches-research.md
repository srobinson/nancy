# Implementation Approaches for Request/Response Monitoring

> Research on practical implementation approaches for adding request/response monitoring to CLI tools that use the Claude API

**Date:** 2026-01-26
**Context:** Nancy orchestration framework - Adding visibility into Claude API calls for debugging and optimization

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Current Nancy Architecture](#current-nancy-architecture)
3. [Implementation Approaches](#implementation-approaches)
4. [Configuration Patterns](#configuration-patterns)
5. [Performance Considerations](#performance-considerations)
6. [File Watching & Real-Time Display](#file-watching--real-time-display)
7. [Recommended Approach](#recommended-approach)
8. [Integration Plan](#integration-plan)
9. [References](#references)

---

## Executive Summary

After analyzing Nancy's existing architecture and researching current API monitoring patterns, I've identified four primary approaches for implementing request/response monitoring:

1. **OpenTelemetry Integration** - Enterprise-grade observability (complex, overkill for Nancy)
2. **Local Proxy Layer** - Transparent HTTP interception (requires infrastructure changes)
3. **JSONL File Watching** - Monitor existing session logs (Nancy already does this for tokens)
4. **CLI Driver Wrapper** - Add monitoring hooks at the CLI invocation layer (cleanest fit)

**Recommendation:** Use approach #3 (JSONL watching) as the foundation, enhanced with approach #4 (driver wrappers) for pre-request hooks. This leverages Nancy's existing token-watching infrastructure and requires minimal architectural changes.

---

## Current Nancy Architecture

### How Nancy Executes Claude Code

```
┌─────────────────────────────────────────────────────────────────┐
│ cmd::start (src/cmd/start.sh)                                   │
│  - Iteration loop                                               │
│  - Renders prompt from template                                 │
│  - Calls cli::run_prompt                                        │
└───────────────────────────┬─────────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────────┐
│ cli::run_prompt (src/cli/drivers/claude.sh)                     │
│  - Generates session UUID                                       │
│  - Sets up args array                                           │
│  - Calls: claude --session-id UUID -p prompt                    │
│  - Pipes output through _claude_format_stream                   │
│  - Copies session JSONL to task dir                             │
└───────────────────────────┬─────────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────────┐
│ Claude CLI (external binary)                                    │
│  - Makes API calls to Claude API                                │
│  - Writes session JSONL to:                                     │
│    ~/.claude/projects/<encoded-path>/<uuid>.jsonl              │
└───────────────────────────┬─────────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────────┐
│ Session JSONL Format                                            │
│  - One JSON object per line                                     │
│  - Contains: requests, responses, tool calls, usage             │
│  - Nancy copies to: $TASK_DIR/session-state/*.jsonl            │
└─────────────────────────────────────────────────────────────────┘
```

### Existing Monitoring Infrastructure

Nancy already has a sophisticated file-watching system for tokens:

```bash
# src/notify/watcher.sh
notify::watch_tokens_bg() {
  # Uses tail -F to follow JSONL file
  tail -n 0 -F "$jsonl_file" | while IFS= read -r line; do
    if token::update "$task" "$line"; then
      # Process token thresholds
      # Send alerts via comms API
    fi
  done
}
```

**Key Insight:** Nancy already tails the session JSONL in real-time to extract token usage. We can extend this pattern for full request/response monitoring.

---

## Implementation Approaches

### Approach 1: OpenTelemetry Integration

**Description:** Configure Claude Code to export telemetry via OpenTelemetry protocol.

```
┌──────────────┐     OTLP      ┌──────────────┐
│ Claude Code  ├──────────────▶│  OTEL        │
│ (with env    │   (metrics    │  Collector   │
│  vars set)   │    & logs)    │              │
└──────────────┘               └──────┬───────┘
                                      │
                              ┌───────▼────────┐
                              │  Backend       │
                              │  (Arize,       │
                              │   Honeycomb)   │
                              └────────────────┘
```

**Configuration:**
```bash
export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_METRICS_EXPORTER=otlp
export OTEL_LOGS_EXPORTER=otlp
export OTEL_LOG_USER_PROMPTS=1  # Enable prompt logging
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318
```

**Pros:**
- Industry standard observability protocol
- Rich metrics and events
- Powerful analysis tools (if using backend)
- Used by Claude Code team internally

**Cons:**
- CRITICAL LIMITATION: No way to log Claude's responses (only prompts)
- Requires external backend infrastructure (Arize, Honeycomb, Phoenix)
- Complex setup for local development
- Overkill for Nancy's use case
- Privacy concerns with prompt logging

**Verdict:** Not suitable for Nancy. The inability to log responses is a dealbreaker.

**Sources:**
- [Claude Code Docs - Monitoring](https://code.claude.com/docs/en/monitoring-usage)
- [Claude Code Observability and Tracing](https://arize.com/blog/claude-code-observability-and-tracing-introducing-dev-agent-lens/)
- [Can Claude Code Observe Its Own Code?](https://www.honeycomb.io/blog/can-claude-code-observe-its-own-code)

---

### Approach 2: Local Proxy Layer

**Description:** Route Claude Code API calls through a local proxy that logs requests/responses.

```
┌──────────────┐   HTTP(S)   ┌──────────────┐   HTTPS   ┌──────────────┐
│ Claude Code  ├────────────▶│  Proxy       ├──────────▶│ Claude API   │
│              │             │  (mitmproxy, │           │              │
│              │◀────────────│   LiteLLM)   │◀──────────│              │
└──────────────┘             └──────┬───────┘           └──────────────┘
                                    │
                             ┌──────▼──────┐
                             │ Log Request │
                             │ Log Response│
                             └─────────────┘
```

**Implementation Options:**

#### Option A: mitmproxy (HTTP interception)
```bash
# Start proxy
mitmproxy --mode reverse:https://api.anthropic.com --listen-port 8080 \
  --save-stream-file requests.jsonl

# Configure Claude Code
export https_proxy=http://localhost:8080
export REQUESTS_CA_BUNDLE=/path/to/mitmproxy-ca-cert.pem
```

#### Option B: LiteLLM Proxy (AI-specific)
```bash
# Start LiteLLM proxy with logging
litellm --model claude-sonnet-4-5 \
  --api_base https://api.anthropic.com \
  --debug \
  --callbacks langfuse  # Or custom callback
```

#### Option C: Custom Node.js Proxy
```javascript
// Using http-proxy-middleware
const { createProxyMiddleware } = require('http-proxy-middleware');

const proxy = createProxyMiddleware({
  target: 'https://api.anthropic.com',
  changeOrigin: true,
  onProxyReq: (proxyReq, req, res) => {
    // Log request
    console.log('REQUEST:', req.method, req.path);
  },
  onProxyRes: (proxyRes, req, res) => {
    // Log response
    console.log('RESPONSE:', proxyRes.statusCode);
  }
});
```

**Pros:**
- Complete visibility into all HTTP traffic
- Can inspect both requests and responses
- Works transparently with any HTTP client
- Can modify requests/responses on the fly

**Cons:**
- Requires SSL certificate setup (for HTTPS)
- Adds latency to every request
- Can break with certificate pinning
- Complex infrastructure for local dev
- Requires process management (proxy must be running)

**Verdict:** Powerful but heavyweight. Too much infrastructure overhead for Nancy's needs.

**Sources:**
- [Build a Node.js API Proxy](https://dev.to/dashsaurabh/build-a-nodejs-api-proxy-to-supercharge-your-backend-42f3)
- [Proxy in Node.js: 5 Common Setup Methods](https://www.webshare.io/academy-article/node-js-proxy)

---

### Approach 3: JSONL File Watching (Recommended)

**Description:** Monitor the session JSONL file that Claude Code writes automatically.

```
┌──────────────────────────────────────────────────────────────┐
│ Claude CLI writes session JSONL                              │
│ ~/.claude/projects/<project>/<uuid>.jsonl                    │
└───────────────────────┬──────────────────────────────────────┘
                        │
                        │ Copied to Nancy task dir
                        ▼
┌──────────────────────────────────────────────────────────────┐
│ $TASK_DIR/session-state/nancy-TASK-iterN.jsonl              │
└───────────────────────┬──────────────────────────────────────┘
                        │
                        │ tail -F (real-time)
                        ▼
┌──────────────────────────────────────────────────────────────┐
│ notify::watch_session_bg                                     │
│  - Parses each JSON line                                     │
│  - Extracts requests, responses, tool calls                  │
│  - Writes to separate log files                              │
│  - Updates UI/alerts as needed                               │
└──────────────────────────────────────────────────────────────┘
```

**JSONL Format Analysis:**

Claude Code's session JSONL contains rich data:

```json
// System init event
{
  "type": "system",
  "subtype": "init",
  "model": "claude-sonnet-4-5-20250929",
  "timestamp": "2025-01-26T12:00:00.000Z"
}

// Assistant message (includes request context)
{
  "type": "assistant",
  "message": {
    "model": "claude-sonnet-4-5-20250929",
    "content": [
      {
        "type": "text",
        "text": "I'll help you with that..."
      },
      {
        "type": "tool_use",
        "id": "toolu_123",
        "name": "Read",
        "input": {"file_path": "/path/to/file"}
      }
    ],
    "usage": {
      "input_tokens": 5000,
      "output_tokens": 150,
      "cache_creation_input_tokens": 0,
      "cache_read_input_tokens": 3000
    }
  },
  "timestamp": "2025-01-26T12:00:05.000Z"
}

// User message (tool results)
{
  "type": "user",
  "message": {
    "content": [
      {
        "type": "tool_result",
        "tool_use_id": "toolu_123",
        "content": "File contents here..."
      }
    ]
  },
  "timestamp": "2025-01-26T12:00:06.000Z"
}

// Result event (session end)
{
  "type": "result",
  "subtype": "success",
  "total_cost_usd": 0.05,
  "duration_ms": 5000,
  "timestamp": "2025-01-26T12:00:10.000Z"
}
```

**Implementation:**

```bash
# src/notify/watcher.sh (new function)
notify::watch_session_bg() {
  local task="$1"
  local iteration="$2"

  local session_id="nancy-${task}-iter${iteration}"
  local jsonl_file="$NANCY_TASK_DIR/$task/logs/${session_id}.log"
  local monitor_log="$NANCY_TASK_DIR/$task/logs/api-monitor.log"

  # Start watcher in background
  (
    tail -n 0 -F "$jsonl_file" 2>/dev/null | while IFS= read -r line; do
      # Extract event type
      local event_type=$(echo "$line" | jq -r '.type // empty')

      case "$event_type" in
        assistant)
          # Log assistant message (response from Claude)
          echo "$line" | jq '{
            timestamp,
            model: .message.model,
            content: .message.content,
            usage: .message.usage
          }' >> "$monitor_log.responses.jsonl"

          # Extract token usage (already done by token watcher)
          token::update "$task" "$line"
          ;;

        user)
          # Log user message (tool results sent to Claude)
          echo "$line" | jq '{
            timestamp,
            tool_results: [.message.content[] | select(.type == "tool_result")]
          }' >> "$monitor_log.tool-results.jsonl"
          ;;

        result)
          # Log session result
          echo "$line" | jq '{
            timestamp,
            status: .subtype,
            cost: .total_cost_usd,
            duration_ms
          }' >> "$monitor_log.sessions.jsonl"
          ;;
      esac
    done
  ) &

  echo $! > "$NANCY_TASK_DIR/$task/.session_watcher_pid"
}
```

**Pros:**
- ZERO infrastructure changes required
- Leverages Nancy's existing file-watching pattern
- All data already available in JSONL
- Real-time monitoring with tail -F
- No performance overhead (passive monitoring)
- Works with both streaming and non-streaming modes
- No SSL/proxy complexity

**Cons:**
- Can only monitor after Claude Code writes data
- No pre-request hooks (can't inspect before API call)
- Tied to Claude Code's JSONL format (could change)
- Can't intercept or modify requests

**Verdict:** Best fit for Nancy. Minimal code changes, leverages existing patterns, no infrastructure overhead.

---

### Approach 4: CLI Driver Wrapper

**Description:** Add monitoring hooks directly in Nancy's CLI driver layer.

```
┌──────────────────────────────────────────────────────────────┐
│ cli::run_prompt (src/cli/drivers/claude.sh)                  │
│   ┌──────────────────────────────────────────────────────┐   │
│   │ 1. PRE-REQUEST HOOK                                  │   │
│   │    - Log prompt text                                 │   │
│   │    - Log model, args, timestamp                      │   │
│   │    - Write to $TASK_DIR/logs/api-requests.jsonl     │   │
│   └──────────────────────────────────────────────────────┘   │
│                           │                                   │
│                           ▼                                   │
│   ┌──────────────────────────────────────────────────────┐   │
│   │ 2. EXECUTE CLAUDE CLI                                │   │
│   │    claude --session-id UUID -p "$prompt"            │   │
│   └──────────────────────────────────────────────────────┘   │
│                           │                                   │
│                           ▼                                   │
│   ┌──────────────────────────────────────────────────────┐   │
│   │ 3. POST-REQUEST HOOK                                 │   │
│   │    - Log exit code                                   │   │
│   │    - Log duration                                    │   │
│   │    - Trigger JSONL copy                              │   │
│   └──────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
```

**Implementation:**

```bash
# src/cli/drivers/claude.sh (modified)
cli::run_prompt() {
  local prompt_text="$1"
  local nancy_session_id="$2"
  local export_file="$3"
  local NANCY_TASK_DIR="$4"
  local model="${NANCY_MODEL:-}"

  # Generate UUID for this Claude session
  local uuid
  uuid=$(uuid::generate)

  # --- PRE-REQUEST HOOK ---
  if [[ "${NANCY_API_MONITOR_ENABLED:-false}" == "true" ]]; then
    api_monitor::log_request \
      "$nancy_session_id" \
      "$uuid" \
      "$model" \
      "$prompt_text" \
      "$NANCY_TASK_DIR"
  fi

  # Build args array
  local args=("--dangerously-skip-permissions")
  args+=("--session-id" "$uuid")
  [[ -n "$model" ]] && args+=("--model" "$model")
  args+=("--include-partial-messages" "--output-format" "stream-json")
  args+=("-p" "$prompt_text")

  # Execute Claude CLI (with timing)
  local start_time=$(date +%s)

  "$CLAUDE_CMD" "${args[@]}" | \
    tee -a "$NANCY_TASK_DIR/logs/$nancy_session_id.log" | \
    _claude_format_stream | \
    fmt::strip_ansi | \
    tee -a "$NANCY_TASK_DIR/logs/$nancy_session_id.formatted.log"

  local exit_code=${PIPESTATUS[0]}
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))

  # --- POST-REQUEST HOOK ---
  if [[ "${NANCY_API_MONITOR_ENABLED:-false}" == "true" ]]; then
    api_monitor::log_response \
      "$nancy_session_id" \
      "$uuid" \
      "$exit_code" \
      "$duration" \
      "$NANCY_TASK_DIR"
  fi

  # Copy session JSONL to task directory
  _copy_project_session "$nancy_session_id" "$uuid"

  # Export session summary if requested
  [[ -n "$export_file" ]] && \
    cli::claude::export_session "$uuid" "$export_file" "$nancy_session_id"

  return "$exit_code"
}
```

**Monitor Module:**

```bash
# src/lib/api-monitor.sh (new file)

api_monitor::log_request() {
  local session_id="$1"
  local uuid="$2"
  local model="$3"
  local prompt="$4"
  local task_dir="$5"

  local log_file="$task_dir/logs/api-requests.jsonl"
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")

  # Optionally redact prompt if configured
  local logged_prompt="$prompt"
  if [[ "${NANCY_API_MONITOR_REDACT_PROMPTS:-false}" == "true" ]]; then
    logged_prompt="<redacted (${#prompt} chars)>"
  fi

  jq -n \
    --arg timestamp "$timestamp" \
    --arg session_id "$session_id" \
    --arg uuid "$uuid" \
    --arg model "$model" \
    --arg prompt "$logged_prompt" \
    --argjson prompt_length "${#prompt}" \
    '{
      timestamp: $timestamp,
      session_id: $session_id,
      uuid: $uuid,
      model: $model,
      prompt: $prompt,
      prompt_length: $prompt_length,
      git_branch: (env.GIT_BRANCH // "unknown")
    }' >> "$log_file"
}

api_monitor::log_response() {
  local session_id="$1"
  local uuid="$2"
  local exit_code="$3"
  local duration="$4"
  local task_dir="$5"

  local log_file="$task_dir/logs/api-responses.jsonl"
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")

  jq -n \
    --arg timestamp "$timestamp" \
    --arg session_id "$session_id" \
    --arg uuid "$uuid" \
    --argjson exit_code "$exit_code" \
    --argjson duration "$duration" \
    '{
      timestamp: $timestamp,
      session_id: $session_id,
      uuid: $uuid,
      exit_code: $exit_code,
      duration_seconds: $duration,
      status: (if $exit_code == 0 then "success" else "error" end)
    }' >> "$log_file"
}
```

**Pros:**
- Full control over monitoring logic
- Can log pre-request data (prompt text, model, args)
- Clean integration point in Nancy's architecture
- Easy to enable/disable via config
- Minimal performance overhead
- Works across all CLI drivers (copilot, claude, etc.)

**Cons:**
- Doesn't capture actual API request/response (only CLI level)
- Can't see streaming response details
- Requires modifying each CLI driver
- Duplicates some data that's in JSONL

**Verdict:** Good complement to Approach #3. Use for pre-request logging and high-level timing.

---

## Configuration Patterns

### Environment Variables

```bash
# Enable API monitoring
export NANCY_API_MONITOR_ENABLED=true

# Control verbosity
export NANCY_API_MONITOR_VERBOSITY=full  # full, summary, minimal

# Redact sensitive data
export NANCY_API_MONITOR_REDACT_PROMPTS=false
export NANCY_API_MONITOR_REDACT_TOOL_RESULTS=true

# Log location
export NANCY_API_MONITOR_LOG_DIR="${NANCY_TASK_DIR}/logs/api-monitor"

# Real-time display options
export NANCY_API_MONITOR_DISPLAY=tmux  # tmux, terminal, none
export NANCY_API_MONITOR_TMUX_PANE=3   # Which tmux pane to display in
```

### Config File

```bash
# .nancy/config (INI-style)
[api-monitor]
enabled = true
verbosity = full
redact_prompts = false
redact_tool_results = true
log_dir = logs/api-monitor
display = tmux
tmux_pane = 3
```

### Per-Task Override

```bash
# .nancy/tasks/ALP-123/config.env
NANCY_API_MONITOR_ENABLED=true
NANCY_API_MONITOR_VERBOSITY=summary
```

### Runtime Toggle

```bash
# Enable monitoring for current session
nancy monitor on

# Disable monitoring
nancy monitor off

# Check status
nancy monitor status

# View live monitoring
nancy monitor watch
```

---

## Performance Considerations

### Async vs Sync Logging

**Sync Logging (Blocking):**
```bash
# Writes block until file I/O completes
api_monitor::log_request "$prompt" >> "$log_file"
claude --session-id "$uuid" -p "$prompt"
```

**Pros:**
- Simple implementation
- Guaranteed write order
- No race conditions

**Cons:**
- Adds latency to every API call (typically 1-5ms)
- Can block on slow disks

**Async Logging (Background):**
```bash
# Write happens in background
(api_monitor::log_request "$prompt" >> "$log_file" &)
claude --session-id "$uuid" -p "$prompt"
```

**Pros:**
- Zero blocking time
- No impact on API call latency

**Cons:**
- Potential race conditions
- Write order not guaranteed
- Harder to debug failures

**Recommendation:** Use **async logging** for pre-request hooks, **sync logging** for post-request hooks (where we're already waiting for Claude to finish).

### File Watching Overhead

**tail -F Performance:**
- CPU usage: ~0.1% per watcher
- Memory: ~2MB per watcher
- Latency: <100ms from write to read

**Optimization:**
- Use single watcher for multiple log types
- Filter events in background process
- Batch writes to reduce syscalls

```bash
# Efficient: Single watcher, multiple parsers
tail -F session.jsonl | tee >(parse_tokens) >(parse_requests) >(parse_responses)

# Inefficient: Multiple watchers
tail -F session.jsonl | parse_tokens &
tail -F session.jsonl | parse_requests &
tail -F session.jsonl | parse_responses &
```

### Disk I/O

**Log File Sizes:**
- Typical session JSONL: 50-500 KB
- Per-iteration growth: ~100 KB/iteration
- Full task lifecycle: 1-5 MB

**Optimization:**
- Use append-only writes (>> operator)
- Compress old logs (gzip logs/*.jsonl)
- Rotate logs by date/iteration

**Log Rotation:**
```bash
# Auto-rotate logs after 10 iterations
if [[ $(ls logs/*.jsonl | wc -l) -gt 10 ]]; then
  mkdir -p logs/archive
  gzip logs/nancy-*.jsonl
  mv logs/*.jsonl.gz logs/archive/
fi
```

### Streaming Response Handling

Nancy already pipes Claude's streaming output through formatters:

```bash
"$CLAUDE_CMD" "${args[@]}" | \
  tee -a "$raw.log" | \
  _claude_format_stream | \
  fmt::strip_ansi | \
  tee -a "$formatted.log"
```

**Performance Impact:**
- tee: ~1% CPU overhead
- jq (in _claude_format_stream): ~5% CPU overhead
- Total: <10% overhead during streaming

**Optimization:**
- Use --unbuffered flag for jq
- Minimize jq passes (one-pass filtering)
- Use tee only when needed

---

## File Watching & Real-Time Display

### Nancy's Existing File Watching Pattern

Nancy uses `fswatch` for bidirectional communication monitoring and `tail -F` for session log monitoring.

**fswatch (for inboxes):**
```bash
# Watches for file creation events
fswatch -0 --event Created "$inbox_dir" | while IFS= read -r -d '' event; do
  # Process new message files
done
```

**tail -F (for logs):**
```bash
# Follows file by name (handles rotation)
tail -n 0 -F "$log_file" | while IFS= read -r line; do
  # Process new log lines
done
```

### Real-Time Display Options

#### Option 1: Dedicated tmux Pane (Recommended)

Nancy's orchestration mode uses tmux with a 3-pane layout:

```
┌─────────────────────────────────────────────────┐
│ Pane 0: Orchestrator (Claude Code)             │
├─────────────────────────────────────────────────┤
│ Pane 1: Worker (Claude Code)                   │
├─────────────────────────────────────────────────┤
│ Pane 2: Inbox (Communication logs)             │
└─────────────────────────────────────────────────┘
```

**Enhancement:** Add Pane 3 for API monitoring:

```
┌──────────────────────────┬──────────────────────┐
│ Pane 0: Orchestrator     │ Pane 2: Inbox        │
├──────────────────────────┼──────────────────────┤
│ Pane 1: Worker           │ Pane 3: API Monitor  │
└──────────────────────────┴──────────────────────┘
```

**Implementation:**
```bash
# src/cmd/orchestrate.sh (modified)
if [[ "${NANCY_API_MONITOR_DISPLAY:-none}" == "tmux" ]]; then
  # Split to create 4-pane layout
  tmux split-window -h -t "$window.2"
  tmux select-pane -t "$window.3" -T "API Monitor"

  # Start monitoring in pane 3
  tmux send-keys -t "$window.3" \
    "nancy monitor watch $task" Enter
fi
```

#### Option 2: Overlay Terminal

Use a floating terminal (like iTerm2 hotkey window) that shows monitoring:

```bash
# Bind to hotkey (Cmd+Shift+M)
osascript -e 'tell app "iTerm2"
  create window with default profile
  tell current window
    set bounds to {100, 100, 800, 600}
    tell current session
      write text "tail -f ~/.nancy/tasks/ALP-123/logs/api-monitor.log"
    end tell
  end tell
end tell'
```

#### Option 3: In-line Terminal (Less Intrusive)

Display monitoring summary at bottom of orchestrator pane:

```bash
# Use terminal status line
echo -ne "\033]0;Nancy - Tokens: 45% | Last API: 2.3s | Cost: $0.15\007"
```

#### Option 4: Web Dashboard

Serve monitoring data via simple HTTP server:

```bash
# Start monitoring server
nancy monitor serve --port 8080 --task ALP-123

# Opens browser to http://localhost:8080
# Shows real-time API calls, token usage, costs
```

**Recommendation:** Use Option 1 (tmux pane) for orchestration mode, Option 3 (status line) for single-agent mode.

### Display Format Examples

**Compact Format (Status Line):**
```
[15:30:45] API Call #12 | Model: sonnet-4-5 | Duration: 2.3s | Tokens: 5K→150 | Cost: $0.02
```

**Detailed Format (Dedicated Pane):**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📡 API CALL #12 - 2026-01-26 15:30:45
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Session:   nancy-ALP-123-iter3
UUID:      f47ac10b-58cc-4372-a567-0e02b2c3d479
Model:     claude-sonnet-4-5-20250929
Duration:  2.3s
Status:    success

Tokens:
  Input:   5,000 (3,000 from cache)
  Output:  150
  Total:   5,150 / 200,000 (2.6%)

Cost:      $0.02

Tool Calls:
  1. Read: src/cmd/start.sh
  2. Edit: src/notify/watcher.sh
  3. Bash: git status

Response Preview:
  I've added the monitoring hooks to the watcher module...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Stream Format (Live Updates):**
```
15:30:42 │ 🔄 Starting API call...
15:30:42 │    Model: claude-sonnet-4-5-20250929
15:30:42 │    Prompt: 1,234 chars
15:30:43 │ 📤 Request sent
15:30:44 │ 💬 Response streaming...
15:30:44 │    "I'll help you with that..."
15:30:45 │ 🔧 Tool: Read (src/cmd/start.sh)
15:30:45 │ 🔧 Tool: Edit (src/notify/watcher.sh)
15:30:45 │ ✅ API call complete (2.3s)
15:30:45 │    Tokens: 5,000 → 150
15:30:45 │    Cost: $0.02
```

---

## Recommended Approach

After evaluating all approaches, here's the recommended implementation:

### Hybrid Approach: JSONL Watching + Driver Hooks

**Why Hybrid?**
- JSONL watching provides complete API-level visibility (requests, responses, tool calls)
- Driver hooks provide pre-request visibility (what Nancy is about to send)
- Together they give end-to-end monitoring with minimal overhead

**Architecture:**

```
┌─────────────────────────────────────────────────────────────┐
│ 1. PRE-REQUEST: Driver Hook                                 │
│    - Log prompt text, model, timestamp                      │
│    - Write to api-requests.jsonl                            │
└───────────────────────┬─────────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────────┐
│ 2. EXECUTION: Claude CLI                                    │
│    - Makes API call                                         │
│    - Writes session JSONL                                   │
└───────────────────────┬─────────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────────┐
│ 3. POST-REQUEST: Driver Hook                                │
│    - Log exit code, duration                                │
│    - Copy session JSONL to task dir                         │
└───────────────────────┬─────────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────────┐
│ 4. REAL-TIME MONITORING: JSONL Watcher                      │
│    - tail -F session JSONL                                  │
│    - Parse assistant messages (responses)                   │
│    - Parse user messages (tool results)                     │
│    - Update real-time display                               │
└─────────────────────────────────────────────────────────────┘
```

### File Structure

```
.nancy/tasks/ALP-123/
├── logs/
│   ├── nancy-ALP-123-iter1.log           # Raw streaming output
│   ├── nancy-ALP-123-iter1.formatted.log # Formatted for humans
│   ├── api-monitor/
│   │   ├── requests.jsonl                # Pre-request logs (driver hooks)
│   │   ├── responses.jsonl               # Post-request logs (driver hooks)
│   │   ├── sessions.jsonl                # Extracted session summaries
│   │   ├── tool-calls.jsonl              # Extracted tool calls
│   │   └── tool-results.jsonl            # Extracted tool results
│   └── token-alerts.log                  # Token threshold alerts
├── session-state/
│   └── nancy-ALP-123-iter1.jsonl         # Full session JSONL (copied from Claude)
└── token-usage.json                      # Current token usage
```

### Configuration

```bash
# .nancy/config
[api-monitor]
enabled = true
verbosity = full  # full, summary, minimal, off

# What to log
log_requests = true       # Pre-request logs (driver hooks)
log_responses = true      # Post-request logs (driver hooks)
log_sessions = true       # Session summaries from JSONL
log_tool_calls = true     # Tool calls from JSONL
log_tool_results = true   # Tool results from JSONL

# Redaction
redact_prompts = false
redact_tool_results = false

# Display
display_mode = tmux       # tmux, terminal, none
display_format = stream   # stream, detailed, compact
tmux_pane = 3

# Performance
async_logging = true      # Use background writes
compress_old_logs = true  # Gzip logs older than 7 days
```

### Implementation Phases

**Phase 1: Driver Hooks (Quick Win)**
- Add pre/post request hooks to `cli::run_prompt`
- Log to `api-requests.jsonl` and `api-responses.jsonl`
- Enable/disable via `NANCY_API_MONITOR_ENABLED`
- Estimated time: 2-3 hours

**Phase 2: JSONL Watcher (Core Visibility)**
- Create `notify::watch_session_bg` function
- Parse JSONL for tool calls, tool results, session summaries
- Write to separate log files for easy analysis
- Estimated time: 4-6 hours

**Phase 3: Real-Time Display (Polish)**
- Add tmux pane for monitoring display
- Format streaming output with colors
- Add status line updates
- Estimated time: 3-4 hours

**Phase 4: CLI Commands (UX)**
- `nancy monitor on/off` - Toggle monitoring
- `nancy monitor watch` - Live monitoring view
- `nancy monitor stats` - Session statistics
- Estimated time: 2-3 hours

**Total Estimated Time:** 11-16 hours

---

## Integration Plan

### Step 1: Create Monitoring Module

```bash
# Create new module
touch src/lib/api-monitor.sh

# Add to index
echo 'source "${NANCY_LIB_DIR}/api-monitor.sh"' >> src/lib/index.sh
```

### Step 2: Implement Driver Hooks

```bash
# Modify src/cli/drivers/claude.sh
# Add calls to api_monitor::log_request and api_monitor::log_response
```

### Step 3: Implement JSONL Watcher

```bash
# Add notify::watch_session_bg to src/notify/watcher.sh
# Integrate with existing watcher lifecycle
```

### Step 4: Add Configuration

```bash
# Add defaults to src/config/config.sh
config::defaults() {
  # ... existing defaults ...

  # API monitoring
  export NANCY_API_MONITOR_ENABLED="${NANCY_API_MONITOR_ENABLED:-false}"
  export NANCY_API_MONITOR_VERBOSITY="${NANCY_API_MONITOR_VERBOSITY:-full}"
  export NANCY_API_MONITOR_DISPLAY="${NANCY_API_MONITOR_DISPLAY:-none}"
}
```

### Step 5: Add CLI Commands

```bash
# Create src/cmd/monitor.sh
cmd::monitor() {
  local subcommand="${1:-status}"
  case "$subcommand" in
    on)     config::set api_monitor.enabled true ;;
    off)    config::set api_monitor.enabled false ;;
    status) config::get api_monitor.enabled ;;
    watch)  api_monitor::watch_live "$2" ;;
    stats)  api_monitor::show_stats "$2" ;;
  esac
}
```

### Step 6: Update Orchestrate

```bash
# Modify src/cmd/orchestrate.sh
# Add 4th pane for monitoring if enabled
# Start monitoring watcher
```

### Step 7: Testing

```bash
# Test with a sample task
nancy start ALP-123

# Enable monitoring
nancy monitor on

# Run iteration and verify logs
ls -lh .nancy/tasks/ALP-123/logs/api-monitor/

# Check real-time display
# (should see updates in tmux pane 3)
```

---

## References

### External Resources

**OpenTelemetry & Observability:**
- [Claude Code Docs - Monitoring](https://code.claude.com/docs/en/monitoring-usage)
- [Claude Code Observability and Tracing](https://arize.com/blog/claude-code-observability-and-tracing-introducing-dev-agent-lens/)
- [Can Claude Code Observe Its Own Code?](https://www.honeycomb.io/blog/can-claude-code-observe-its-own-code)
- [A Complete Guide to Monitoring Claude Code in 2025](https://www.eesel.ai/blog/monitoring-claude-code)

**Proxy & Middleware:**
- [Build a Node.js API Proxy](https://dev.to/dashsaurabh/build-a-nodejs-api-proxy-to-supercharge-your-backend-42f3)
- [Proxy in Node.js: 5 Common Setup Methods](https://www.webshare.io/academy-article/node-js-proxy)
- [http-proxy-middleware - npm](https://www.npmjs.com/package/http-proxy-middleware)

**API Monitoring Best Practices:**
- [The Ultimate Guide to API Monitoring in 2026](https://signoz.io/blog/api-monitoring-complete-guide/)
- [API Monitoring Metrics, Tips and Best Practices](https://www.catchpoint.com/guide-to-synthetic-monitoring/api-monitoring)
- [Debugging Best Practices for REST API Consumers](https://stackoverflow.blog/2022/02/28/debugging-best-practices-for-rest-api-consumers/)

**Claude-Specific Tools:**
- [claude-code-logger - GitHub](https://github.com/dreampulse/claude-code-logger)
- [Feature Request: Ability to Log Full LLM Span](https://github.com/anthropics/claude-code/issues/2090)
- [Collecting Anthropic Server Logs with an Undocumented API](https://www.ai.moda/en/blog/anthropic-server-logs-api)

### Nancy Codebase References

**Existing Monitoring Infrastructure:**
- `src/task/token.sh` - Token usage tracking
- `src/notify/watcher.sh` - File watching patterns (fswatch, tail -F)
- `src/cli/drivers/claude.sh` - Claude CLI driver
- `src/cmd/start.sh` - Main iteration loop

**Relevant Patterns:**
- Background process management (watchers with PID files)
- JSONL parsing with jq
- tmux pane management
- Configuration via environment variables

---

## Appendix: Alternative Considered Approaches

### A. Mitmdump Scripting

**Description:** Use mitmproxy's mitmdump with a Python script to log traffic.

```python
# monitor.py
from mitmproxy import http

def request(flow: http.HTTPFlow):
    if "api.anthropic.com" in flow.request.url:
        print(f"REQUEST: {flow.request.method} {flow.request.path}")
        with open("requests.log", "a") as f:
            f.write(flow.request.content.decode())

def response(flow: http.HTTPFlow):
    if "api.anthropic.com" in flow.request.url:
        print(f"RESPONSE: {flow.response.status_code}")
        with open("responses.log", "a") as f:
            f.write(flow.response.content.decode())
```

```bash
# Run with mitmdump
mitmdump -s monitor.py --set stream_large_bodies=100m

# Configure Claude Code
export https_proxy=http://localhost:8080
```

**Verdict:** Too complex for Nancy's needs. Requires Python, mitmproxy installation, SSL cert setup.

### B. eBPF Tracing

**Description:** Use eBPF to trace syscalls and network traffic at kernel level.

```bash
# Use bpftrace to monitor connect() syscalls
bpftrace -e 'tracepoint:syscalls:sys_enter_connect {
  printf("Connection from PID %d\n", pid);
}'
```

**Verdict:** Massive overkill. Requires root, Linux-only, extremely complex. No benefit over simpler approaches.

### C. Strace/Dtruss

**Description:** Use system call tracing to monitor Claude CLI's network calls.

```bash
# Linux
strace -e trace=network -f -o api-calls.log claude --session-id UUID

# macOS
sudo dtruss -t connect,sendto,recvfrom -f -o api-calls.log claude --session-id UUID
```

**Verdict:** Very noisy output (thousands of syscalls). Hard to parse. Requires root on macOS. Not worth it.

### D. Network Packet Capture

**Description:** Use tcpdump/wireshark to capture packets.

```bash
# Capture HTTPS traffic to Claude API
tcpdump -i any -w capture.pcap 'host api.anthropic.com'

# Analyze with tshark
tshark -r capture.pcap -Y http2 -T json
```

**Verdict:** Can't decrypt HTTPS without private key. Only shows encrypted packets. Useless for our needs.

---

## Conclusion

The **Hybrid Approach (JSONL Watching + Driver Hooks)** is the clear winner for Nancy:

**Why it works:**
- Leverages Nancy's existing file-watching infrastructure
- No external dependencies (no mitmproxy, no OpenTelemetry backends)
- Minimal performance overhead (async logging + passive monitoring)
- Complete visibility (pre-request, API-level, post-request)
- Easy to enable/disable via configuration
- Clean integration with Nancy's architecture

**Implementation effort:** ~11-16 hours across 4 phases

**Next steps:**
1. Create `src/lib/api-monitor.sh` module
2. Add driver hooks to `cli::run_prompt`
3. Implement `notify::watch_session_bg`
4. Add CLI commands (`nancy monitor`)
5. Integrate with orchestration mode

This approach provides enterprise-grade API monitoring with startup-level simplicity.

---

**Research by:** Claude Sonnet 4.5
**Date:** 2026-01-26
**Status:** Ready for implementation
