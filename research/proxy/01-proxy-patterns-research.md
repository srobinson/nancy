# HTTP Proxy Patterns and Architectures for CLI Applications

Research compiled: 2026-01-26

## Executive Summary

This document explores HTTP proxy patterns and architectures for intercepting API requests and responses in CLI applications, with a focus on Node.js implementations. We examine three primary proxy patterns, evaluate modern tooling options, and provide implementation guidance for CLI tools.

## Table of Contents

1. [Proxy Pattern Overview](#proxy-pattern-overview)
2. [Forward Proxy](#forward-proxy)
3. [Reverse Proxy](#reverse-proxy)
4. [Transparent Proxy](#transparent-proxy)
5. [HTTPS Interception Challenges](#https-interception-challenges)
6. [Node.js Implementation Libraries](#nodejs-implementation-libraries)
7. [Implementation Considerations for CLI Tools](#implementation-considerations-for-cli-tools)
8. [Recommended Approaches](#recommended-approaches)
9. [Code Examples](#code-examples)
10. [Security Considerations](#security-considerations)

---

## Proxy Pattern Overview

A proxy server acts as an intermediary between clients and servers, enabling traffic inspection, modification, caching, and policy enforcement. The global web proxy market is projected to reach $50 billion by 2026, driven by privacy and compliance demands.

### Three Primary Patterns

1. **Forward Proxy**: Acts on behalf of clients
2. **Reverse Proxy**: Acts on behalf of servers
3. **Transparent Proxy**: Operates invisibly to clients

---

## Forward Proxy

### Overview

A forward proxy routes traffic between clients and external systems (typically the internet). It operates on behalf of the client, making requests to external servers and returning responses.

### Key Characteristics

- **Client-side placement**: Sits between client applications and the internet
- **Request routing**: Forwards client requests to destination servers
- **IP masking**: Hides client IP addresses from destination servers
- **Access control**: Can block/allow traffic based on policies
- **Caching**: Stores frequently accessed content

### Use Cases

- Privacy protection and anonymity
- Content filtering and access control
- Bandwidth optimization through caching
- Bypassing geographic restrictions
- Corporate internet usage monitoring

### Pros

- **Privacy**: Masks client identity from destination servers
- **Control**: Centralized policy enforcement for outbound traffic
- **Performance**: Caching reduces bandwidth and latency
- **Security**: Can block malicious sites and enforce protocols

### Cons

- **Single point of failure**: Proxy outage blocks all traffic
- **Latency**: Additional hop adds processing time
- **Configuration required**: Clients must be configured to use proxy
- **HTTPS challenges**: Requires certificate trust setup

### Implementation Complexity

**Medium** - Requires:
- HTTP/HTTPS protocol handling
- Certificate management for HTTPS interception
- Policy/routing logic
- Connection pooling and error handling

### Relevance to CLI Tools

**HIGH** - Forward proxies are ideal for CLI tools that need to:
- Intercept outbound API calls
- Log request/response data
- Modify requests before sending
- Mock API responses for testing

---

## Reverse Proxy

### Overview

A reverse proxy sits in front of backend servers, intercepting requests before they reach the origin servers. It operates on behalf of servers, handling client requests and forwarding them to appropriate backends.

### Key Characteristics

- **Server-side placement**: Sits between clients and backend servers
- **Load balancing**: Distributes traffic across multiple servers
- **SSL termination**: Handles encryption/decryption
- **Request routing**: Routes to appropriate backend services
- **Security gateway**: Protects backend infrastructure

### Use Cases

- Load balancing across server pools
- SSL/TLS termination
- Web application firewalls (WAF)
- API gateways
- Caching and compression
- Rate limiting and DDoS protection

### Pros

- **Scalability**: Enables horizontal scaling through load balancing
- **Security**: Hides backend topology and provides security layer
- **Performance**: SSL offloading, caching, compression
- **Flexibility**: Centralized routing and policy enforcement

### Cons

- **Complexity**: Requires infrastructure setup and management
- **Cost**: Additional server resources needed
- **Single point of failure**: Without redundancy, proxy failure blocks all access
- **Configuration overhead**: Complex routing rules and policies

### Implementation Complexity

**High** - Requires:
- Production-grade infrastructure
- Load balancing algorithms
- Health checks and failover logic
- SSL certificate management
- Monitoring and logging

### Relevance to CLI Tools

**LOW** - Reverse proxies are typically used in server infrastructure, not CLI tools. However, understanding the pattern is useful when:
- Building CLI tools that interact with reverse proxy-protected APIs
- Implementing mock API servers for development/testing
- Creating local development proxies

---

## Transparent Proxy

### Overview

A transparent proxy (also called intercepting proxy, inline proxy, or forced proxy) intercepts traffic without requiring client configuration. Clients are unaware of the proxy's existence.

### Key Characteristics

- **Invisible operation**: No client configuration needed
- **Network-level interception**: Uses routing/firewall rules
- **Automatic redirection**: Traffic is silently redirected
- **Protocol transparency**: Works with any protocol

### Use Cases

- ISP-level caching and content filtering
- Corporate policy enforcement
- Parental controls
- Network monitoring and analytics
- Bandwidth management

### Pros

- **No client configuration**: Works without user knowledge or consent
- **Universal coverage**: All traffic automatically intercepted
- **User-friendly**: Zero configuration burden
- **Enforcement**: Users cannot bypass without advanced techniques

### Cons

- **Privacy concerns**: Can inspect traffic without user awareness
- **Ethical issues**: Raises consent and transparency questions
- **Complex setup**: Requires network infrastructure control
- **Protocol limitations**: Some protocols detect and reject transparent proxies
- **HTTPS challenges**: Modern browsers detect certificate manipulation

### Implementation Complexity

**Very High** - Requires:
- Network infrastructure control (routing/iptables)
- Kernel-level packet manipulation
- Certificate injection (for HTTPS)
- Deep protocol understanding
- Operating system privileges

### Relevance to CLI Tools

**LOW to MEDIUM** - Not typically implemented in CLI tools themselves, but CLI tools may need to:
- Detect transparent proxies in the environment
- Work correctly when transparent proxies are present
- Provide options to bypass transparent proxies
- Implement transparent proxying for local development environments

---

## HTTPS Interception Challenges

### The Fundamental Problem

HTTPS uses SSL/TLS encryption to prevent man-in-the-middle attacks. This creates a challenge for legitimate proxies that need to inspect traffic:

1. Client initiates HTTPS connection to server
2. Proxy intercepts the connection
3. Proxy must decrypt traffic to inspect it
4. Client's browser/application detects certificate mismatch
5. Connection fails or shows security warning

### Certificate Trust Chain

For HTTPS interception to work:

1. **Generate CA certificate**: Proxy creates a Certificate Authority (CA)
2. **Install CA certificate**: Add CA to client's trusted certificate store
3. **Dynamic certificate generation**: Proxy generates per-domain certificates signed by its CA
4. **Transparent decryption**: Client trusts proxy's certificates, allowing inspection

### Node.js Certificate Handling

Node.js has unique certificate handling characteristics:

- **Built-in CA list**: Uses Mozilla's CA list, not system certificate store
- **NODE_EXTRA_CA_CERTS**: Environment variable to add custom CAs (Node.js 7.3.0+)
- **Certificate validation**: Strict by default (unlike some browsers)

### Common SSL Errors

- `UNABLE_TO_GET_ISSUER_CERT_LOCALLY`: CA certificate not found
- `UNABLE_TO_VERIFY_FIRST_CERTIFICATE`: Certificate chain incomplete
- `CERT_HAS_EXPIRED`: Certificate validity period expired
- `SELF_SIGNED_CERT_IN_CHAIN`: Self-signed certificate detected

### Solutions for CLI Tools

#### Option 1: User-Installed CA Certificate

**Pros:**
- Secure and proper approach
- Works with all applications
- No security warnings

**Cons:**
- Requires user action
- Administrative privileges needed
- Platform-specific installation

**Implementation:**
```bash
# Generate CA certificate
openssl genrsa -out ca.key 2048
openssl req -new -x509 -days 3650 -key ca.key -out ca.crt

# Set environment variable
export NODE_EXTRA_CA_CERTS=/path/to/ca.crt
```

#### Option 2: Disable Certificate Validation (NOT RECOMMENDED)

**Pros:**
- No setup required
- Works immediately

**Cons:**
- **MAJOR SECURITY RISK**: Exposes to MITM attacks
- Bad practice, should never be used in production
- Creates security vulnerabilities

**Implementation (shown for reference only):**
```javascript
// NEVER DO THIS IN PRODUCTION
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';
```

#### Option 3: Per-Request Certificate Options

**Pros:**
- Fine-grained control
- No global state changes

**Cons:**
- Requires modifying each request
- Application-specific implementation

**Implementation:**
```javascript
const https = require('https');
const fs = require('fs');

const agent = new https.Agent({
  ca: fs.readFileSync('/path/to/ca.crt')
});

https.get('https://api.example.com', { agent }, callback);
```

---

## Node.js Implementation Libraries

### 1. Mockttp (Recommended)

**Overview:**
Mockttp is a modern, actively maintained library that powers HTTP Toolkit. Built in TypeScript, it provides comprehensive HTTP/HTTPS interception capabilities.

**Key Features:**
- Full HTTP/HTTPS support with automatic certificate generation
- Request/response interception and modification
- Mock server and proxy modes
- WebSocket support
- Universal (works in Node.js and browsers)
- TypeScript-first with excellent type definitions
- Active development and maintenance

**Use Cases:**
- Integration testing with real HTTP interception
- Building custom scriptable HTTPS proxies
- API mocking and stubbing
- Traffic inspection and debugging

**Installation:**
```bash
npm install mockttp
```

**Example:**
```javascript
const mockttp = require('mockttp');

async function startProxy() {
  const proxy = mockttp.getLocal();

  await proxy.start(8000);
  console.log(`Proxy listening on port ${proxy.port}`);

  // Intercept and log all requests
  await proxy.forAnyRequest().thenPassThrough({
    beforeRequest: (req) => {
      console.log(`${req.method} ${req.url}`);
    },
    beforeResponse: (res) => {
      console.log(`Status: ${res.statusCode}`);
    }
  });
}
```

**Pros:**
- Modern, actively maintained
- Excellent TypeScript support
- Comprehensive documentation
- Battle-tested (powers HTTP Toolkit)
- Clean, intuitive API

**Cons:**
- Heavier dependency than simple solutions
- May be overkill for basic use cases

**Implementation Complexity:** Medium

**GitHub:** [httptoolkit/mockttp](https://github.com/httptoolkit/mockttp)

---

### 2. mitmproxy (Python + Node.js Bridge)

**Overview:**
mitmproxy is a powerful, mature Python-based proxy with Node.js bindings available through `mitmproxy-node`.

**Key Features:**
- Mature, battle-tested proxy implementation
- Command-line, web, and programmatic interfaces
- HTTP/1, HTTP/2, HTTP/3, WebSocket support
- Interactive traffic inspection
- Request/response rewriting via Node.js scripts

**Use Cases:**
- Deep traffic inspection and debugging
- Security testing and penetration testing
- Complex protocol analysis
- Learning about HTTP internals

**Installation:**
```bash
# Install mitmproxy (Python)
brew install mitmproxy  # macOS
sudo apt install mitmproxy  # Ubuntu/Debian

# Install Node.js bridge
npm install mitmproxy-node
```

**Example (using mitmproxy-node):**
```javascript
const { RequestInterceptor } = require('mitmproxy-node');

const interceptor = new RequestInterceptor({
  onRequest: (req) => {
    console.log(`Request: ${req.method} ${req.url}`);
    return req;
  },
  onResponse: (res) => {
    console.log(`Response: ${res.statusCode}`);
    return res;
  }
});

interceptor.start(8080);
```

**Pros:**
- Extremely powerful and feature-rich
- Excellent CLI tools for manual inspection
- Strong security testing capabilities
- Large, active community

**Cons:**
- Requires Python installation
- More complex setup than pure Node.js solutions
- Steeper learning curve
- Bridge architecture adds complexity

**Implementation Complexity:** High

**Website:** [mitmproxy.org](https://www.mitmproxy.org/)

**GitHub:** [jvilk/mitmproxy-node](https://github.com/jvilk/mitmproxy-node)

---

### 3. node-http-proxy

**Overview:**
A well-established HTTP proxy library for Node.js, providing core proxy functionality without the overhead of more complex solutions.

**Key Features:**
- Simple, focused API
- WebSocket support
- Reverse and forward proxy support
- Custom routing logic
- Lightweight

**Use Cases:**
- Building API gateways
- Simple request forwarding
- Load balancing implementations
- Basic proxy servers

**Installation:**
```bash
npm install http-proxy
```

**Example:**
```javascript
const httpProxy = require('http-proxy');
const proxy = httpProxy.createProxyServer({});

// Create proxy server
const server = require('http').createServer((req, res) => {
  console.log(`Proxying: ${req.method} ${req.url}`);

  proxy.web(req, res, {
    target: 'http://api.example.com',
    changeOrigin: true
  });
});

server.listen(8000);
```

**Pros:**
- Lightweight and fast
- Simple, straightforward API
- Well-established (though maintenance mode)
- Good for basic proxy needs

**Cons:**
- Limited built-in HTTPS interception support
- Requires manual certificate management
- Less feature-rich than modern alternatives
- Minimal documentation updates

**Implementation Complexity:** Medium

**GitHub:** [http-party/node-http-proxy](https://github.com/http-party/node-http-proxy)

---

### 4. AnyProxy

**Overview:**
A fully configurable HTTP/HTTPS proxy from Alibaba, designed for web debugging and testing.

**Key Features:**
- Web interface for traffic inspection
- Rule-based request/response modification
- Certificate generation and management
- HTTPS support out of the box

**Use Cases:**
- Mobile app debugging
- API testing and mocking
- Web development debugging
- Traffic analysis

**Installation:**
```bash
npm install -g anyproxy
anyproxy --port 8001
```

**Example:**
```javascript
const AnyProxy = require('anyproxy');

const options = {
  port: 8001,
  rule: {
    beforeSendRequest(requestDetail) {
      console.log(`Request: ${requestDetail.url}`);
      return requestDetail;
    },
    beforeSendResponse(requestDetail, responseDetail) {
      console.log(`Response: ${responseDetail.response.statusCode}`);
      return responseDetail;
    }
  },
  webInterface: {
    enable: true,
    webPort: 8002
  }
};

const proxyServer = new AnyProxy.ProxyServer(options);
proxyServer.start();
```

**Pros:**
- Great web UI for inspection
- Easy HTTPS setup
- Good for visual debugging

**Cons:**
- **Last updated 5 years ago** (maintenance mode)
- May have security vulnerabilities
- Limited ongoing support
- Documentation may be outdated

**Implementation Complexity:** Medium

**GitHub:** [alibaba/anyproxy](https://github.com/alibaba/anyproxy)

---

### 5. HTTP Toolkit (Desktop Application)

**Overview:**
While not a library, HTTP Toolkit is a complete desktop application for HTTP(S) debugging, built on Mockttp.

**Key Features:**
- Visual traffic inspection
- Automatic certificate management
- Support for multiple languages/runtimes
- Request/response editing
- Mock responses

**Use Cases:**
- Development and debugging
- API exploration
- Security testing
- Learning HTTP protocols

**Pros:**
- No code required
- Excellent UX
- Handles certificates automatically
- Cross-platform

**Cons:**
- Not embeddable in CLI tools
- Desktop application, not library
- Requires separate installation

**Website:** [httptoolkit.com](https://httptoolkit.com/)

---

## Implementation Considerations for CLI Tools

### 1. Architecture Decisions

#### Embedded vs. External Proxy

**Embedded Proxy (Library):**
- Runs within CLI application process
- No additional setup required
- Easier distribution
- Limited to CLI application's traffic

**External Proxy (Standalone):**
- Separate process or service
- Can intercept multiple applications
- More flexible but requires coordination
- Better for system-wide interception

**Recommendation for CLI Tools:** Embedded proxy using libraries like Mockttp

---

### 2. Certificate Management Strategies

#### Strategy A: Automatic Certificate Generation + User Installation

```javascript
const mockttp = require('mockttp');
const fs = require('fs');
const path = require('path');
const os = require('os');

async function setupProxy() {
  const certPath = path.join(os.homedir(), '.mycli', 'certificates');
  const proxy = mockttp.getLocal({
    https: {
      keyPath: path.join(certPath, 'ca.key'),
      certPath: path.join(certPath, 'ca.crt')
    }
  });

  await proxy.start(8000);

  // Provide instructions to user
  console.log('Certificate installation required:');
  console.log(`Certificate: ${path.join(certPath, 'ca.crt')}`);
  console.log('Run: mycli install-cert');

  return proxy;
}
```

**Pros:**
- Secure approach
- Works long-term
- No security warnings

**Cons:**
- Requires user action
- Platform-specific instructions
- May need admin privileges

---

#### Strategy B: Runtime Certificate Injection

```javascript
const https = require('https');
const fs = require('fs');

function createSecureAgent(certPath) {
  return new https.Agent({
    ca: fs.readFileSync(certPath)
  });
}

// Use with requests
const agent = createSecureAgent('./ca.crt');
https.get('https://api.example.com', { agent }, callback);
```

**Pros:**
- No system-level changes
- Scoped to CLI tool
- Easy to implement

**Cons:**
- Requires modifying all HTTPS requests
- Doesn't work for child processes
- Application-specific

---

#### Strategy C: Environment Variable Configuration

```bash
# Set in CLI tool startup
export NODE_EXTRA_CA_CERTS=/path/to/cli/ca.crt
```

**Pros:**
- Works for all Node.js processes spawned by CLI
- Standard Node.js mechanism
- No code changes needed

**Cons:**
- Affects child processes (may be undesired)
- Requires Node.js 7.3.0+
- Limited to Node.js applications

---

### 3. Traffic Routing Strategies

#### Strategy 1: Explicit Proxy Configuration

```javascript
// User sets proxy explicitly
process.env.HTTP_PROXY = 'http://localhost:8000';
process.env.HTTPS_PROXY = 'http://localhost:8000';
```

**Pros:**
- Clear and explicit
- Standard environment variables
- Works with many libraries

**Cons:**
- Requires user configuration
- May conflict with existing proxies
- Not all libraries respect environment variables

---

#### Strategy 2: HTTP Module Patching

```javascript
const http = require('http');
const https = require('https');
const originalRequest = http.request;

http.request = function(options, callback) {
  // Modify options to route through proxy
  options.proxy = 'http://localhost:8000';
  return originalRequest.call(this, options, callback);
};

// Similar for https
```

**Pros:**
- Transparent to application code
- No environment variable setup
- Works with most HTTP clients

**Cons:**
- Fragile (breaks if internal APIs change)
- May not work with all libraries
- Monkey-patching considered harmful

---

#### Strategy 3: Custom HTTP Client Wrapper

```javascript
class ProxiedHttpClient {
  constructor(proxyUrl) {
    this.proxyUrl = proxyUrl;
    this.agent = new https.Agent({ proxy: proxyUrl });
  }

  async get(url, options = {}) {
    return fetch(url, {
      ...options,
      agent: this.agent
    });
  }

  async post(url, body, options = {}) {
    return fetch(url, {
      ...options,
      method: 'POST',
      body: JSON.stringify(body),
      agent: this.agent
    });
  }
}

// Usage
const client = new ProxiedHttpClient('http://localhost:8000');
await client.get('https://api.example.com/data');
```

**Pros:**
- Clean abstraction
- Full control over request behavior
- Easy to test and maintain

**Cons:**
- Requires using custom client throughout codebase
- Doesn't intercept third-party library requests
- More initial implementation work

---

### 4. Performance Considerations

#### Latency Impact

Each proxy hop adds latency:
- **Local proxy**: ~1-5ms overhead
- **Network proxy**: 10-100ms+ depending on distance
- **HTTPS interception**: Additional SSL handshake time

**Mitigation strategies:**
- Use persistent connections (HTTP keep-alive)
- Implement caching for repeated requests
- Compress request/response bodies
- Use HTTP/2 or HTTP/3 when possible

#### Memory Usage

Proxies buffer request/response data:
- **Streaming**: Process data as it arrives (lower memory)
- **Buffering**: Store entire request/response (higher memory, easier manipulation)

**Example (streaming):**
```javascript
await proxy.forAnyRequest().thenPassThrough({
  beforeResponse: (res) => {
    // Stream response without buffering
    return {
      ...res,
      body: res.body.pipeThrough(myTransformStream)
    };
  }
});
```

#### Connection Pool Management

Manage connections efficiently:
- Reuse connections when possible
- Set appropriate timeout values
- Limit concurrent connections
- Handle connection errors gracefully

---

### 5. Error Handling

#### Common Error Scenarios

1. **Proxy startup fails** (port already in use)
2. **Certificate trust issues**
3. **Target server unreachable**
4. **Connection timeouts**
5. **SSL/TLS errors**
6. **Protocol violations**

#### Robust Error Handling Pattern

```javascript
class ProxyManager {
  async start(port = 8000) {
    try {
      await this.proxy.start(port);
      console.log(`Proxy started on port ${port}`);
    } catch (err) {
      if (err.code === 'EADDRINUSE') {
        console.error(`Port ${port} already in use`);
        // Try alternative port
        return this.start(port + 1);
      }
      throw err;
    }
  }

  async stop() {
    try {
      await this.proxy.stop();
    } catch (err) {
      console.error('Error stopping proxy:', err.message);
      // Continue cleanup anyway
    }
  }

  handleRequestError(err, req) {
    console.error(`Request failed: ${req.url}`);
    console.error(`Error: ${err.message}`);

    // Return appropriate error response
    return {
      statusCode: 502,
      body: JSON.stringify({
        error: 'Proxy error',
        message: err.message
      })
    };
  }
}
```

---

### 6. User Experience Considerations

#### Setup Process

**Good UX:**
```bash
# First run detects missing certificate
$ mycli run
⚠️  HTTPS interception requires certificate installation
Run: mycli install-cert

# Install certificate
$ mycli install-cert
✓ Certificate generated
✓ Certificate installed to system store
✓ Ready to intercept HTTPS traffic

# Now works
$ mycli run
✓ Proxy started on port 8000
```

**Poor UX:**
```bash
$ mycli run
Error: UNABLE_TO_GET_ISSUER_CERT_LOCALLY
at TLSSocket.onConnectSecure (_tls_wrap.js:1501:34)
# User has no idea what to do
```

#### Progress Feedback

```javascript
async function startProxyWithFeedback() {
  console.log('Starting proxy...');

  const proxy = mockttp.getLocal();
  await proxy.start(8000);
  console.log('✓ Proxy started on port 8000');

  console.log('Installing certificate...');
  await installCertificate();
  console.log('✓ Certificate installed');

  console.log('Ready to intercept traffic');
}
```

#### Configuration Options

Provide sensible defaults with override options:

```javascript
// Default configuration
const defaultConfig = {
  proxyPort: 8000,
  enableHTTPS: true,
  logLevel: 'info',
  certificatePath: path.join(os.homedir(), '.mycli', 'certs')
};

// User can override via CLI flags or config file
const config = {
  ...defaultConfig,
  ...userConfig
};
```

---

## Recommended Approaches

### For Simple CLI Tools (Request Logging/Inspection)

**Recommended:** Mockttp with embedded proxy

**Why:**
- Modern, actively maintained
- Excellent TypeScript support
- Handles certificate generation automatically
- Clean API for common use cases
- Good documentation

**Setup:**
```javascript
const mockttp = require('mockttp');

async function createProxy() {
  const proxy = mockttp.getLocal();
  await proxy.start(8000);

  // Log all requests
  await proxy.forAnyRequest().thenPassThrough({
    beforeRequest: (req) => {
      console.log(`→ ${req.method} ${req.url}`);
    },
    beforeResponse: (res) => {
      console.log(`← ${res.statusCode}`);
    }
  });

  return proxy;
}
```

---

### For Advanced CLI Tools (Request Modification/Mocking)

**Recommended:** Mockttp with custom rules

**Why:**
- Flexible rule system for complex scenarios
- Can mock specific endpoints
- Can modify requests/responses
- Supports conditional logic

**Setup:**
```javascript
const mockttp = require('mockttp');

async function createAdvancedProxy() {
  const proxy = mockttp.getLocal();
  await proxy.start(8000);

  // Mock specific endpoint
  await proxy.forGet('/api/users').thenJson(200, {
    users: [{ id: 1, name: 'Test User' }]
  });

  // Modify requests to another endpoint
  await proxy.forPost('/api/data').thenPassThrough({
    beforeRequest: (req) => {
      const body = JSON.parse(req.body.text);
      body.injectedBy = 'proxy';
      return {
        ...req,
        body: JSON.stringify(body)
      };
    }
  });

  // Pass through everything else
  await proxy.forAnyRequest().thenPassThrough();

  return proxy;
}
```

---

### For Testing and Development

**Recommended:** Mockttp with mock server mode

**Why:**
- No need for real backend during development
- Deterministic responses for testing
- Fast test execution
- Easy to set up different scenarios

**Setup:**
```javascript
// test/setup.js
const mockttp = require('mockttp');

let mockServer;

beforeEach(async () => {
  mockServer = mockttp.getLocal();
  await mockServer.start(8000);

  // Configure mock responses
  await mockServer.forGet('/api/status').thenJson(200, {
    status: 'ok'
  });
});

afterEach(async () => {
  await mockServer.stop();
});

// test/api.test.js
test('API client handles success', async () => {
  const client = new ApiClient('http://localhost:8000');
  const result = await client.getStatus();
  expect(result.status).toBe('ok');
});
```

---

### For Production Monitoring

**Recommended:** Custom HTTP client wrapper + external monitoring

**Why:**
- No proxy overhead in production
- Direct control over logging
- Integration with monitoring services
- No certificate trust issues

**Setup:**
```javascript
class MonitoredHttpClient {
  constructor(options = {}) {
    this.monitor = options.monitor || console.log;
  }

  async request(url, options = {}) {
    const startTime = Date.now();

    try {
      const response = await fetch(url, options);
      const duration = Date.now() - startTime;

      this.monitor({
        type: 'http_request',
        url,
        method: options.method || 'GET',
        statusCode: response.status,
        duration,
        timestamp: new Date().toISOString()
      });

      return response;
    } catch (err) {
      const duration = Date.now() - startTime;

      this.monitor({
        type: 'http_error',
        url,
        method: options.method || 'GET',
        error: err.message,
        duration,
        timestamp: new Date().toISOString()
      });

      throw err;
    }
  }
}
```

---

## Code Examples

### Example 1: Basic Request Logger

```javascript
const mockttp = require('mockttp');
const fs = require('fs');

class RequestLogger {
  constructor(logFile) {
    this.logFile = logFile;
    this.proxy = null;
  }

  async start(port = 8000) {
    this.proxy = mockttp.getLocal();
    await this.proxy.start(port);

    console.log(`Logging proxy started on port ${port}`);
    console.log(`Logs: ${this.logFile}`);

    await this.proxy.forAnyRequest().thenPassThrough({
      beforeRequest: (req) => this.logRequest(req),
      beforeResponse: (res) => this.logResponse(res)
    });
  }

  logRequest(req) {
    const entry = {
      timestamp: new Date().toISOString(),
      type: 'request',
      method: req.method,
      url: req.url,
      headers: req.headers
    };

    this.writeLog(entry);
  }

  logResponse(res) {
    const entry = {
      timestamp: new Date().toISOString(),
      type: 'response',
      statusCode: res.statusCode,
      headers: res.headers
    };

    this.writeLog(entry);
  }

  writeLog(entry) {
    fs.appendFileSync(
      this.logFile,
      JSON.stringify(entry) + '\n'
    );
  }

  async stop() {
    if (this.proxy) {
      await this.proxy.stop();
      console.log('Proxy stopped');
    }
  }
}

// Usage
async function main() {
  const logger = new RequestLogger('./http-requests.log');
  await logger.start(8000);

  // Keep running until interrupted
  process.on('SIGINT', async () => {
    await logger.stop();
    process.exit(0);
  });
}

main();
```

---

### Example 2: API Mock Server

```javascript
const mockttp = require('mockttp');

class ApiMockServer {
  constructor() {
    this.server = null;
    this.mocks = new Map();
  }

  async start(port = 8000) {
    this.server = mockttp.getLocal();
    await this.server.start(port);
    console.log(`Mock API server started on port ${port}`);
  }

  mock(method, path, response) {
    const key = `${method}:${path}`;
    this.mocks.set(key, response);
  }

  async configure() {
    // Set up mocked endpoints
    for (const [key, response] of this.mocks) {
      const [method, path] = key.split(':');

      if (method === 'GET') {
        await this.server.forGet(path).thenJson(
          response.statusCode || 200,
          response.body
        );
      } else if (method === 'POST') {
        await this.server.forPost(path).thenJson(
          response.statusCode || 200,
          response.body
        );
      }
      // Add more methods as needed
    }

    // Pass through unmocked requests
    await this.server.forAnyRequest().thenPassThrough();
  }

  async stop() {
    if (this.server) {
      await this.server.stop();
    }
  }
}

// Usage
async function main() {
  const mock = new ApiMockServer();

  // Define mocks
  mock.mock('GET', '/api/users', {
    body: [
      { id: 1, name: 'Alice' },
      { id: 2, name: 'Bob' }
    ]
  });

  mock.mock('POST', '/api/users', {
    statusCode: 201,
    body: { id: 3, name: 'Charlie' }
  });

  await mock.start(8000);
  await mock.configure();

  console.log('Mock API ready at http://localhost:8000');
}

main();
```

---

### Example 3: Request/Response Modifier

```javascript
const mockttp = require('mockttp');

class RequestModifier {
  constructor() {
    this.proxy = null;
    this.requestModifiers = [];
    this.responseModifiers = [];
  }

  async start(port = 8000) {
    this.proxy = mockttp.getLocal();
    await this.proxy.start(port);

    await this.proxy.forAnyRequest().thenPassThrough({
      beforeRequest: (req) => this.modifyRequest(req),
      beforeResponse: (res) => this.modifyResponse(res)
    });
  }

  addRequestModifier(fn) {
    this.requestModifiers.push(fn);
  }

  addResponseModifier(fn) {
    this.responseModifiers.push(fn);
  }

  async modifyRequest(req) {
    let modified = req;

    for (const modifier of this.requestModifiers) {
      modified = await modifier(modified);
    }

    return modified;
  }

  async modifyResponse(res) {
    let modified = res;

    for (const modifier of this.responseModifiers) {
      modified = await modifier(modified);
    }

    return modified;
  }

  async stop() {
    if (this.proxy) {
      await this.proxy.stop();
    }
  }
}

// Usage
async function main() {
  const modifier = new RequestModifier();

  // Add API key to all requests
  modifier.addRequestModifier((req) => {
    return {
      ...req,
      headers: {
        ...req.headers,
        'X-API-Key': 'my-secret-key'
      }
    };
  });

  // Add custom header to all responses
  modifier.addResponseModifier((res) => {
    return {
      ...res,
      headers: {
        ...res.headers,
        'X-Proxied-By': 'my-cli-tool'
      }
    };
  });

  await modifier.start(8000);
  console.log('Request modifier running on port 8000');
}

main();
```

---

### Example 4: Certificate Management

```javascript
const mockttp = require('mockttp');
const fs = require('fs');
const path = require('path');
const os = require('os');
const { execSync } = require('child_process');

class CertificateManager {
  constructor(appName) {
    this.appName = appName;
    this.certDir = path.join(os.homedir(), `.${appName}`, 'certs');
    this.caKeyPath = path.join(this.certDir, 'ca.key');
    this.caCertPath = path.join(this.certDir, 'ca.crt');
  }

  certificateExists() {
    return fs.existsSync(this.caKeyPath) &&
           fs.existsSync(this.caCertPath);
  }

  generateCertificate() {
    if (this.certificateExists()) {
      console.log('Certificate already exists');
      return;
    }

    // Create directory
    fs.mkdirSync(this.certDir, { recursive: true });

    // Generate CA key
    execSync(
      `openssl genrsa -out "${this.caKeyPath}" 2048`,
      { stdio: 'inherit' }
    );

    // Generate CA certificate
    execSync(
      `openssl req -new -x509 -days 3650 ` +
      `-key "${this.caKeyPath}" -out "${this.caCertPath}" ` +
      `-subj "/CN=${this.appName} CA"`,
      { stdio: 'inherit' }
    );

    console.log('✓ Certificate generated');
    console.log(`  Key: ${this.caKeyPath}`);
    console.log(`  Certificate: ${this.caCertPath}`);
  }

  installCertificate() {
    if (!this.certificateExists()) {
      throw new Error('Certificate not generated. Run generateCertificate() first.');
    }

    const platform = os.platform();

    try {
      if (platform === 'darwin') {
        // macOS
        execSync(
          `sudo security add-trusted-cert -d -r trustRoot ` +
          `-k /Library/Keychains/System.keychain "${this.caCertPath}"`,
          { stdio: 'inherit' }
        );
        console.log('✓ Certificate installed (macOS)');
      } else if (platform === 'linux') {
        // Linux (Debian/Ubuntu)
        execSync(
          `sudo cp "${this.caCertPath}" /usr/local/share/ca-certificates/ && ` +
          `sudo update-ca-certificates`,
          { stdio: 'inherit' }
        );
        console.log('✓ Certificate installed (Linux)');
      } else if (platform === 'win32') {
        // Windows
        execSync(
          `certutil -addstore -f "ROOT" "${this.caCertPath}"`,
          { stdio: 'inherit' }
        );
        console.log('✓ Certificate installed (Windows)');
      } else {
        throw new Error(`Unsupported platform: ${platform}`);
      }
    } catch (err) {
      console.error('Failed to install certificate:', err.message);
      console.log('\nManual installation instructions:');
      console.log(`Certificate: ${this.caCertPath}`);
      throw err;
    }
  }

  uninstallCertificate() {
    const platform = os.platform();

    try {
      if (platform === 'darwin') {
        execSync(
          `sudo security delete-certificate -c "${this.appName} CA" ` +
          `/Library/Keychains/System.keychain`,
          { stdio: 'inherit' }
        );
        console.log('✓ Certificate uninstalled (macOS)');
      } else if (platform === 'linux') {
        execSync(
          `sudo rm /usr/local/share/ca-certificates/${this.appName}-ca.crt && ` +
          `sudo update-ca-certificates`,
          { stdio: 'inherit' }
        );
        console.log('✓ Certificate uninstalled (Linux)');
      } else if (platform === 'win32') {
        execSync(
          `certutil -delstore "ROOT" "${this.appName} CA"`,
          { stdio: 'inherit' }
        );
        console.log('✓ Certificate uninstalled (Windows)');
      }
    } catch (err) {
      console.error('Failed to uninstall certificate:', err.message);
    }
  }

  getProxyConfig() {
    if (!this.certificateExists()) {
      throw new Error('Certificate not found. Run generateCertificate() first.');
    }

    return {
      https: {
        keyPath: this.caKeyPath,
        certPath: this.caCertPath
      }
    };
  }
}

// Usage
async function main() {
  const certManager = new CertificateManager('mycli');

  // Generate certificate if needed
  if (!certManager.certificateExists()) {
    certManager.generateCertificate();
  }

  // Start proxy with certificate
  const proxy = mockttp.getLocal(certManager.getProxyConfig());
  await proxy.start(8000);

  console.log('Proxy started with HTTPS support');

  // Provide installation instructions
  console.log('\nTo intercept HTTPS traffic, install the certificate:');
  console.log('  mycli install-cert');
}
```

---

### Example 5: CLI Integration

```javascript
#!/usr/bin/env node

const { Command } = require('commander');
const mockttp = require('mockttp');
const CertificateManager = require('./cert-manager');
const RequestLogger = require('./request-logger');

const program = new Command();

program
  .name('mycli')
  .description('CLI tool with HTTP interception')
  .version('1.0.0');

program
  .command('proxy')
  .description('Start HTTP proxy')
  .option('-p, --port <port>', 'Proxy port', '8000')
  .option('--log <file>', 'Log file path', './requests.log')
  .action(async (options) => {
    const logger = new RequestLogger(options.log);
    await logger.start(parseInt(options.port));

    console.log('Press Ctrl+C to stop');

    process.on('SIGINT', async () => {
      await logger.stop();
      process.exit(0);
    });
  });

program
  .command('install-cert')
  .description('Install HTTPS certificate')
  .action(() => {
    const certManager = new CertificateManager('mycli');

    if (!certManager.certificateExists()) {
      certManager.generateCertificate();
    }

    certManager.installCertificate();
  });

program
  .command('uninstall-cert')
  .description('Uninstall HTTPS certificate')
  .action(() => {
    const certManager = new CertificateManager('mycli');
    certManager.uninstallCertificate();
  });

program
  .command('cert-status')
  .description('Check certificate status')
  .action(() => {
    const certManager = new CertificateManager('mycli');

    if (certManager.certificateExists()) {
      console.log('✓ Certificate exists');
      console.log(`  Path: ${certManager.caCertPath}`);
    } else {
      console.log('✗ Certificate not found');
      console.log('  Run: mycli install-cert');
    }
  });

program.parse();
```

---

## Security Considerations

### 1. Certificate Management

**Risks:**
- Private keys stored on disk can be compromised
- Certificates with long validity periods increase risk
- System-wide certificate trust affects all applications

**Best Practices:**
- Generate unique certificates per installation
- Use strong key sizes (2048-bit RSA minimum, 4096-bit preferred)
- Store private keys with restricted permissions (chmod 600)
- Provide easy uninstall/revocation mechanism
- Display clear warnings about HTTPS interception
- Document security implications in README

**Implementation:**
```javascript
function secureCertificateStorage(keyPath, certPath) {
  const fs = require('fs');

  // Set restrictive permissions on private key
  fs.chmodSync(keyPath, 0o600);  // Owner read/write only

  // Certificate can be more permissive
  fs.chmodSync(certPath, 0o644);  // Owner write, all read

  console.log('✓ Certificate permissions secured');
}
```

---

### 2. Data Privacy

**Risks:**
- Proxies can intercept sensitive data (passwords, API keys, etc.)
- Logs may contain personally identifiable information (PII)
- Request/response bodies may include confidential data

**Best Practices:**
- Sanitize logged data (remove sensitive headers, redact PII)
- Encrypt log files if they contain sensitive information
- Provide opt-out mechanisms for logging
- Document what data is collected and how it's used
- Implement automatic log rotation and cleanup
- Never log passwords, tokens, or credit card numbers

**Implementation:**
```javascript
const SENSITIVE_HEADERS = [
  'authorization',
  'cookie',
  'x-api-key',
  'x-auth-token'
];

function sanitizeHeaders(headers) {
  const sanitized = { ...headers };

  for (const header of SENSITIVE_HEADERS) {
    if (sanitized[header]) {
      sanitized[header] = '[REDACTED]';
    }
  }

  return sanitized;
}

function sanitizeBody(body, contentType) {
  if (contentType && contentType.includes('json')) {
    try {
      const parsed = JSON.parse(body);

      // Redact sensitive fields
      if (parsed.password) parsed.password = '[REDACTED]';
      if (parsed.apiKey) parsed.apiKey = '[REDACTED]';
      if (parsed.token) parsed.token = '[REDACTED]';

      return JSON.stringify(parsed);
    } catch {
      return '[INVALID JSON]';
    }
  }

  return '[BINARY DATA]';
}
```

---

### 3. Network Security

**Risks:**
- Proxy server exposed on network interface
- Unencrypted proxy traffic on localhost
- Proxy could be abused by other applications/users

**Best Practices:**
- Bind proxy to localhost (127.0.0.1) only, not 0.0.0.0
- Implement authentication if proxy must be network-accessible
- Use firewall rules to restrict access
- Monitor for unusual traffic patterns
- Implement rate limiting to prevent abuse

**Implementation:**
```javascript
async function startSecureProxy() {
  const proxy = mockttp.getLocal({
    // Bind to localhost only
    host: '127.0.0.1',
    port: 8000
  });

  await proxy.start();

  console.log('✓ Proxy listening on 127.0.0.1:8000 (localhost only)');
  console.log('  Not accessible from network');
}
```

---

### 4. Code Injection Risks

**Risks:**
- Modified requests/responses could execute malicious code
- User-provided configuration could inject malicious rules
- Dynamic code evaluation could lead to RCE

**Best Practices:**
- Validate all user input strictly
- Avoid using `eval()` or `Function()` constructors
- Sanitize URLs before making requests
- Use parameterized queries/templates
- Implement Content Security Policy (CSP) for any web interfaces

**Implementation:**
```javascript
function validateUrl(url) {
  try {
    const parsed = new URL(url);

    // Only allow HTTP and HTTPS
    if (!['http:', 'https:'].includes(parsed.protocol)) {
      throw new Error('Invalid protocol');
    }

    // Block private IP ranges if needed
    const host = parsed.hostname;
    if (host === 'localhost' || host === '127.0.0.1') {
      throw new Error('Cannot proxy to localhost');
    }

    return parsed;
  } catch (err) {
    throw new Error(`Invalid URL: ${err.message}`);
  }
}
```

---

### 5. Dependency Security

**Risks:**
- Third-party libraries may have vulnerabilities
- Outdated dependencies may be exploited
- Supply chain attacks via compromised packages

**Best Practices:**
- Regularly update dependencies
- Use `npm audit` to check for vulnerabilities
- Pin dependency versions in production
- Use lockfiles (package-lock.json)
- Monitor security advisories
- Consider using Snyk or Dependabot

**Implementation:**
```bash
# Regular security audits
npm audit

# Fix vulnerabilities automatically
npm audit fix

# Check for outdated packages
npm outdated

# Update specific package
npm update mockttp
```

---

### 6. Least Privilege Principle

**Risks:**
- Running proxy with elevated privileges increases attack surface
- Unnecessary permissions could be exploited

**Best Practices:**
- Run proxy as non-root user when possible
- Request elevated privileges only when necessary (certificate installation)
- Drop privileges after initial setup
- Document why each permission is needed

**Implementation:**
```javascript
function checkPermissions() {
  if (process.getuid && process.getuid() === 0) {
    console.warn('⚠️  Running as root is not recommended');
    console.warn('   Consider running as a regular user');
  }
}

function requireElevatedPrivileges(reason) {
  if (process.getuid && process.getuid() !== 0) {
    console.error(`This operation requires administrator privileges:`);
    console.error(`  ${reason}`);
    console.error('Please run with sudo or as administrator');
    process.exit(1);
  }
}
```

---

## Conclusion

### Summary

HTTP proxy patterns provide powerful capabilities for CLI tools to intercept, inspect, and modify network traffic. The three primary patterns (forward, reverse, transparent) each serve different purposes:

- **Forward proxies** are ideal for CLI tools, providing client-side interception
- **Reverse proxies** are server-side and less relevant for CLI applications
- **Transparent proxies** require system-level access and are complex to implement

### Key Takeaways

1. **Mockttp is the recommended library** for modern Node.js CLI tools due to its active maintenance, excellent TypeScript support, and comprehensive features

2. **HTTPS interception requires careful certificate management** - provide clear user guidance and secure storage

3. **Security is paramount** - sanitize logs, restrict network access, validate input, and document privacy implications

4. **User experience matters** - provide clear setup instructions, helpful error messages, and sensible defaults

5. **Consider alternatives** - for production monitoring, a custom HTTP client wrapper may be simpler than a full proxy

### Next Steps

For implementing HTTP interception in a CLI tool:

1. **Prototype with Mockttp** - Start with basic request logging
2. **Implement certificate management** - Create user-friendly install/uninstall commands
3. **Add security measures** - Sanitize logs, restrict access, validate input
4. **Polish UX** - Clear error messages, progress indicators, helpful documentation
5. **Test thoroughly** - Various network conditions, error scenarios, edge cases

### Additional Resources

- [Mockttp Documentation](https://github.com/httptoolkit/mockttp)
- [HTTP Toolkit Blog](https://httptoolkit.com/blog/)
- [Node.js TLS Documentation](https://nodejs.org/api/tls.html)
- [Node.js Security Best Practices](https://nodejs.org/en/learn/getting-started/security-best-practices)

---

## Sources

- [What is a Transparent Proxy and How is It Used?](https://oxylabs.io/blog/what-is-transparent-proxy)
- [What is a Transparent Proxy | Client vs. Server Side Use Cases | Imperva](https://www.imperva.com/learn/ddos/transparent-proxy/)
- [Proxy Servers Explained: Types, Use Cases & Trends in 2025 [Technical Deep Dive] - MarkTechPost](https://www.marktechpost.com/2025/08/08/proxy-servers-explained-types-use-cases-trends-in-2025-technical-deep-dive/)
- [Comparing Forward Proxies and Reverse Proxies | ScrapingBee](https://www.scrapingbee.com/blog/comparing-forward-proxies-and-reverse-proxies/)
- [mitmproxy - an interactive HTTPS proxy](https://www.mitmproxy.org/)
- [Build an HTTPS-intercepting JavaScript proxy in 30 seconds flat](https://httptoolkit.com/blog/javascript-mitm-proxy-mockttp/)
- [GitHub - jvilk/mitmproxy-node: A bridge between Python's mitmproxy and Node.JS programs](https://github.com/jvilk/mitmproxy-node)
- [GitHub - alibaba/anyproxy: A fully configurable http/https proxy in NodeJS](https://github.com/alibaba/anyproxy)
- [GitHub - http-party/node-http-proxy: A full-featured http proxy for node.js](https://github.com/http-party/node-http-proxy)
- [GitHub - httptoolkit/mockttp: Powerful friendly HTTP mock server & proxy library](https://github.com/httptoolkit/mockttp)
- [Step-by-Step Guide to Fixing Node.js SSL Certificate Errors - DEV Community](https://dev.to/hardy_mervana/step-by-step-guide-to-fixing-nodejs-ssl-certificate-errors-2il2)
- [TLS (SSL) | Node.js v25.3.0 Documentation](https://nodejs.org/api/tls.html)
- [Node.js — Security Best Practices](https://nodejs.org/en/learn/getting-started/security-best-practices)
- [The Proxy Pattern: A Masterpiece of Control and Illusion in Node.js - DEV Community](https://dev.to/alex_aslam/the-proxy-pattern-a-masterpiece-of-control-and-illusion-in-nodejs-6dg)

---

**Research compiled by:** Claude (Anthropic)
**Date:** 2026-01-26
**Version:** 1.0
