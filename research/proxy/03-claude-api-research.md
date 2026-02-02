# Claude API Research: Monitoring Requests and Responses

## Executive Summary

This document provides comprehensive research on the Anthropic Claude API structure, streaming capabilities, authentication mechanisms, and best practices for monitoring and logging API requests and responses. The findings inform the design of a proxy-based monitoring solution for Nancy's Claude Code integration.

## 1. Claude API Structure

### 1.1 Base API Endpoint

- **Base URL**: `https://api.anthropic.com`
- **Primary Endpoint**: POST `/v1/messages` (Messages API)
- **Architecture**: RESTful API with clean JSON structure

### 1.2 Request Format

#### Basic Request Structure

```json
{
  "model": "claude-sonnet-4-5-20250929",
  "max_tokens": 1024,
  "messages": [
    {"role": "user", "content": "Hello, world"}
  ],
  "system": "Optional system prompt for context",
  "temperature": 1.0,
  "stream": false
}
```

#### Required Headers

```
Content-Type: application/json
x-api-key: <API_KEY>
anthropic-version: 2023-06-01
```

#### Optional Headers

- `anthropic-beta`: For feature flags (e.g., `structured-outputs-2025-11-13`)
- `anthropic-dangerous-direct-browser-access`: For browser-based usage (not recommended)

#### Key Request Parameters

- **model** (required): Model identifier (e.g., `claude-sonnet-4-5-20250929`)
- **max_tokens** (required): Maximum tokens to generate
- **messages** (required): Array of conversation turns with `role` and `content`
- **system** (optional): System prompt for instructions/context
- **temperature** (optional): Sampling temperature (0-1)
- **top_p** (optional): Nucleus sampling parameter
- **top_k** (optional): Top-k sampling parameter
- **stream** (optional): Enable streaming responses (boolean)
- **stop_sequences** (optional): Array of strings that stop generation
- **metadata** (optional): User ID and other tracking data

### 1.3 Response Format

#### Standard Response Structure

```json
{
  "id": "msg_013Zva2CMHLNnXjNJJKqJ2EF",
  "type": "message",
  "role": "assistant",
  "content": [
    {
      "type": "text",
      "text": "Hi! My name is Claude.",
      "citations": null
    }
  ],
  "model": "claude-sonnet-4-5-20250929",
  "stop_reason": "end_turn",
  "stop_sequence": null,
  "usage": {
    "input_tokens": 2095,
    "output_tokens": 503
  }
}
```

#### Response Fields

- **id**: Unique message identifier
- **type**: Always "message"
- **role**: Always "assistant"
- **content**: Array of content blocks (text, tool_use, etc.)
- **model**: Echo of model used
- **stop_reason**: Why generation stopped (`end_turn`, `max_tokens`, `stop_sequence`)
- **usage**: Token consumption breakdown
  - `input_tokens`: Tokens in request
  - `output_tokens`: Tokens in response

#### Error Response Structure

```json
{
  "type": "error",
  "error": {
    "type": "invalid_request_error",
    "message": "Detailed error message"
  }
}
```

## 2. Streaming Responses

### 2.1 Server-Sent Events (SSE) Protocol

Claude API uses Server-Sent Events (SSE) for streaming, providing incremental message delivery.

#### Enabling Streaming

Set `"stream": true` in the request:

```json
{
  "model": "claude-sonnet-4-5-20250929",
  "max_tokens": 1024,
  "messages": [...],
  "stream": true
}
```

### 2.2 SSE Event Sequence

Streaming events flow in a predictable sequence:

1. **message_start**: Initial message metadata (empty content)
2. **content_block_start**: Beginning of a content block
3. **content_block_delta**: Incremental content updates (multiple events)
4. **content_block_stop**: End of a content block
5. **message_delta**: Updates to message-level fields
6. **message_stop**: Final event with usage statistics

#### Example Event Stream

```
event: message_start
data: {"type":"message_start","message":{"id":"msg_123","type":"message","role":"assistant","content":[],"model":"claude-sonnet-4-5-20250929"}}

event: content_block_start
data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" there"}}

event: content_block_stop
data: {"type":"content_block_stop","index":0}

event: message_delta
data: {"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null},"usage":{"output_tokens":503}}

event: message_stop
data: {"type":"message_stop"}
```

### 2.3 Extended Thinking Support

For extended thinking responses (long chains of reasoning):

- **thinking_delta** events: Deliver reasoning content
- Separate from regular content blocks
- Provides transparency into Claude's reasoning process

### 2.4 Capturing Streaming Responses

**Challenge**: SSE events are consumed incrementally and may not be available for replay.

**Solutions**:
1. **Buffer events**: Collect all SSE events in memory before forwarding
2. **Dual streaming**: Forward events to client while logging simultaneously
3. **Event reconstruction**: Reassemble final response from delta events

**Considerations**:
- Memory overhead for long responses
- Latency impact from buffering
- Thread safety for concurrent requests

## 3. Authentication and Security

### 3.1 API Key Authentication

#### Header Format

Primary method:
```
x-api-key: sk-ant-api03-...
```

Alternative (less common):
```
Authorization: Bearer sk-ant-api03-...
```

#### API Key Management

- API keys start with `sk-ant-api03-`
- Keys are displayed only once at creation
- Support for multiple keys per organization
- Per-key usage tracking and rate limits

### 3.2 Security Best Practices

#### Critical Security Rules

1. **Never log API keys**: Redact or mask in all logs
2. **Never expose keys in client-side code**: Server-side only
3. **Store securely**: Use environment variables or secret managers
4. **Rotate regularly**: Implement key rotation policies
5. **Monitor usage**: Track anomalous patterns per key
6. **Separate keys**: Use different keys for dev/staging/prod

#### API Key Detection Patterns

```bash
# Regex pattern for API key detection
sk-ant-api03-[A-Za-z0-9_-]{95}
```

### 3.3 Rate Limiting Headers

Responses include rate limit information:

```
anthropic-ratelimit-requests-limit: 1000
anthropic-ratelimit-requests-remaining: 999
anthropic-ratelimit-requests-reset: 2026-01-26T18:00:00Z
anthropic-ratelimit-tokens-limit: 100000
anthropic-ratelimit-tokens-remaining: 95000
anthropic-ratelimit-tokens-reset: 2026-01-26T18:00:00Z
```

## 4. SDK Implementation Details

### 4.1 Python SDK (@anthropic-ai/sdk-python)

#### Basic Usage

```python
from anthropic import Anthropic

client = Anthropic(api_key="sk-ant-api03-...")

message = client.messages.create(
    model="claude-sonnet-4-5-20250929",
    max_tokens=1024,
    messages=[
        {"role": "user", "content": "Hello, Claude"}
    ]
)
```

#### Streaming Usage

```python
with client.messages.stream(
    model="claude-sonnet-4-5-20250929",
    max_tokens=1024,
    messages=[{"role": "user", "content": "Hello"}]
) as stream:
    for text in stream.text_stream:
        print(text, end="", flush=True)
```

#### HTTP Implementation

- Uses `httpx` library (synchronous and async)
- Supports custom HTTP clients
- Type hints via Pydantic models
- Automatic retry logic with exponential backoff

#### Intercepting Requests

```python
import httpx
from anthropic import Anthropic

class LoggingTransport(httpx.HTTPTransport):
    def handle_request(self, request):
        # Log request here
        print(f"Request: {request.method} {request.url}")
        response = super().handle_request(request)
        # Log response here
        print(f"Response: {response.status_code}")
        return response

client = Anthropic(
    http_client=httpx.Client(transport=LoggingTransport())
)
```

### 4.2 TypeScript SDK (@anthropic-ai/sdk)

#### Basic Usage

```typescript
import Anthropic from '@anthropic-ai/sdk';

const client = new Anthropic({
  apiKey: process.env.ANTHROPIC_API_KEY
});

const message = await client.messages.create({
  model: 'claude-sonnet-4-5-20250929',
  max_tokens: 1024,
  messages: [
    { role: 'user', content: 'Hello, Claude' }
  ]
});
```

#### Streaming Usage

```typescript
const stream = await client.messages.stream({
  model: 'claude-sonnet-4-5-20250929',
  max_tokens: 1024,
  messages: [{ role: 'user', content: 'Hello' }]
});

for await (const chunk of stream) {
  if (chunk.type === 'content_block_delta') {
    process.stdout.write(chunk.delta.text);
  }
}
```

#### HTTP Implementation

- Uses native `fetch()` API
- Access raw response via `.asResponse()` or `.withResponse()`
- TypeScript type definitions included
- Automatic retry logic

#### Intercepting Requests

```typescript
class LoggingClient extends Anthropic {
  async request(options: RequestOptions) {
    console.log('Request:', options.method, options.path);
    const response = await super.request(options);
    console.log('Response:', response.status);
    return response;
  }
}

const client = new LoggingClient({ apiKey: '...' });
```

### 4.3 Claude Code SDK

The Claude Code Agent SDK uses a different architecture:

- **Not HTTP-based**: Uses IPC or WebSocket for CLI communication
- **Challenge for proxies**: Traditional HTTP proxies don't work
- **Monitoring approach**: OpenTelemetry integration instead of HTTP interception

## 5. Token Counting and Cost Tracking

### 5.1 Token Counting Endpoint

#### Endpoint

POST `/v1/messages/count_tokens`

#### Request

```json
{
  "model": "claude-sonnet-4-5-20250929",
  "messages": [
    {"role": "user", "content": "Hello, Claude"}
  ],
  "system": "Optional system prompt"
}
```

#### Response

```json
{
  "input_tokens": 15
}
```

#### Characteristics

- **Free to use** (no billing)
- **Rate limited** based on usage tier
- **Estimate only**: Actual usage may differ slightly
- **Excludes system-added tokens**: You're not billed for system overhead

### 5.2 Cost Calculation

#### Claude 4.5 Pricing (2026)

| Model | Input (per 1M tokens) | Output (per 1M tokens) |
|-------|----------------------|------------------------|
| Haiku 4.5 | $1 | $5 |
| Sonnet 4.5 | $3 | $15 |
| Opus 4.5 | $5 | $25 |

#### Cost Calculation Formula

```
total_cost = (input_tokens / 1_000_000 * input_price) +
             (output_tokens / 1_000_000 * output_price)
```

#### Example (Sonnet 4.5)

```
Request: 2,095 input tokens, 503 output tokens
Cost = (2,095 / 1,000,000 * $3) + (503 / 1,000,000 * $15)
Cost = $0.006285 + $0.007545
Cost = $0.01383
```

### 5.3 Usage and Cost API

#### Organization Usage Endpoint

GET `/v1/organization/usage`

Query parameters:
- `start_time`: ISO 8601 timestamp
- `end_time`: ISO 8601 timestamp
- `granularity`: `1m`, `1h`, or `1d`
- `model`: Filter by specific model

#### Response

```json
{
  "usage": [
    {
      "timestamp": "2026-01-26T12:00:00Z",
      "model": "claude-sonnet-4-5-20250929",
      "input_tokens": 150000,
      "output_tokens": 50000,
      "workspace_id": "ws_abc123",
      "service_tier": "enterprise"
    }
  ]
}
```

#### Cost Report Endpoint

GET `/v1/organization/costs`

Returns USD costs broken down by:
- Token usage (input/output)
- Web search costs
- Code execution costs
- All costs in cents (decimal strings)

### 5.4 Monitoring Tools Integration

Third-party integrations available:

- **Datadog Cloud Cost Management**: Real-time usage and cost tracking
- **Grafana Cloud**: Anthropic integration for metrics and dashboards
- Both provide alerting, anomaly detection, and cost attribution

## 6. Privacy and Security Considerations

### 6.1 Data Retention Policies

#### Consumer Users (Free, Pro, Max)

- **With model improvement**: 5-year retention
- **Without model improvement**: 30-day retention
- User choice via account settings

#### Commercial Users (Team, Enterprise, API)

- **Zero data retention**: With appropriate API key configuration
- No training on customer data by default
- Explicit opt-in required for any data usage

### 6.2 Data Protection Measures

#### Encryption

- **In transit**: TLS encryption for all API requests
- **At rest**: 256-bit AES encryption for stored data

#### Access Controls

- Multi-factor authentication for admin access
- Role-based access control (RBAC)
- Audit logging of all access

### 6.3 What to Log vs What to Skip

#### NEVER LOG

1. **API Keys**: Always redact or mask
   - Pattern: `sk-ant-api03-[A-Za-z0-9_-]{95}`
   - Replace with: `sk-ant-api03-***REDACTED***`

2. **Personal Identifiable Information (PII)**:
   - Social Security Numbers (SSN)
   - Credit card numbers
   - Bank account details
   - Email addresses (in some contexts)
   - Phone numbers
   - Physical addresses

3. **Production Secrets**:
   - Database credentials
   - OAuth tokens
   - AWS/GCP/Azure credentials
   - Encryption keys
   - Signing secrets

4. **Sensitive Business Data**:
   - Proprietary algorithms
   - Trade secrets
   - Confidential financial data
   - Internal system architecture details

#### SAFE TO LOG

1. **Request Metadata**:
   - Timestamp
   - Request ID
   - Model name
   - Max tokens
   - Temperature/sampling parameters
   - Stream flag

2. **Response Metadata**:
   - Response ID (message ID)
   - Stop reason
   - Token usage (input/output counts)
   - Status code
   - Latency/timing

3. **Operational Metrics**:
   - Request count
   - Error rates
   - Rate limit status
   - Retry attempts
   - Queue depth

4. **Sanitized Content** (with PII redaction):
   - Message prompts (redacted)
   - Response text (redacted)
   - Tool names and schemas
   - System prompts (redacted)

### 6.4 Logging Best Practices

#### Implement Multi-Level Redaction

```python
import re

def redact_api_key(text):
    """Redact Anthropic API keys"""
    return re.sub(
        r'sk-ant-api03-[A-Za-z0-9_-]{95}',
        'sk-ant-api03-***REDACTED***',
        text
    )

def redact_pii(text):
    """Redact common PII patterns"""
    # SSN
    text = re.sub(r'\b\d{3}-\d{2}-\d{4}\b', '***-**-****', text)
    # Credit cards
    text = re.sub(r'\b\d{4}[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}\b', '****-****-****-****', text)
    # Email
    text = re.sub(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b', '***@***.***', text)
    return text

def sanitize_for_logging(data):
    """Sanitize data structure for logging"""
    if isinstance(data, dict):
        sanitized = {}
        for key, value in data.items():
            if key in ['api_key', 'x-api-key', 'authorization']:
                sanitized[key] = '***REDACTED***'
            else:
                sanitized[key] = sanitize_for_logging(value)
        return sanitized
    elif isinstance(data, str):
        return redact_pii(redact_api_key(data))
    elif isinstance(data, list):
        return [sanitize_for_logging(item) for item in data]
    else:
        return data
```

#### Logging Levels

- **DEBUG**: Full request/response (heavily redacted)
- **INFO**: Metadata only (no content)
- **WARN**: Errors and anomalies
- **ERROR**: Failures and exceptions

#### Structured Logging

```json
{
  "timestamp": "2026-01-26T17:30:00Z",
  "level": "INFO",
  "event": "claude_api_request",
  "request_id": "req_abc123",
  "model": "claude-sonnet-4-5-20250929",
  "input_tokens": 2095,
  "output_tokens": 503,
  "latency_ms": 1250,
  "status": "success",
  "cost_usd": 0.01383
}
```

### 6.5 Compliance Considerations

#### GDPR

- Right to erasure: Ability to delete logged data
- Data minimization: Log only what's necessary
- Purpose limitation: Clear logging purposes documented
- User consent: Notify users of logging practices

#### SOC 2

- Access controls on logs
- Encryption at rest and in transit
- Audit trails of log access
- Retention policies documented

#### HIPAA (if applicable)

- No PHI in logs without proper safeguards
- Encrypted log storage
- Access controls and audit trails
- Business Associate Agreement (BAA) with Anthropic

## 7. Integration Points for Monitoring

### 7.1 Proxy Approaches

#### HTTP Proxy

**Concept**: Intercept HTTP/HTTPS traffic between client and API

**Implementations**:
- mitmproxy
- Charles Proxy
- Custom Node.js/Python proxy

**Advantages**:
- Language-agnostic
- Works with any HTTP client
- Transparent to application

**Disadvantages**:
- Doesn't work with Claude Code SDK (uses IPC/WebSocket)
- HTTPS certificate complications
- Potential latency overhead

#### SDK Wrapper

**Concept**: Wrap official SDK with logging layer

**Implementation**:
```python
class MonitoredAnthropicClient(Anthropic):
    def messages_create(self, **kwargs):
        # Log request
        start_time = time.time()
        request_id = generate_request_id()
        log_request(request_id, kwargs)

        # Make actual API call
        try:
            response = super().messages.create(**kwargs)
            # Log response
            latency = time.time() - start_time
            log_response(request_id, response, latency)
            return response
        except Exception as e:
            log_error(request_id, e)
            raise
```

**Advantages**:
- Full control over logging
- Access to pre/post request hooks
- Easy to customize

**Disadvantages**:
- SDK-specific (need wrappers for Python, TypeScript, etc.)
- Maintenance burden with SDK updates

#### Environment Variable Proxy

**Concept**: Use `HTTP_PROXY` environment variable

```bash
export HTTP_PROXY=http://localhost:8080
export HTTPS_PROXY=http://localhost:8080
```

**Advantages**:
- No code changes required
- Works with multiple applications

**Disadvantages**:
- All traffic routed through proxy
- May break other applications
- Doesn't work with Claude Code SDK

### 7.2 OpenTelemetry Integration

For Claude Code specifically, Anthropic recommends OpenTelemetry:

#### Metrics Available

- Request count
- Token usage
- Latency
- Error rates
- Cost tracking

#### Events Available

- Request/response events (content redacted by default)
- Tool usage
- Conversation turns

#### Configuration

```bash
# Enable OpenTelemetry
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318

# Run Claude Code with telemetry
claude-code --enable-telemetry
```

#### Privacy Guarantees

- API keys never included
- File contents never included
- User prompts redacted by default (only length recorded)
- Configurable redaction policies

### 7.3 Database Logging Architecture

#### Schema Design

```sql
CREATE TABLE api_requests (
    id UUID PRIMARY KEY,
    timestamp TIMESTAMP NOT NULL,
    model VARCHAR(100) NOT NULL,
    input_tokens INTEGER,
    output_tokens INTEGER,
    max_tokens INTEGER,
    temperature FLOAT,
    stream BOOLEAN,
    latency_ms INTEGER,
    status VARCHAR(50),
    cost_usd DECIMAL(10, 6),
    error_message TEXT,
    request_hash VARCHAR(64),  -- SHA256 of content (not stored)
    INDEX idx_timestamp (timestamp),
    INDEX idx_model (model),
    INDEX idx_status (status)
);

CREATE TABLE api_costs_daily (
    date DATE PRIMARY KEY,
    model VARCHAR(100),
    total_requests INTEGER,
    total_input_tokens BIGINT,
    total_output_tokens BIGINT,
    total_cost_usd DECIMAL(10, 2),
    INDEX idx_model (model)
);
```

#### Aggregation Strategy

- Real-time logging to `api_requests`
- Hourly rollup to daily summaries
- Monthly archival of detailed logs
- Permanent retention of aggregates

### 7.4 Dashboard and Analytics

#### Key Metrics to Display

1. **Usage Metrics**:
   - Requests per hour/day/month
   - Tokens consumed (input/output split)
   - Average response latency
   - Error rate

2. **Cost Metrics**:
   - Daily/weekly/monthly spend
   - Cost per model
   - Cost per user/workspace
   - Projected monthly costs

3. **Performance Metrics**:
   - P50/P95/P99 latency
   - Timeout rate
   - Retry rate
   - Rate limit hits

4. **Content Metrics** (aggregated, not individual):
   - Average prompt length
   - Average response length
   - Common stop reasons
   - Model distribution

#### Visualization Tools

- Grafana: Open-source dashboards
- Datadog: Commercial APM platform
- Custom: React/Vue dashboard with Chart.js

## 8. Existing Claude Code Proxy Projects

### 8.1 seifghazi/claude-code-proxy

**Repository**: https://github.com/seifghazi/claude-code-proxy

**Features**:
- Real-time interception of Claude Code to Anthropic API
- SQLite-based logging
- Live dashboard
- Request monitoring
- Conversation analysis
- Tool usage visualization

**Architecture**:
- HTTP proxy server (intercepts HTTPS)
- SQLite database for storage
- Web UI for visualization

**Use Case**: Development/debugging Claude Code interactions

### 8.2 ccflare

**Website**: https://ccflare.com

**Features**:
- Full Anthropic API proxy
- Real-time token analytics
- Intelligent load balancing
- Monitoring of every API call (millisecond precision)
- Token usage tracking
- API cost tracking
- Latency monitoring
- Success rate tracking

**Architecture**:
- Commercial SaaS platform
- Multi-tenant proxy
- Advanced analytics

**Use Case**: Production monitoring and cost management

### 8.3 claude-code-logger

**Repository**: https://github.com/dreampulse/claude-code-logger

**Features**:
- HTTP/HTTPS proxy logger
- Enhanced chat mode visualization
- Specialized for Claude Code traffic analysis

**Architecture**:
- Standalone proxy
- Log file output
- Terminal visualization

**Use Case**: Debugging and traffic analysis

### 8.4 AIProxy

**Repository**: https://github.com/uezo/aiproxy

**Features**:
- Multi-provider support (Claude, ChatGPT, etc.)
- Monitoring and logging
- Request/response filtering
- Reverse proxy architecture

**Architecture**:
- Python-based reverse proxy
- Pluggable middleware
- Support for multiple LLM APIs

**Use Case**: General-purpose LLM API monitoring

## 9. Recommendations for Nancy Monitoring

### 9.1 Architecture Approach

**Recommendation**: Hybrid approach combining SDK wrapper and OpenTelemetry

**Rationale**:
1. SDK wrapper provides immediate, detailed logging
2. OpenTelemetry provides long-term observability
3. Hybrid covers both direct API usage and Claude Code SDK

### 9.2 Implementation Strategy

#### Phase 1: Basic Logging (SDK Wrapper)

1. Create wrapper around Anthropic SDK
2. Implement request/response logging
3. Add cost tracking
4. Store in SQLite for simplicity

#### Phase 2: Enhanced Monitoring (OpenTelemetry)

1. Integrate OpenTelemetry exporters
2. Set up Prometheus/Grafana
3. Create dashboards for key metrics
4. Implement alerting

#### Phase 3: Privacy and Security Hardening

1. Implement comprehensive PII redaction
2. Add API key detection and masking
3. Create data retention policies
4. Add audit logging

#### Phase 4: Advanced Analytics

1. Cost attribution by user/project
2. Performance optimization insights
3. Usage pattern analysis
4. Predictive cost modeling

### 9.3 Technical Specifications

#### Proxy Server

- **Language**: Node.js or Python
- **Framework**: Express.js / FastAPI
- **Protocol**: HTTP/HTTPS with TLS termination
- **Port**: 8080 (configurable)

#### Database

- **Development**: SQLite (simple, local)
- **Production**: PostgreSQL (scalable, reliable)
- **Schema**: Normalized with time-series optimization
- **Retention**: 90 days detailed, indefinite aggregates

#### Dashboard

- **Framework**: React or Vue.js
- **Charts**: Chart.js or Recharts
- **Real-time**: WebSocket updates
- **Authentication**: JWT-based

### 9.4 Privacy Configuration

#### Default Settings (Conservative)

- API keys: Always redacted
- User prompts: Logged as hashes only (length recorded)
- Responses: Logged as hashes only (length recorded)
- Metadata: Fully logged
- Retention: 30 days

#### Verbose Settings (Development)

- API keys: Redacted
- User prompts: Logged with PII redaction
- Responses: Logged with PII redaction
- Metadata: Fully logged
- Retention: 90 days

#### Minimal Settings (Production)

- API keys: Redacted
- User prompts: Not logged
- Responses: Not logged
- Metadata: Fully logged
- Retention: 7 days

### 9.5 Cost Estimation

#### Nancy Usage Assumptions

- Average: 100 requests/day
- Average input: 2,000 tokens
- Average output: 500 tokens
- Model: Sonnet 4.5 (70%), Opus 4.5 (30%)

#### Cost Calculation

```
Sonnet: 70 requests/day
  Input:  70 * 2,000 / 1M * $3  = $0.42/day
  Output: 70 * 500 / 1M * $15   = $0.53/day
  Subtotal: $0.95/day

Opus: 30 requests/day
  Input:  30 * 2,000 / 1M * $5  = $0.30/day
  Output: 30 * 500 / 1M * $25   = $0.38/day
  Subtotal: $0.68/day

Total: $1.63/day = $48.90/month
```

**Monitoring overhead**: <1% (negligible latency)

### 9.6 Success Metrics

1. **Coverage**: 100% of API requests logged
2. **Accuracy**: <1% discrepancy with Anthropic's billing
3. **Latency**: <50ms overhead per request
4. **Privacy**: Zero API key leaks in logs
5. **Uptime**: 99.9% proxy availability

## 10. References and Resources

### Official Documentation

- [Messages API Reference](https://docs.claude.com/en/api/messages)
- [Streaming Messages](https://platform.claude.com/docs/en/build-with-claude/streaming)
- [Token Counting](https://platform.claude.com/docs/en/build-with-claude/token-counting)
- [Usage and Cost API](https://docs.anthropic.com/en/api/usage-cost-api)
- [Client SDKs](https://docs.claude.com/en/api/client-sdks)
- [Data Usage](https://code.claude.com/docs/en/data-usage)

### Security and Privacy

- [Anthropic Privacy Center](https://privacy.claude.com/en/)
- [Data Protection](https://privacy.claude.com/en/articles/10458704-how-does-anthropic-protect-the-personal-data-of-claude-users)
- [Claude API Key Security](https://www.nightfall.ai/ai-security-101/anthropic-claude-api-key)
- [Data Loss Prevention Guide](https://toolkit.nightfallai.com/guides/anthropic-claude)

### Monitoring Tools and Integrations

- [Datadog Cloud Cost Management](https://www.datadoghq.com/blog/anthropic-usage-and-costs/)
- [Grafana Cloud Integration](https://grafana.com/blog/how-to-monitor-claude-usage-and-costs-introducing-the-anthropic-integration-for-grafana-cloud/)
- [Claude Code Monitoring](https://code.claude.com/docs/en/monitoring-usage)

### Proxy Projects

- [seifghazi/claude-code-proxy](https://github.com/seifghazi/claude-code-proxy)
- [ccflare](https://ccflare.com/)
- [claude-code-logger](https://github.com/dreampulse/claude-code-logger)
- [AIProxy](https://github.com/uezo/aiproxy)

### Technical Deep Dives

- [Claude Code Internals: SSE Stream Processing](https://kotrotsos.medium.com/claude-code-internals-part-7-sse-stream-processing-c620ae9d64a1)
- [How Streaming LLM APIs Work](https://til.simonwillison.net/llms/streaming-llm-apis)
- [Structured Outputs Guide](https://towardsdatascience.com/hands-on-with-anthropics-new-structured-output-capabilities/)

### Pricing and Costs

- [Anthropic Claude API Pricing 2026](https://www.metacto.com/blogs/anthropic-api-pricing-a-full-breakdown-of-costs-and-integration)
- [Claude Pricing Explained](https://intuitionlabs.ai/articles/claude-pricing-plans-api-costs)
- [Cost and Usage Reporting](https://support.anthropic.com/en/articles/9534590-cost-and-usage-reporting-in-console)

### Community Resources

- [Anthropic SDK Python GitHub](https://github.com/anthropics/anthropic-sdk-python)
- [Anthropic SDK TypeScript GitHub](https://github.com/anthropics/anthropic-sdk-typescript)
- [LiteLLM Anthropic Provider](https://docs.litellm.ai/docs/providers/anthropic)

---

**Document Version**: 1.0
**Last Updated**: 2026-01-26
**Author**: Nancy Research Team
**Status**: Complete
