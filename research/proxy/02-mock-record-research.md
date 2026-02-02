# Mock and Record Strategies for API Testing

## Executive Summary

This document explores various strategies for recording and replaying API interactions in testing environments. These patterns enable fast, deterministic, and reliable tests by capturing real HTTP traffic and replaying it in subsequent test runs, eliminating dependencies on live services.

## 1. Core Patterns

### 1.1 VCR (Video Cassette Recorder) Pattern

The VCR pattern is the foundational approach for recording and replaying HTTP interactions. It records API requests and responses to "cassette" files that can be replayed in future test runs.

**Key Characteristics:**
- First test run makes live HTTP calls and records them
- Subsequent runs replay recorded interactions
- Provides 50x+ speed improvements in many implementations
- Enables offline testing
- Ensures deterministic test behavior

**Available Implementations:**
- **Ruby**: Original vcr gem
- **Python**: VCR.py
- **Go**: go-vcr
- **Node.js**: Various implementations (yakbak, Polly.JS)
- **Swift**: Replay (uses HAR format)
- **R**: vcr package
- **PHP**: PHP-VCR

**Core Features:**
- Sensitive data filtering/censoring
- Custom matching rules (method, URI, headers, body)
- Recording modes (once, new_episodes, all, none)
- Automatic cassette management

### 1.2 HAR (HTTP Archive) Format

HAR files provide a standardized JSON format for logging browser-server interactions. Modern tools increasingly prefer HAR over custom formats due to ecosystem compatibility.

**Advantages:**
- Standard format supported by browser DevTools
- Compatible with Charles Proxy, Proxyman, etc.
- Can be generated directly from browsers
- Rich ecosystem of tools

**Structure:**
```json
{
  "log": {
    "version": "1.2",
    "creator": {...},
    "entries": [
      {
        "request": {
          "method": "GET",
          "url": "https://api.example.com/users",
          "headers": [...],
          "queryString": [...],
          "postData": {...}
        },
        "response": {
          "status": 200,
          "statusText": "OK",
          "headers": [...],
          "content": {
            "mimeType": "application/json",
            "text": "{...}"
          }
        },
        "time": 123,
        "timings": {...}
      }
    ]
  }
}
```

**Testing Framework Support:**
- **Playwright**: `page.routeFromHAR()` and `browserContext.routeFromHAR()`
- **Testim**: Native HAR file mocking
- **Microcks**: Specialized HAR-based API mocking

**Security Note:**
HAR files can contain sensitive data including authentication tokens, API keys, and session cookies. Always sanitize before committing to version control.

### 1.3 Traffic-Driven Mock Generation

Modern approach that generates mocks automatically from real production or staging traffic.

**Benefits:**
- Most realistic test scenarios
- Captures edge cases and unusual patterns
- Reduces manual mock creation effort
- Reflects actual user behavior

**Key Tools:**
- **Speedscale**: Automatically generates mocks from recorded traffic
- **WireMock**: Recording and playback capabilities
- **Hoverfly**: Lightweight service virtualization with traffic capture
- **GoReplay**: Production traffic capture and replay

**Use Cases:**
- Complex multi-step API flows
- Dynamic data scenarios
- Performance testing with realistic loads
- Understanding production behavior patterns

## 2. Node.js Libraries and Tools

### 2.1 Nock

HTTP server mocking and expectations library for Node.js. The most popular choice with 5.2M weekly downloads.

**Strengths:**
- Works by overriding Node's `http.request` function
- Library-agnostic (works with Axios, Fetch, etc.)
- Combines mocking and assertions
- 15 years of maturity and stability
- Migrated to Interceptors (foundation of MSW)

**Basic Usage:**
```javascript
const nock = require('nock');

// Define mock
nock('https://api.example.com')
  .get('/users/123')
  .reply(200, {
    id: 123,
    name: 'John Doe',
    email: 'john@example.com'
  });

// Recording real interactions
nock.recorder.rec({
  output_objects: true,
  dont_print: true
});

// Make real API calls...

// Get recorded interactions
const nockCallObjects = nock.recorder.play();

// Save to file for replay
fs.writeFileSync('fixtures.json', JSON.stringify(nockCallObjects, null, 2));
```

**Advanced Features:**
```javascript
// Conditional responses
nock('https://api.example.com')
  .get('/users')
  .query({ page: 1 })
  .reply(200, { users: [...] })
  .get('/users')
  .query({ page: 2 })
  .reply(200, { users: [...] });

// Dynamic responses
nock('https://api.example.com')
  .post('/users')
  .reply((uri, requestBody) => {
    return [201, { id: Date.now(), ...requestBody }];
  });

// Request matching with regex
nock('https://api.example.com')
  .get(/^\/users\/\d+$/)
  .reply(200, { id: 1, name: 'User' });

// Scoped mocks with cleanup
const scope = nock('https://api.example.com')
  .get('/users')
  .reply(200, {...});

// After test
scope.isDone(); // Assert all mocks were called
nock.cleanAll(); // Clear all mocks
```

### 2.2 Polly.JS

Recording, replaying, and stubbing HTTP interactions with a VCR-style approach.

**Strengths:**
- Automatic recording and replaying
- Supports both client and server-side
- Response modification capabilities
- Request matching rules
- 28K weekly downloads

**Basic Usage:**
```javascript
import { Polly } from '@pollyjs/core';
import XHRAdapter from '@pollyjs/adapter-xhr';
import FetchAdapter from '@pollyjs/adapter-fetch';
import FSPersister from '@pollyjs/persister-fs';

Polly.register(XHRAdapter);
Polly.register(FetchAdapter);
Polly.register(FSPersister);

const polly = new Polly('My Test', {
  adapters: ['xhr', 'fetch'],
  persister: 'fs',
  persisterOptions: {
    fs: {
      recordingsDir: './recordings'
    }
  },
  recordIfMissing: true
});

// Your API calls happen here

await polly.stop(); // Save recordings
```

**Configuration:**
```javascript
const polly = new Polly('Test Name', {
  mode: 'replay', // 'record', 'replay', 'passthrough', 'stopped'
  recordIfMissing: true,
  matchRequestsBy: {
    method: true,
    headers: { exclude: ['user-agent', 'authorization'] },
    body: true,
    order: true
  }
});

// Intercept and modify
polly.server
  .get('/api/users')
  .intercept((req, res) => {
    res.status(200).json({ users: [...] });
  });

// Passthrough for specific routes
polly.server
  .get('/api/health')
  .passthrough();
```

**Limitations:**
- Learning curve for new users
- Less popular than Nock
- More complex setup

### 2.3 Mock Service Worker (MSW)

Modern approach that works in both browser and Node.js environments.

**Strengths:**
- Seamless browser and Node.js mocking
- First-class GraphQL support
- Standard-based request/response handling
- Uses Service Workers in browser, Interceptors in Node.js
- Growing rapidly in popularity

**Basic Usage:**
```javascript
import { http, HttpResponse } from 'msw';
import { setupServer } from 'msw/node';

// Define handlers
const handlers = [
  http.get('https://api.example.com/users', () => {
    return HttpResponse.json([
      { id: 1, name: 'John' },
      { id: 2, name: 'Jane' }
    ]);
  }),

  http.post('https://api.example.com/users', async ({ request }) => {
    const body = await request.json();
    return HttpResponse.json(
      { id: 3, ...body },
      { status: 201 }
    );
  })
];

// Setup server
const server = setupServer(...handlers);

// Enable mocking
beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());
```

**GraphQL Support:**
```javascript
import { graphql, HttpResponse } from 'msw';

const handlers = [
  graphql.query('GetUser', ({ variables }) => {
    return HttpResponse.json({
      data: {
        user: {
          id: variables.id,
          name: 'John Doe'
        }
      }
    });
  })
];
```

### 2.4 yakbak

Simple record and playback tool from Flickr.

**Characteristics:**
- Creates standard Node.js http.Server with proxy middleware
- Each "tape" is its own module exporting http.Server handler
- Lightweight and straightforward

**Basic Usage:**
```javascript
const yakbak = require('yakbak');
const express = require('express');

const app = express();

app.use(yakbak('https://api.example.com', {
  dirname: __dirname + '/tapes',
  noRecord: process.env.YAKBAK_NO_RECORD === 'true'
}));

app.listen(3000);
```

### 2.5 HTTP Proxy Tools

For more control over interception and recording:

**Mockttp** (HTTP Toolkit):
```javascript
const mockttp = require('mockttp');

const mockServer = mockttp.getLocal();
await mockServer.start();

// Record all traffic
const seenRequests = [];
await mockServer.forAnyRequest().thenCallback((req) => {
  seenRequests.push({
    method: req.method,
    url: req.url,
    headers: req.headers,
    body: req.body.text
  });
  return { statusCode: 200, body: 'Recorded' };
});

// Later: replay recorded requests
```

**Hoxy**:
```javascript
const hoxy = require('hoxy');
const proxy = hoxy.createServer();

proxy.intercept('request', (req, resp) => {
  console.log('Request:', req.method, req.url);
});

proxy.intercept('response', (req, resp) => {
  console.log('Response:', resp.statusCode);
  // Save to file
});

proxy.listen(8080);
```

**http-proxy-middleware**:
```javascript
const { createProxyMiddleware, responseInterceptor } = require('http-proxy-middleware');

app.use('/api', createProxyMiddleware({
  target: 'https://api.example.com',
  changeOrigin: true,
  selfHandleResponse: true,
  onProxyRes: responseInterceptor(async (responseBuffer, proxyRes, req, res) => {
    // Save response
    const response = responseBuffer.toString('utf8');
    saveToFile(req.path, response);
    return responseBuffer;
  })
}));
```

## 3. Storage Formats

### 3.1 Format Comparison

| Format | Pros | Cons | Best For |
|--------|------|------|----------|
| **JSON** | Fast parsing, widely supported, easy to read | No comments, verbose for large data | API responses, structured data |
| **YAML** | Human-readable, supports comments, compact | Slower parsing, whitespace-sensitive | Configuration, documentation |
| **HAR** | Standard format, tool ecosystem, rich metadata | Verbose, complex structure | Browser traffic, cross-tool compatibility |
| **Custom** | Optimized for specific needs | Requires custom tooling | Specialized use cases |

### 3.2 Cassette Storage Strategies

**Flat File Structure:**
```
fixtures/
  api-users-list.json
  api-users-123.json
  api-posts-create.json
```

**Organized by Test:**
```
fixtures/
  user-tests/
    list-users.json
    get-user.json
    create-user.json
  post-tests/
    list-posts.json
    create-post.json
```

**Organized by Endpoint:**
```
fixtures/
  users/
    GET-list.json
    GET-123.json
    POST-create.json
  posts/
    GET-list.json
```

**Single File per Test Suite:**
```
fixtures/
  user-api-suite.json  // Contains all user-related cassettes
  post-api-suite.json  // Contains all post-related cassettes
```

### 3.3 JSON Cassette Format

**Nock Format:**
```json
[
  {
    "scope": "https://api.example.com",
    "method": "GET",
    "path": "/users/123",
    "body": "",
    "status": 200,
    "response": {
      "id": 123,
      "name": "John Doe",
      "email": "john@example.com"
    },
    "responseHeaders": {
      "content-type": "application/json",
      "cache-control": "no-cache"
    }
  }
]
```

**VCR-style Format:**
```json
{
  "http_interactions": [
    {
      "request": {
        "method": "GET",
        "uri": "https://api.example.com/users/123",
        "body": {
          "encoding": "UTF-8",
          "string": ""
        },
        "headers": {
          "User-Agent": ["My App/1.0"],
          "Accept": ["application/json"]
        }
      },
      "response": {
        "status": {
          "code": 200,
          "message": "OK"
        },
        "headers": {
          "Content-Type": ["application/json"]
        },
        "body": {
          "encoding": "UTF-8",
          "string": "{\"id\":123,\"name\":\"John Doe\"}"
        }
      },
      "recorded_at": "2026-01-26T12:00:00Z"
    }
  ],
  "recorded_with": "VCR 6.0.0"
}
```

### 3.4 YAML Cassette Format

**VCR.py Default:**
```yaml
version: 1
interactions:
- request:
    method: GET
    uri: https://api.example.com/users/123
    body: null
    headers:
      User-Agent:
      - My App/1.0
      Accept:
      - application/json
  response:
    status:
      code: 200
      message: OK
    headers:
      Content-Type:
      - application/json
    body:
      string: '{"id":123,"name":"John Doe"}'
    recorded_at: '2026-01-26T12:00:00Z'
```

**Benefits:**
- Comments for documentation
- More compact than JSON
- Better for version control diffs

**Drawbacks:**
- Slower parsing
- Whitespace sensitivity can cause issues

## 4. Integration Patterns

### 4.1 Test Setup Patterns

**Pattern 1: Automatic Recording in Development**
```javascript
import nock from 'nock';
import fs from 'fs';
import path from 'path';

const FIXTURES_DIR = './fixtures';
const RECORDING_MODE = process.env.RECORDING_MODE || 'replay';

function setupNock(testName) {
  const fixturePath = path.join(FIXTURES_DIR, `${testName}.json`);

  if (RECORDING_MODE === 'record') {
    nock.recorder.rec({
      output_objects: true,
      dont_print: true
    });
  } else if (RECORDING_MODE === 'replay') {
    if (fs.existsSync(fixturePath)) {
      const fixtures = JSON.parse(fs.readFileSync(fixturePath, 'utf8'));
      nock.define(fixtures);
    } else {
      throw new Error(`Fixture not found: ${fixturePath}`);
    }
  }
  // 'passthrough' mode: no nock setup
}

function teardownNock(testName) {
  if (RECORDING_MODE === 'record') {
    const fixturePath = path.join(FIXTURES_DIR, `${testName}.json`);
    const recorded = nock.recorder.play();
    fs.writeFileSync(fixturePath, JSON.stringify(recorded, null, 2));
  }
  nock.restore();
  nock.cleanAll();
}

// Usage in tests
beforeEach(() => setupNock('my-test'));
afterEach(() => teardownNock('my-test'));
```

**Pattern 2: Fixture Helper with Modes**
```javascript
class FixtureManager {
  constructor(options = {}) {
    this.mode = options.mode || 'replay';
    this.fixturesDir = options.fixturesDir || './fixtures';
    this.updateSnapshots = options.updateSnapshots || false;
  }

  async setup(testName) {
    switch (this.mode) {
      case 'record':
        return this.startRecording();
      case 'replay':
        return this.loadFixture(testName);
      case 'update':
        return this.startRecording(); // Record to update
      case 'passthrough':
        return; // No mocking
    }
  }

  async teardown(testName) {
    if (this.mode === 'record' || this.mode === 'update') {
      await this.saveFixture(testName);
    }
  }

  startRecording() {
    nock.recorder.rec({
      output_objects: true,
      dont_print: true
    });
  }

  loadFixture(testName) {
    const fixturePath = path.join(this.fixturesDir, `${testName}.json`);
    if (!fs.existsSync(fixturePath)) {
      throw new Error(`Missing fixture: ${fixturePath}. Run with RECORDING_MODE=record`);
    }
    const fixtures = JSON.parse(fs.readFileSync(fixturePath, 'utf8'));
    nock.define(fixtures);
  }

  async saveFixture(testName) {
    const fixturePath = path.join(this.fixturesDir, `${testName}.json`);
    const recorded = nock.recorder.play();

    // Sanitize sensitive data
    const sanitized = this.sanitize(recorded);

    fs.writeFileSync(fixturePath, JSON.stringify(sanitized, null, 2));
  }

  sanitize(fixtures) {
    return fixtures.map(fixture => {
      // Remove authorization headers
      if (fixture.reqheaders) {
        delete fixture.reqheaders.authorization;
        delete fixture.reqheaders.cookie;
      }

      // Mask sensitive response data
      if (fixture.response && typeof fixture.response === 'object') {
        if (fixture.response.token) {
          fixture.response.token = 'REDACTED';
        }
        if (fixture.response.apiKey) {
          fixture.response.apiKey = 'REDACTED';
        }
      }

      return fixture;
    });
  }
}

// Usage
const fixtures = new FixtureManager({
  mode: process.env.FIXTURE_MODE || 'replay',
  fixturesDir: './test/fixtures'
});

beforeEach(() => fixtures.setup(test.name));
afterEach(() => fixtures.teardown(test.name));
```

**Pattern 3: Per-Test Configuration**
```javascript
describe('User API', () => {
  it('fetches user list', async () => {
    await useFixture('user-list', async () => {
      const users = await api.getUsers();
      expect(users).toHaveLength(10);
    });
  });

  it('creates new user', async () => {
    await useFixture('user-create', async () => {
      const user = await api.createUser({ name: 'John' });
      expect(user.id).toBeDefined();
    });
  });
});

async function useFixture(name, testFn) {
  const manager = new FixtureManager();
  await manager.setup(name);
  try {
    await testFn();
  } finally {
    await manager.teardown(name);
  }
}
```

### 4.2 CI/CD Integration

**GitHub Actions Example:**
```yaml
name: Test Suite

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'

      - name: Install dependencies
        run: npm ci

      - name: Run tests (replay mode)
        run: npm test
        env:
          FIXTURE_MODE: replay

      - name: Verify fixtures are up to date
        run: |
          FIXTURE_MODE=record npm test
          if ! git diff --quiet test/fixtures/; then
            echo "Fixtures are outdated. Run 'FIXTURE_MODE=record npm test' locally."
            exit 1
          fi
        if: github.event_name == 'pull_request'

  integration-test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'

      - name: Install dependencies
        run: npm ci

      - name: Run integration tests (live APIs)
        run: npm run test:integration
        env:
          FIXTURE_MODE: passthrough
          API_KEY: ${{ secrets.API_KEY }}

      - name: Update fixtures from integration tests
        run: FIXTURE_MODE=record npm run test:integration
        if: github.ref == 'refs/heads/main'

      - name: Commit updated fixtures
        if: github.ref == 'refs/heads/main'
        run: |
          git config user.name "GitHub Actions"
          git config user.email "actions@github.com"
          git add test/fixtures/
          git commit -m "chore: update API fixtures [skip ci]" || true
          git push
```

**GitLab CI Example:**
```yaml
stages:
  - test
  - integration

unit-tests:
  stage: test
  script:
    - npm ci
    - npm test
  variables:
    FIXTURE_MODE: replay
  artifacts:
    when: on_failure
    paths:
      - test/fixtures/
    expire_in: 1 week

integration-tests:
  stage: integration
  only:
    - main
    - develop
  script:
    - npm ci
    - npm run test:integration
  variables:
    FIXTURE_MODE: passthrough
    API_KEY: ${CI_API_KEY}
  after_script:
    - FIXTURE_MODE=record npm run test:integration
    - git add test/fixtures/
    - git commit -m "chore: update fixtures [skip ci]" || true
    - git push origin HEAD:${CI_COMMIT_REF_NAME}
```

### 4.3 Development Workflows

**Workflow 1: Initial Development**
```bash
# 1. Write test with expected behavior
# 2. Record fixture from real API
FIXTURE_MODE=record npm test

# 3. Review and sanitize fixture
cat test/fixtures/my-test.json

# 4. Run test in replay mode
npm test

# 5. Commit fixture with test
git add test/ test/fixtures/
git commit -m "Add user API tests with fixtures"
```

**Workflow 2: Updating Existing Tests**
```bash
# 1. Modify test
# 2. Re-record fixture
FIXTURE_MODE=update npm test -- my-test

# 3. Verify changes
git diff test/fixtures/

# 4. Commit
git add test/ test/fixtures/
git commit -m "Update user API test and fixtures"
```

**Workflow 3: Debugging Failed Tests**
```bash
# 1. Run test in passthrough mode to see real API behavior
FIXTURE_MODE=passthrough npm test -- my-test

# 2. Compare with fixture
cat test/fixtures/my-test.json

# 3. Update fixture if API changed
FIXTURE_MODE=record npm test -- my-test

# 4. Or fix test if expectation was wrong
```

**Workflow 4: Periodic Fixture Refresh**
```bash
# Schedule weekly fixture refresh
cron: 0 0 * * 0
  script:
    - FIXTURE_MODE=record npm test
    - git add test/fixtures/
    - git commit -m "chore: refresh API fixtures"
    - git push
```

## 5. Testing Workflows

### 5.1 Snapshot Testing with Jest/Vitest

Snapshot testing captures and compares entire API responses for detecting unexpected changes.

**Basic Snapshot Test:**
```javascript
import { expect, test } from 'vitest';
import { api } from './api';

test('user list API response', async () => {
  const response = await api.getUsers();
  expect(response).toMatchSnapshot();
});

test('user creation response', async () => {
  const response = await api.createUser({ name: 'John' });

  // Exclude dynamic fields
  const { createdAt, id, ...staticFields } = response;

  expect(staticFields).toMatchSnapshot();
});
```

**Inline Snapshots:**
```javascript
test('user API structure', async () => {
  const user = await api.getUser(123);

  expect(user).toMatchInlineSnapshot(`
    {
      "id": 123,
      "name": "John Doe",
      "email": "john@example.com",
      "role": "user"
    }
  `);
});
```

**File Snapshots (Vitest):**
```javascript
test('large API response', async () => {
  const response = await api.getLargeDataset();
  await expect(response).toMatchFileSnapshot('./snapshots/large-dataset.json');
});
```

**Handling Dynamic Data:**
```javascript
test('API with timestamps', async () => {
  const response = await api.getUser(123);

  expect(response).toMatchSnapshot({
    createdAt: expect.any(String),
    updatedAt: expect.any(String),
    id: expect.any(Number)
  });
});

// Or with custom serializer
expect.addSnapshotSerializer({
  test: (val) => val && typeof val.createdAt === 'string',
  serialize: (val, config, indentation, depth, refs, printer) => {
    const sanitized = { ...val };
    sanitized.createdAt = '<TIMESTAMP>';
    sanitized.updatedAt = '<TIMESTAMP>';
    return printer(sanitized, config, indentation, depth, refs);
  }
});
```

**Updating Snapshots:**
```bash
# Update all snapshots
npm test -- -u

# Update specific test
npm test -- my-test.spec.js -u

# Interactive update (Vitest)
npm test -- --watch
# Press 'u' to update snapshots
```

### 5.2 Fixture-Based Testing with ava-fixture

Test-per-folder or test-per-file pattern for systematic testing.

**Directory Structure:**
```
test/
  fixtures/
    cases/
      user-create/
        input.json
        request.json
      user-update/
        input.json
        request.json
    baselines/
      user-create/
        response.json
      user-update/
        response.json
    results/
      (generated during tests)
```

**Test Implementation:**
```javascript
import { test } from 'ava';
import { fixture } from '@unional/fixture';

const ftest = fixture(test, {
  casesFolder: './test/fixtures/cases',
  baselinesFolder: './test/fixtures/baselines',
  resultsFolder: './test/fixtures/results'
});

ftest.each('user API operations', async (t, { caseName, casePath, resultPath, match }) => {
  // Load input
  const input = require(`${casePath}/input.json`);
  const requestData = require(`${casePath}/request.json`);

  // Make API call
  const response = await api[input.operation](requestData);

  // Save result
  await fs.writeFile(
    `${resultPath}/response.json`,
    JSON.stringify(response, null, 2)
  );

  // Match against baseline
  await match('response.json');
});
```

**NextJS AVA Fixture:**
```javascript
import { createFixture } from 'nextjs-ava-fixture';

const test = createFixture({
  nextConfig: require('./next.config.js')
});

test('API route /api/users', async (t) => {
  const { makeRequest } = t.context;

  const response = await makeRequest('/api/users', {
    method: 'GET',
    headers: { 'Authorization': 'Bearer token' }
  });

  t.is(response.status, 200);
  t.truthy(Array.isArray(response.body));
});
```

### 5.3 Diffing and Assertion Strategies

**Approval Testing Pattern:**
```javascript
import { verify } from 'approvals';

test('user API response', async () => {
  const response = await api.getUsers();

  // First run: creates approved file
  // Subsequent runs: compares against approved
  verify(JSON.stringify(response, null, 2));
});

// On failure: diff tool opens showing differences
// Approve: copy received to approved
// Reject: fix code and rerun
```

**JSON Schema Validation:**
```javascript
import Ajv from 'ajv';

const ajv = new Ajv();

const userSchema = {
  type: 'object',
  required: ['id', 'name', 'email'],
  properties: {
    id: { type: 'number' },
    name: { type: 'string' },
    email: { type: 'string', format: 'email' },
    role: { type: 'string', enum: ['user', 'admin'] }
  }
};

test('user API schema', async () => {
  const user = await api.getUser(123);
  const valid = ajv.validate(userSchema, user);

  if (!valid) {
    console.error('Schema validation errors:', ajv.errors);
  }

  expect(valid).toBe(true);
});
```

**JSONPath Assertions:**
```javascript
import jp from 'jsonpath';

test('nested API response', async () => {
  const response = await api.getComplex();

  // Extract specific values
  const usernames = jp.query(response, '$.users[*].name');
  expect(usernames).toContain('John Doe');

  // Assert on nested structure
  const adminEmails = jp.query(response, '$.users[?(@.role=="admin")].email');
  expect(adminEmails).toHaveLength(2);
});
```

**Deep Equality with Partial Matching:**
```javascript
test('API response structure', async () => {
  const response = await api.getUser(123);

  expect(response).toMatchObject({
    id: expect.any(Number),
    name: expect.any(String),
    email: expect.stringMatching(/@.+\..+/),
    profile: {
      bio: expect.any(String),
      avatar: expect.stringContaining('https://')
    }
  });
});
```

**Custom Diff Assertions:**
```javascript
import deepDiff from 'deep-diff';

test('API response changes', async () => {
  const baseline = require('./fixtures/user-baseline.json');
  const response = await api.getUser(123);

  const differences = deepDiff(baseline, response);

  // Assert specific allowed changes
  expect(differences).toEqual(
    expect.arrayContaining([
      expect.objectContaining({
        kind: 'E', // Edit
        path: ['updatedAt']
      })
    ])
  );

  // No other changes allowed
  const unexpectedChanges = differences.filter(
    d => d.path[0] !== 'updatedAt'
  );
  expect(unexpectedChanges).toHaveLength(0);
});
```

**Masking Dynamic Data:**
```javascript
function maskDynamicFields(data) {
  const masked = JSON.parse(JSON.stringify(data));

  // Mask timestamps
  if (masked.createdAt) masked.createdAt = '<TIMESTAMP>';
  if (masked.updatedAt) masked.updatedAt = '<TIMESTAMP>';

  // Mask IDs
  if (masked.id) masked.id = '<ID>';

  // Mask tokens
  if (masked.token) masked.token = '<TOKEN>';

  // Mask nested
  if (Array.isArray(masked)) {
    return masked.map(maskDynamicFields);
  }

  return masked;
}

test('API with dynamic data', async () => {
  const response = await api.getUser(123);
  const masked = maskDynamicFields(response);
  expect(masked).toMatchSnapshot();
});
```

## 6. Best Practices

### 6.1 Security and Privacy

**Sanitize Sensitive Data:**
```javascript
function sanitizeFixture(fixture) {
  const sanitized = JSON.parse(JSON.stringify(fixture));

  // Headers
  if (sanitized.reqheaders) {
    delete sanitized.reqheaders.authorization;
    delete sanitized.reqheaders.cookie;
    delete sanitized.reqheaders['x-api-key'];
  }

  if (sanitized.responseHeaders) {
    delete sanitized.responseHeaders['set-cookie'];
  }

  // Response body
  if (sanitized.response) {
    if (typeof sanitized.response === 'string') {
      sanitized.response = sanitized.response.replace(
        /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/g,
        'user@example.com'
      );
    } else if (typeof sanitized.response === 'object') {
      if (sanitized.response.token) {
        sanitized.response.token = 'REDACTED_TOKEN';
      }
      if (sanitized.response.apiKey) {
        sanitized.response.apiKey = 'REDACTED_API_KEY';
      }
      if (sanitized.response.password) {
        delete sanitized.response.password;
      }
    }
  }

  return sanitized;
}
```

**Environment-Based Sanitization:**
```javascript
const SANITIZATION_RULES = {
  production: {
    headers: ['authorization', 'cookie', 'x-api-key'],
    fields: ['password', 'token', 'apiKey', 'secret'],
    patterns: [
      { regex: /\b[\w\.-]+@[\w\.-]+\.\w+\b/g, replace: 'user@example.com' },
      { regex: /\b\d{3}-\d{2}-\d{4}\b/g, replace: 'XXX-XX-XXXX' }
    ]
  },
  development: {
    headers: ['authorization'],
    fields: ['password'],
    patterns: []
  }
};

function sanitize(fixture, env = 'production') {
  const rules = SANITIZATION_RULES[env];
  // Apply rules...
}
```

### 6.2 Fixture Organization

**Naming Conventions:**
```
fixtures/
  api-name/
    operation-name/
      success.json
      error-404.json
      error-500.json
      validation-error.json
```

**Metadata in Fixtures:**
```json
{
  "_meta": {
    "description": "User list API - successful response",
    "recordedAt": "2026-01-26T12:00:00Z",
    "recordedBy": "john@example.com",
    "apiVersion": "v1",
    "testCase": "should return list of users"
  },
  "scope": "https://api.example.com",
  "method": "GET",
  "path": "/users",
  "response": {...}
}
```

### 6.3 Maintenance

**Fixture Versioning:**
```
fixtures/
  v1/
    users/
      list.json
      get.json
  v2/
    users/
      list.json
      get.json
```

**Expiration Tracking:**
```json
{
  "_meta": {
    "recordedAt": "2026-01-26T12:00:00Z",
    "expiresAt": "2026-02-26T12:00:00Z",
    "lastVerified": "2026-01-26T12:00:00Z"
  }
}
```

**Automated Refresh:**
```javascript
async function refreshExpiredFixtures() {
  const fixtures = await loadAllFixtures();

  for (const fixture of fixtures) {
    const expiresAt = new Date(fixture._meta.expiresAt);
    if (expiresAt < new Date()) {
      console.log(`Refreshing expired fixture: ${fixture.name}`);
      await recordFixture(fixture.name, { mode: 'record' });
    }
  }
}
```

### 6.4 Performance

**Lazy Loading:**
```javascript
class FixtureCache {
  constructor() {
    this.cache = new Map();
  }

  load(name) {
    if (!this.cache.has(name)) {
      const path = `./fixtures/${name}.json`;
      const data = JSON.parse(fs.readFileSync(path, 'utf8'));
      this.cache.set(name, data);
    }
    return this.cache.get(name);
  }

  clear() {
    this.cache.clear();
  }
}
```

**Fixture Size Management:**
```javascript
// Compress large responses
function compressFixture(fixture) {
  if (fixture.response && typeof fixture.response === 'object') {
    const size = JSON.stringify(fixture.response).length;

    if (size > 100000) {
      // Store compressed or truncated version
      fixture.response = truncateLargeArrays(fixture.response, 10);
      fixture._meta.truncated = true;
    }
  }

  return fixture;
}

function truncateLargeArrays(obj, limit) {
  if (Array.isArray(obj) && obj.length > limit) {
    return obj.slice(0, limit);
  }

  if (typeof obj === 'object' && obj !== null) {
    for (const key in obj) {
      obj[key] = truncateLargeArrays(obj[key], limit);
    }
  }

  return obj;
}
```

## 7. Comparison Matrix

| Tool/Pattern | Recording | Replay | Node.js | Browser | GraphQL | Complexity | Popularity |
|-------------|-----------|---------|---------|---------|---------|------------|------------|
| Nock | Manual/Recorder | ✓ | ✓ | ✗ | ✓ | Low | Very High |
| Polly.JS | Automatic | ✓ | ✓ | ✓ | ✓ | Medium | Medium |
| MSW | Manual | ✓ | ✓ | ✓ | ✓ | Low | High |
| VCR (Ruby) | Automatic | ✓ | ✗ | ✗ | ✗ | Low | High |
| yakbak | Automatic | ✓ | ✓ | ✗ | ✗ | Low | Low |
| Mockttp | Manual | ✓ | ✓ | ✓ | ✓ | Medium | Medium |
| HAR Files | Browser/Proxy | Manual | ✓ | ✓ | ✓ | Low | High |
| WireMock | Automatic | ✓ | ✓ | ✓ | ✓ | Medium | High |
| Speedscale | Automatic | ✓ | ✓ | ✓ | ✓ | High | Medium |

## 8. Recommendations

### When to Use Each Approach

**Nock:**
- Pure Node.js testing
- Simple HTTP APIs
- Need for assertions on requests
- Quick setup required

**Polly.JS:**
- Need automatic recording
- Both client and server testing
- VCR-style workflow preferred

**MSW:**
- Testing across browser and Node.js
- GraphQL APIs
- Modern, standards-based approach
- Active development preferred

**HAR Files:**
- Browser-based testing
- Need tool compatibility
- Complex multi-step flows
- Already using Playwright/Cypress

**Traffic-Driven (Speedscale, WireMock):**
- Production traffic patterns needed
- Complex microservices
- Performance testing required
- Large-scale systems

**Snapshot Testing:**
- Detecting unexpected changes
- Large response structures
- Rapid development
- Combined with other approaches

### Storage Format Recommendations

**Use JSON when:**
- Fast parsing is critical
- Integrating with JavaScript tools
- File size is not a concern

**Use YAML when:**
- Human readability is important
- Need comments for documentation
- Config-like fixtures

**Use HAR when:**
- Need cross-tool compatibility
- Browser traffic recording
- Rich metadata required

### Integration Workflow Recommendation

1. **Development**: Record mode for new tests
2. **CI/CD**: Replay mode for fast, deterministic tests
3. **Integration Tests**: Passthrough mode periodically
4. **Scheduled**: Automatic fixture refresh weekly/monthly

## Sources

- [VCR GitHub Repository](https://github.com/vcr/vcr)
- [PHP-VCR Documentation](https://php-vcr.github.io/)
- [Getting Started with vcr (R)](https://cran.r-project.org/web/packages/vcr/vignettes/vcr.html)
- [go-vcr GitHub Repository](https://github.com/dnaeon/go-vcr)
- [Testing External APIs with VCR in Rails](https://dev.to/gathuku/testing-external-apis-with-vcr-in-rails-488m)
- [Recording and Replaying HTTP Interactions with VCR.py](https://dev.to/00geekinside00/recording-and-replaying-http-interactions-with-ease-a-guide-to-vcrpy-1c70)
- [Replay - NSHipster](https://nshipster.com/replay/)
- [Mocking API Responses with HAR Files in Playwright](https://www.neovasolutions.com/2024/08/08/mocking-api-responses-with-har-files-in-playwright-and-typescript/)
- [Mock APIs | Playwright Documentation](https://playwright.dev/docs/mock)
- [Http Archive Conventions - Microcks](https://microcks.io/documentation/references/artifacts/har-conventions/)
- [Mastering API Testing: HAR Files vs Mocking](https://jagannath.dev/mastering-api-testing-a-comparison-of-har-files-and-mocking-techniques)
- [Mock Service Worker - Comparison](https://mswjs.io/docs/comparison/)
- [npm trends: api-mock vs msw vs nock vs polly-js](https://npmtrends.com/api-mock-vs-msw-vs-nock-vs-polly-js)
- [Mocking an API in Node.js with Nock](https://noone234.medium.com/mocking-an-api-in-node-js-with-nock-0e7a44148cc4)
- [nock GitHub Repository](https://github.com/nock/nock)
- [API mock testing with Nock for Node.js apps](https://blog.logrocket.com/api-mock-testing-with-nock-node-js/)
- [What is API Mocking - BrowserStack](https://www.browserstack.com/guide/what-is-api-mocking)
- [Complete Guide to API Mocking - API7](https://api7.ai/blog/complete-guide-to-api-mocking)
- [Top 8 API Mocking Tools and Methodologies](https://speedscale.com/blog/api-mocking-tools/)
- [How Mock Servers Enhance API Testing Efficiency](https://speedscale.com/blog/using-a-mock-server-understanding-efficient-api-testing/)
- [ava-fixture Documentation](https://unional.github.io/ava-fixture/)
- [nextjs-ava-fixture GitHub](https://github.com/seamapi/nextjs-ava-fixture)
- [Verifying Entire API Responses - Angie Jones](https://angiejones.tech/verifying-entire-api-responses/)
- [api-diff GitHub Repository](https://github.com/radarlabs/api-diff)
- [3 Simple Strategies to Test a JSON API](https://assertible.com/blog/3-simple-strategies-to-test-a-json-api)
- [Web Data Serialization - Beeceptor](https://beeceptor.com/docs/concepts/data-exchange-formats/)
- [JSON vs YAML - SnapLogic](https://www.snaplogic.com/blog/json-vs-yaml-whats-the-difference-and-which-one-is-right-for-your-enterprise)
- [Introducing yakbak - Flickr Engineering](https://code.flickr.net/2016/04/25/introducing-yakbak-record-and-playback-http-interactions-in-nodejs/)
- [Build an HTTPS-intercepting JavaScript proxy](https://httptoolkit.com/blog/javascript-mitm-proxy-mockttp/)
- [Hoxy Documentation](https://greim.github.io/hoxy/)
- [http-proxy-middleware npm](https://www.npmjs.com/package/http-proxy-middleware)
- [Capture, debug and mock HTTP traffic - HTTP Toolkit](https://httptoolkit.com/javascript/)
- [Record and Playback Testing - BrowserStack](https://www.browserstack.com/guide/record-playback-testing-2)
- [GoReplay Setup for Testing](https://goreplay.org/blog/goreplay-setup-for-testing-environments/)
- [API Testing Tools Best Practices - Speedscale](https://speedscale.com/blog/api-testing-tools/)
- [The Definitive Guide to Traffic Replay](https://speedscale.com/blog/definitive-guide-to-traffic-replay/)
- [Snapshot Testing - Jest Documentation](https://jestjs.io/docs/snapshot-testing)
- [Snapshot Testing - Vitest Documentation](https://vitest.dev/guide/snapshot)
- [Master Snapshot Testing with Vitest and Jest](https://blog.seancoughlin.me/mastering-snapshot-testing-with-vite-vitest-or-jest-in-typescript)
- [Snapshot Testing APIs with Jest](https://daveceddia.com/snapshot-testing-apis-with-jest/)
