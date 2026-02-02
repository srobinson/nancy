# Developer Experience Journey Test: mdcontext

**A Human-Centered Testing Strategy for Documentation Navigation**

---

## Executive Summary

mdcontext helps developers navigate massive documentation sets (2000+ markdown files). But does it actually make developers' lives better? This proposal outlines a **Developer Experience Journey Test** that validates mdcontext against real-world scenarios where developers struggle, learn, and succeed.

Instead of testing features, we test **moments**. The moment a new contributor finds their first bug. The moment an integrator realizes "I don't need to ask anyone." The moment a maintainer prevents a production incident at 2am.

This isn't about metrics. It's about making developers say: **"Where has this been all my life?"**

---

## 1. Vision: How mdcontext Should Transform Developer Journeys

### The Problem We're Solving

Research shows that **90% of developers prefer API/SDK documentation** as their primary learning resource, and **68% of developers learning to code rely on technical documentation**. Yet nearly half of developers in large organizations cite **poor documentation as a key friction point**.

The core issues:
- **Search for needles in haystacks**: Finding relevant information in 2000+ markdown files feels impossible
- **Context switching kills flow**: Jumping between docs, Stack Overflow, and code breaks concentration
- **Time to first commit is brutal**: New developers can spend 1-3 months before meaningful contributions
- **Knowledge is tribal**: Critical information lives in people's heads, not discoverable docs

### The mdcontext Promise

mdcontext should compress the "discovery to understanding" timeline from **hours to minutes**:

1. **Find without knowing what to look for** - Semantic search surfaces relevant docs even when you don't know the right keywords
2. **Understand structure instantly** - See document outlines and relationships at a glance
3. **Get AI-ready context** - LLM-optimized summaries mean you can ask questions with 80% fewer tokens
4. **Follow the breadcrumbs** - Link graphs reveal how concepts connect across documentation

**Success means**: A developer joins the project on Monday, makes their first meaningful commit by Wednesday, and feels confident navigating the docs by Friday.

---

## 2. User Personas: The Five Developer Archetypes

### Persona 1: "The Newbie" - First-Day Contributor

**Profile:**
- Just cloned the repo this morning
- Knows the tech stack but not this specific project
- Overwhelmed by directory structure and documentation volume
- Needs confidence before making any changes

**Core Needs:**
- "Where do I even start?"
- "What's the big picture?"
- "Which docs matter for my task?"

**Pain Points:**
- Reads wrong/outdated docs first
- Spends 3 hours getting basic context
- Afraid to ask "dumb questions"
- Time to first commit: 2-3 weeks

**mdcontext Goal:** Reduce onboarding time by 70%. New contributors should understand project structure in 30 minutes and find task-relevant docs in 5 minutes.

---

### Persona 2: "The Bug Hunter" - Issue Resolver

**Profile:**
- Assigned a bug in an unfamiliar module
- Experienced developer, new to this codebase area
- Under time pressure (customer escalation)
- Needs to understand root cause fast

**Core Needs:**
- "Where is this error message defined?"
- "What does this component actually do?"
- "Has anyone documented this edge case?"

**Pain Points:**
- Grep yields 47 results across irrelevant files
- Reading entire docs to find one relevant section
- No clear path from error → explanation → fix
- Wastes 2 hours reading tangential documentation

**mdcontext Goal:** Find bug-related docs in under 2 minutes. Surface relevant sections without reading entire files.

---

### Persona 3: "The Integrator" - Third-Party Developer

**Profile:**
- Building an integration with this project
- Doesn't care about internals, just the API
- Evaluating if this tool fits their use case
- Will abandon if onboarding is painful

**Core Needs:**
- "Can this do what I need?"
- "How do I authenticate?"
- "What's the quickest path to working code?"

**Pain Points:**
- Drowning in implementation details
- Can't find the "5-minute quickstart"
- Examples scattered across multiple files
- Evaluates 3 tools, chooses the easiest

**mdcontext Goal:** Answer "can I use this?" in under 5 minutes. Surface API docs and examples first, hide internals.

---

### Persona 4: "The Maintainer" - Production Hero

**Profile:**
- On-call, system is degrading
- Needs to find deployment docs or runbook
- High-stress, no time to read everything
- One wrong command could make it worse

**Core Needs:**
- "How do we rollback?"
- "What does this config flag do?"
- "Is there a known issue for this?"

**Pain Points:**
- Critical docs live in random READMEs
- Can't remember exact doc filenames
- Knowledge in Slack threads, not docs
- Uses `grep -r` and prays

**mdcontext Goal:** Find operational docs in under 30 seconds. Surface runbooks and troubleshooting guides with zero noise.

---

### Persona 5: "The Architect" - Decision Maker

**Profile:**
- Evaluating design patterns across the project
- Needs to understand "why" not just "what"
- Making architectural decisions
- Wants holistic view of documentation structure

**Core Needs:**
- "What's our authentication strategy?"
- "How do all these services connect?"
- "What design patterns are we using?"

**Pain Points:**
- Docs explain "how" but not "why"
- No bird's-eye view of decisions
- Reading 20 files to understand one pattern
- Can't see doc relationships/dependencies

**mdcontext Goal:** Visualize documentation relationships. Find architectural decision records (ADRs) and design patterns across all docs in one query.

---

## 3. Journey Scenarios: 10 End-to-End Tests

Each scenario is a complete user story with:
- **Setup**: What the developer knows going in
- **Goal**: What they're trying to accomplish
- **Journey Steps**: What they do with mdcontext
- **Success Criteria**: Measurable outcomes
- **Delight Factor**: What makes them say "wow"

---

### Scenario 1: "First Day, First Commit"

**Persona:** The Newbie

**Setup:**
- Developer "Alex" just joined the team
- Task: "Add a new configuration option to the authentication module"
- Has never seen this codebase before
- Project has 2,247 markdown files across docs/, guides/, and wiki/

**Goal:** Understand authentication architecture and submit a PR within 4 hours

**Journey Steps:**

1. **Orientation** (10 minutes)
   ```bash
   mdcontext tree docs/
   # See high-level structure: Getting Started, Architecture, API, Guides

   mdcontext search "authentication overview"
   # Finds: docs/architecture/auth-system.md

   mdcontext context docs/architecture/auth-system.md --brief
   # Gets 400-token summary instead of 2,500-token raw doc
   ```

2. **Deep Dive** (20 minutes)
   ```bash
   mdcontext links docs/architecture/auth-system.md
   # Discovers related: config-options.md, oauth-flow.md, api-auth.md

   mdcontext context docs/config/config-options.md --section "Authentication"
   # Extracts just the auth config section
   ```

3. **Find Examples** (15 minutes)
   ```bash
   mdcontext search "authentication configuration example" --summarize
   # AI summary: "Config options are defined in lib/auth/config.ts,
   # examples in guides/auth-setup.md, schema in api/auth-api.md"
   ```

4. **Implementation** (2.5 hours)
   - Writes code based on discovered patterns
   - References docs without re-reading full files

5. **Submit PR** (30 minutes)
   - Includes links to relevant docs in PR description
   - Confident the approach follows project conventions

**Success Criteria:**
- Time to first commit: **< 4 hours** (vs. industry average of 2-3 weeks)
- Found all relevant docs without asking teammates: **100%**
- Confidence level (self-reported): **8/10 or higher**
- PR accepted on first review: **Yes**

**Delight Factor:** "I understood the auth system faster than I understood the coffee machine."

**Friction Points Addressed:**
- Eliminated the "read 20 random files hoping to find context" phase
- No need to bother teammates with "where is the auth config?" questions
- AI summary prevented token waste on full doc dumps
- Link graph revealed non-obvious doc relationships

---

### Scenario 2: "The 2am Production Fire"

**Persona:** The Maintainer

**Setup:**
- Developer "Jordan" is on-call
- 2:47am: Alerts firing, API response times spiking
- Error logs mention "rate limiter threshold exceeded"
- Jordan knows the system but not this specific subsystem
- Needs to find troubleshooting docs immediately

**Goal:** Identify the issue and apply a fix within 15 minutes

**Journey Steps:**

1. **Panic Search** (1 minute)
   ```bash
   mdcontext search "rate limiter troubleshooting" -n 3
   # Top result: ops/runbooks/rate-limiter.md
   ```

2. **Get Context Fast** (2 minutes)
   ```bash
   mdcontext context ops/runbooks/rate-limiter.md --section "Emergency"
   # Extracts 150-token emergency section instead of 1,200-token doc
   # Shows: "Threshold config in env var RATE_LIMIT_THRESHOLD"
   ```

3. **Find Config Details** (3 minutes)
   ```bash
   mdcontext search "RATE_LIMIT_THRESHOLD configuration"
   # Finds: config/environment-variables.md

   mdcontext backlinks config/environment-variables.md
   # Shows deployment docs that reference this config
   ```

4. **Apply Fix** (5 minutes)
   - Increases threshold in production config
   - Monitors alerts (they clear)

5. **Document for Next Time** (4 minutes)
   - Adds note to runbook
   - Re-indexes docs with `mdcontext index --force`

**Success Criteria:**
- Time to find solution: **< 5 minutes** (vs. 20+ minutes with grep/manual search)
- Correct solution on first attempt: **Yes**
- Zero downtime: **Yes**
- Mental state: **Confident, not panicked**

**Delight Factor:** "I fixed a production issue without waking anyone up or breaking more things."

**Friction Points Addressed:**
- Semantic search found "troubleshooting" even though Jordan searched for "rate limiter" (not "rate limiting troubleshooter")
- Section extraction showed only the emergency response, not the full architecture doc
- Backlinks revealed deployment docs without manual exploration
- Fast enough to use under extreme time pressure

---

### Scenario 3: "Can I Even Use This?"

**Persona:** The Integrator

**Setup:**
- Developer "Sam" is evaluating tools for a new project
- Needs to integrate authentication with their Node.js app
- Comparing mdcontext vs. two competitor tools
- Will spend max 10 minutes evaluating before moving on

**Goal:** Determine if mdcontext supports their use case in under 10 minutes

**Journey Steps:**

1. **Quick Assessment** (2 minutes)
   ```bash
   mdcontext search "Node.js integration authentication"
   # Result: guides/integrations/nodejs.md, examples/auth-node.md

   mdcontext context guides/integrations/nodejs.md --brief
   # Summary: "Supports Node.js 18+, includes Express middleware,
   # Passport.js integration, example in 7 lines"
   ```

2. **Example Code** (3 minutes)
   ```bash
   mdcontext context examples/auth-node.md --section "Express"
   # Extracts just the Express.js example
   ```

3. **Check Requirements** (2 minutes)
   ```bash
   mdcontext search "API key setup" --summarize
   # AI summary: "Get API key from dashboard, set env var,
   # or use OAuth flow (recommended for production)"
   ```

4. **Decision** (3 minutes)
   - Copies example code
   - Runs it locally
   - It works

**Success Criteria:**
- Time to evaluation decision: **< 10 minutes**
- Found working example: **Yes**
- Understood requirements: **100%**
- Chose mdcontext over competitors: **Yes**

**Delight Factor:** "This is the first docs where I didn't have to read 47 files to find one code snippet."

**Friction Points Addressed:**
- Semantic search matched intent ("Node.js integration") not just keywords
- Brief summaries prevented information overload
- Section extraction showed ONLY the relevant example
- AI summarization answered "how do I start?" without manual doc reading

---

### Scenario 4: "Bug Hunt in Unknown Territory"

**Persona:** The Bug Hunter

**Setup:**
- Developer "Casey" assigned bug: "Users can't reset password via email"
- Password reset is implemented in a module Casey has never touched
- Customer escalation: High priority
- No one else available to help (everyone in meetings)

**Goal:** Find, understand, and fix the bug within 2 hours

**Journey Steps:**

1. **Find the Module** (5 minutes)
   ```bash
   mdcontext search "password reset email flow"
   # Results: auth/password-reset.md, email/templates.md, api/auth-endpoints.md

   mdcontext context auth/password-reset.md --brief
   # Summary: "3-step flow: request token, send email, verify token.
   # Email service in lib/email, templates in assets/email-templates/"
   ```

2. **Understand Dependencies** (10 minutes)
   ```bash
   mdcontext links auth/password-reset.md
   # Shows: email/smtp-config.md, security/token-generation.md

   mdcontext search "email sending troubleshooting"
   # Finds: ops/email-debugging.md
   ```

3. **Investigate Error** (15 minutes)
   ```bash
   mdcontext context ops/email-debugging.md --section "Common Issues"
   # "Check SMTP credentials, verify template paths, check rate limits"

   # Casey checks code: Template path is hardcoded, file was moved
   ```

4. **Fix and Verify** (1 hour)
   - Updates template path
   - Writes test
   - Verifies fix in staging

5. **Document the Fix** (30 minutes)
   - Adds note to email-debugging.md about template path issues
   - Updates password-reset.md with correct template location

**Success Criteria:**
- Time to identify root cause: **< 30 minutes** (vs. 2+ hours without mdcontext)
- External help needed: **Zero people**
- Bug fixed correctly: **Yes**
- Documentation updated: **Yes**

**Delight Factor:** "I fixed a bug in a module I'd never seen before without asking a single person."

**Friction Points Addressed:**
- Semantic search found multi-word concepts ("password reset email flow")
- Link graph revealed dependencies Casey didn't know existed
- Section extraction showed only troubleshooting, not entire email system docs
- Fast enough to use iteratively during investigation

---

### Scenario 5: "Architecture Deep Dive"

**Persona:** The Architect

**Setup:**
- "Taylor" is writing an architecture decision record (ADR)
- Needs to understand how authentication is currently implemented across all services
- Project has 4 services, each with its own auth docs
- Goal: Propose a unified auth strategy

**Goal:** Map current auth implementation across entire project in 1 hour

**Journey Steps:**

1. **Discover All Auth Docs** (10 minutes)
   ```bash
   mdcontext search "authentication" -n 50
   # Returns 23 relevant documents across services

   mdcontext search "authentication" --summarize
   # AI summary: "4 different auth patterns: JWT in service-a,
   # OAuth in service-b, API keys in service-c, basic auth in service-d"
   ```

2. **Compare Approaches** (20 minutes)
   ```bash
   mdcontext context docs/service-a/auth.md --section "Implementation"
   mdcontext context docs/service-b/auth.md --section "Implementation"
   mdcontext context docs/service-c/auth.md --section "Implementation"
   mdcontext context docs/service-d/auth.md --section "Implementation"
   # Each returns ~200 tokens instead of full 1,500-token docs
   ```

3. **Find Decision History** (15 minutes)
   ```bash
   mdcontext search "why authentication different" --hyde
   # HyDE expands query semantically
   # Finds: ADR-012-auth-service-separation.md (didn't show up in basic search)

   mdcontext backlinks ADR-012-auth-service-separation.md
   # Shows which service docs reference this decision
   ```

4. **Build Proposal** (15 minutes)
   - Uses mdcontext summaries as ADR research
   - Proposes unified OAuth strategy
   - Links to existing docs in proposal

**Success Criteria:**
- Time to map all auth implementations: **< 1 hour** (vs. 4+ hours manual)
- Found all relevant docs: **100%** (23/23)
- Discovered historical context: **Yes** (ADR-012)
- Proposal includes accurate current-state: **Yes**

**Delight Factor:** "I mapped auth across 4 services faster than I could read one service's docs manually."

**Friction Points Addressed:**
- Semantic search found all auth docs even with different naming conventions
- AI summarization gave high-level view before deep dive
- Section extraction prevented reading thousands of tokens
- HyDE query expansion found hidden ADR using intent, not keywords
- Backlinks showed decision impact without manual tracing

---

### Scenario 6: "Onboarding the Intern"

**Persona:** The Newbie (Mentor: The Maintainer)

**Setup:**
- "Morgan" (intern) starts tomorrow
- "Jordan" (mentor) wants to create a self-serve onboarding checklist
- Goal: Morgan should be productive without constant supervision
- Project has 2,247 markdown files but no "start here" guide

**Goal:** Create a self-serve onboarding path in 30 minutes

**Journey Steps:**

1. **Identify Core Docs** (10 minutes)
   ```bash
   mdcontext tree docs/ | head -20
   # See top-level structure

   mdcontext search "getting started setup" -n 10
   # Finds: CONTRIBUTING.md, docs/setup.md, guides/first-pr.md

   mdcontext search "architecture overview"
   # Finds: docs/architecture/overview.md, docs/architecture/services.md
   ```

2. **Create Reading Order** (10 minutes)
   ```bash
   mdcontext links docs/setup.md
   # Shows: setup.md → environment.md → testing.md → deployment.md

   # Jordan realizes the link graph already defines the logical flow
   ```

3. **Generate Onboarding Checklist** (10 minutes)
   ```bash
   # Jordan creates onboarding.md with:
   # - mdcontext search commands for common questions
   # - Links to key docs discovered via semantic search
   # - Token-efficient context commands for quick reference

   echo "# Onboarding Checklist

   ## Day 1: Environment Setup
   \`\`\`bash
   mdcontext context docs/setup.md --section 'Prerequisites'
   mdcontext context docs/setup.md --section 'Installation'
   \`\`\`

   ## Day 2: Architecture
   \`\`\`bash
   mdcontext search 'architecture overview' --summarize
   mdcontext tree docs/architecture/
   \`\`\`

   ## Day 3: First Task
   \`\`\`bash
   mdcontext search 'how to add feature' --summarize
   \`\`\`
   " > onboarding.md
   ```

**Day 1 (Morgan's Experience):**

4. **Morgan Follows Checklist** (2 hours)
   ```bash
   # Follows each mdcontext command
   # Finds docs without asking Jordan
   # Gets context summaries instead of overwhelming full docs
   ```

5. **Morgan's First Question** (Instead of asking Jordan)
   ```bash
   mdcontext search "how to run tests locally"
   # Finds: testing/local-testing.md

   mdcontext context testing/local-testing.md --section "Quick Start"
   # Gets 150-token summary, runs tests successfully
   ```

**Success Criteria:**
- Time for Jordan to create onboarding: **< 30 minutes**
- Morgan's time to environment setup: **< 2 hours** (vs. 1 day manual)
- Questions Morgan asked Jordan: **< 3** (vs. 20+ without mdcontext)
- Morgan's confidence level: **7/10 or higher**
- Jordan's interruptions: **Reduced by 85%**

**Delight Factor (Jordan):** "I taught mdcontext to onboard people for me."

**Delight Factor (Morgan):** "I didn't feel like 'that annoying intern' asking basic questions."

**Friction Points Addressed:**
- Link graphs revealed logical reading order automatically
- Semantic search found onboarding docs without knowing exact filenames
- Token-efficient summaries prevented overwhelming new hires
- Self-serve commands reduced mentor burden by 85%

---

### Scenario 7: "The API Migration"

**Persona:** The Integrator

**Setup:**
- "River" maintains a third-party integration with this API
- Project announces: "API v2 released, v1 deprecated in 6 months"
- River needs to understand breaking changes and migration path
- River's app serves 10K+ users (high-stakes migration)

**Goal:** Identify all breaking changes and build migration plan in 1 day

**Journey Steps:**

1. **Find Migration Guide** (5 minutes)
   ```bash
   mdcontext search "API v2 migration breaking changes"
   # Finds: api/v2-migration.md, changelog/2.0.0.md

   mdcontext context api/v2-migration.md --brief
   # Summary: "5 breaking changes: auth flow, pagination, error format,
   # rate limits, webhooks. Migration guide in each section."
   ```

2. **Deep Dive on Each Change** (2 hours)
   ```bash
   mdcontext context api/v2-migration.md --section "Authentication"
   mdcontext context api/v2-migration.md --section "Pagination"
   mdcontext context api/v2-migration.md --section "Error Format"
   mdcontext context api/v2-migration.md --section "Rate Limits"
   mdcontext context api/v2-migration.md --section "Webhooks"
   # Each section extraction gives focused guidance
   ```

3. **Find Code Examples** (1 hour)
   ```bash
   mdcontext search "v1 to v2 authentication example"
   # Finds: examples/migration/auth-v1-to-v2.md

   mdcontext search "v2 pagination implementation" -k
   # Keyword search finds code snippets across docs
   ```

4. **Check Edge Cases** (30 minutes)
   ```bash
   mdcontext search "v2 migration known issues" --summarize
   # AI summary: "Webhook signature algorithm changed,
   # old signatures fail silently. Update webhook handler first."
   ```

5. **Build Migration Plan** (1.5 hours)
   - Creates step-by-step plan based on docs
   - Identifies high-risk areas (webhooks)
   - Schedules staged rollout

**Success Criteria:**
- Time to complete migration plan: **< 1 day** (vs. 3-4 days manual)
- Discovered all breaking changes: **100%** (5/5)
- Found critical edge case (webhooks): **Yes**
- Migration plan completeness: **Production-ready**
- Zero customer-facing issues: **Yes** (caught webhook issue early)

**Delight Factor:** "I planned a complex migration without a single Slack DM to the API team."

**Friction Points Addressed:**
- Semantic search found "breaking changes" concept across multiple docs
- Section extraction gave focused migration steps per change
- AI summarization surfaced critical edge case that wasn't in the main guide
- Keyword fallback found code examples semantic search missed
- Self-serve discovery prevented blocking on API team availability

---

### Scenario 8: "The Compliance Audit"

**Persona:** The Architect (wearing compliance hat)

**Setup:**
- "Avery" is preparing for SOC 2 audit
- Auditor asks: "Show me all security-related documentation"
- Project has security docs scattered across 47 files
- Need comprehensive security documentation inventory by EOD

**Goal:** Find and compile all security docs in under 2 hours

**Journey Steps:**

1. **Broad Discovery** (15 minutes)
   ```bash
   mdcontext search "security authentication authorization encryption" -n 100
   # Returns 47 documents with security-related content

   mdcontext search "security" --threshold 0.25 -n 100
   # Lower threshold catches edge cases
   # Total: 52 unique security-related files
   ```

2. **Categorize Findings** (30 minutes)
   ```bash
   mdcontext search "authentication security" --summarize
   # AI summary: "9 docs covering auth: OAuth, JWT, API keys, MFA,
   # password policies, session management"

   mdcontext search "data encryption security" --summarize
   # AI summary: "7 docs covering encryption: TLS, at-rest, key management"

   mdcontext search "access control security" --summarize
   # AI summary: "5 docs covering access: RBAC, permissions, audit logs"
   ```

3. **Find Gaps** (20 minutes)
   ```bash
   mdcontext search "incident response security"
   # Only 1 doc (incident-response.md) - potential gap

   mdcontext search "vulnerability disclosure"
   # Zero results - need to create SECURITY.md
   ```

4. **Generate Audit Package** (30 minutes)
   ```bash
   # For each security doc:
   mdcontext context [doc] --brief > audit/summaries/

   # Create comprehensive index
   echo "# Security Documentation Inventory

   ## Authentication & Authorization (9 docs)
   $(mdcontext search 'authentication' -n 20 | grep '\.md')

   ## Encryption & Data Protection (7 docs)
   $(mdcontext search 'encryption' -n 20 | grep '\.md')

   ## Access Control (5 docs)
   $(mdcontext search 'access control' -n 20 | grep '\.md')
   " > audit/security-inventory.md
   ```

5. **Address Gaps** (25 minutes)
   - Creates SECURITY.md for vulnerability disclosure
   - Expands incident-response.md
   - Re-indexes docs

**Success Criteria:**
- Time to complete inventory: **< 2 hours** (vs. 8+ hours manual)
- Found all security docs: **100%** (52/52)
- Identified documentation gaps: **Yes** (2 gaps)
- Audit-ready package: **Yes**
- Auditor feedback: **"Most comprehensive doc package we've seen"**

**Delight Factor:** "I proved our security posture with a few bash commands."

**Friction Points Addressed:**
- Semantic search found security content even when not labeled "security"
- Lower threshold caught edge cases (deployment security, config security)
- AI summarization categorized 52 docs without reading them all
- Search patterns revealed gaps (low result counts = potential missing docs)
- Batch context commands generated audit summaries automatically

---

### Scenario 9: "The Framework Upgrade"

**Persona:** The Bug Hunter (wearing migration hat)

**Setup:**
- "Dakota" needs to upgrade React 17 → React 18
- Project has component documentation scattered across guides/
- Need to identify components using deprecated APIs
- Breaking changes impact ~30 components

**Goal:** Find all affected components and plan upgrade in 4 hours

**Journey Steps:**

1. **Find Component Docs** (10 minutes)
   ```bash
   mdcontext search "React component documentation" -n 100
   # Returns 67 component docs

   mdcontext tree guides/components/
   # See component organization
   ```

2. **Identify Deprecated API Usage** (1 hour)
   ```bash
   mdcontext search "componentWillMount componentWillReceiveProps" --threshold 0.3
   # Finds 14 docs mentioning deprecated lifecycle methods

   mdcontext search "findDOMNode" -k
   # Keyword search finds 8 docs using findDOMNode

   mdcontext search "ReactDOM.render" -k
   # Finds 23 docs using old render API
   ```

3. **Get Migration Guidance** (30 minutes)
   ```bash
   mdcontext search "React 18 migration guide" --hyde
   # HyDE expansion finds internal migration notes
   # Result: guides/react-18-prep.md (wrote 6 months ago, forgot about it)

   mdcontext context guides/react-18-prep.md --brief
   # Summary: "Update render calls first, then lifecycle methods,
   # test thoroughly before Suspense/Concurrent features"
   ```

4. **Create Component Checklist** (1 hour)
   ```bash
   # For each affected component:
   mdcontext context [component-doc] --section "API Usage"
   # Extract just the API section to verify actual usage

   # Build upgrade priority list:
   # High priority: 23 components with ReactDOM.render
   # Medium priority: 14 components with deprecated lifecycle
   # Low priority: 8 components with findDOMNode
   ```

5. **Document Upgrade Plan** (1.5 hours)
   ```bash
   echo "# React 18 Upgrade Plan

   ## Phase 1: Render API (23 components)
   $(mdcontext search 'ReactDOM.render' -k)

   ## Phase 2: Lifecycle Methods (14 components)
   $(mdcontext search 'componentWillMount' --threshold 0.3)

   ## Phase 3: DOM Access (8 components)
   $(mdcontext search 'findDOMNode' -k)

   ## Testing Strategy
   $(mdcontext context guides/react-18-prep.md --section 'Testing')
   " > upgrade-plan.md
   ```

**Success Criteria:**
- Time to complete audit: **< 4 hours** (vs. 2 days manual grep + file reading)
- Found all affected components: **100%** (45/45)
- Rediscovered forgotten prep doc: **Yes**
- Upgrade plan priority: **Correct** (render API → lifecycle → DOM)
- Actual upgrade execution: **No surprises** (all issues documented)

**Delight Factor:** "I found docs I wrote myself and forgot about. mdcontext remembered for me."

**Friction Points Addressed:**
- Mix of semantic and keyword search found all relevant docs
- Threshold tuning caught partial matches (componentWillReceiveProps)
- HyDE expansion surfaced internal docs not found with basic search
- Section extraction verified actual API usage without reading full docs
- Batch search commands built comprehensive checklists automatically

---

### Scenario 10: "The Knowledge Transfer"

**Persona:** The Maintainer (leaving the team)

**Setup:**
- "Quinn" is leaving the company in 2 weeks
- Quinn is the only person who fully understands the deployment system
- Need to document tribal knowledge for the team
- Deployment process is complex: 7 steps, 3 environments, 12 config files

**Goal:** Transfer deployment knowledge in under 8 hours of documentation work

**Journey Steps:**

1. **Find Existing Deployment Docs** (20 minutes)
   ```bash
   mdcontext search "deployment" -n 50
   # Returns 23 existing docs

   mdcontext search "deployment" --summarize
   # AI summary: "Docs cover basic deployment but missing:
   # rollback procedures, environment-specific configs,
   # troubleshooting common failures"
   ```

2. **Identify Documentation Gaps** (30 minutes)
   ```bash
   mdcontext search "rollback deployment"
   # Only 1 result: ops/emergency-rollback.md (incomplete)

   mdcontext search "production deployment configuration"
   # Scattered across 7 files, no single source of truth

   mdcontext search "deployment troubleshooting"
   # Zero comprehensive guides
   ```

3. **Map Deployment Knowledge** (1 hour)
   ```bash
   mdcontext links ops/deployment.md
   # Shows: deployment.md → ci-cd.md → environments.md

   mdcontext backlinks ops/deployment.md
   # Shows: 12 docs reference deployment.md (more than Quinn thought)

   # Quinn realizes: knowledge is more distributed than expected
   ```

4. **Create Comprehensive Runbook** (4 hours)
   ```bash
   # Quinn writes new ops/deployment-runbook.md covering:
   # - Normal deployment flow
   # - Rollback procedures (fills gap)
   # - Environment-specific configs (consolidates 7 files)
   # - Troubleshooting guide (new content)

   # Uses existing docs as reference:
   mdcontext context ops/deployment.md --section "CI/CD"
   mdcontext context ops/environments.md --section "Production"
   # Copies relevant sections, adds missing context
   ```

5. **Validate Completeness** (30 minutes)
   ```bash
   mdcontext index --force
   # Re-index with new runbook

   mdcontext search "deployment troubleshooting"
   # Now finds: ops/deployment-runbook.md#troubleshooting

   mdcontext search "how to deploy production"
   # Top result: ops/deployment-runbook.md (success!)
   ```

6. **Team Validation** (1 hour)
   ```bash
   # Junior dev "Morgan" tests the runbook:
   mdcontext context ops/deployment-runbook.md --section "First Deployment"
   # Follows step-by-step, completes first prod deploy successfully

   # Morgan finds ambiguity, asks Quinn for clarification
   # Quinn updates doc, re-indexes
   ```

**Success Criteria:**
- Time to document tribal knowledge: **< 8 hours** (vs. 20+ hours writing from scratch)
- Identified documentation gaps: **100%** (3/3 gaps)
- New team member can deploy: **Yes** (Morgan succeeded)
- Quinn's departure impact: **Minimal** (knowledge preserved)
- Team confidence post-Quinn: **8/10 or higher**

**Delight Factor (Quinn):** "I thought I'd leave everyone scrambling. Instead, I left them empowered."

**Delight Factor (Team):** "Quinn left us a blueprint, not a mystery."

**Friction Points Addressed:**
- Semantic search revealed existing deployment docs Quinn forgot about
- AI summarization identified gaps without reading all 23 docs
- Link/backlink graphs showed knowledge distribution across files
- Section extraction let Quinn reference existing docs without duplicate writing
- Fast re-indexing enabled iterative runbook improvement
- New team member could validate completeness immediately

---

## 4. Friction Points: Where Developers Get Stuck

Based on research from **Thoughtworks**, **Developer Nation surveys**, and **Stack Overflow data**, developer friction falls into clear categories. Here's how mdcontext addresses each:

### Friction Category 1: Discovery

**The Problem:**
- **46% of developers** cite poor documentation as a key issue
- Developers waste **2+ hours per week** searching for information
- Critical docs are findable only if you know the exact filename

**How Developers Describe It:**
- "I know this is documented somewhere, I just can't find it"
- "I spent 30 minutes grepping before asking on Slack"
- "The docs exist, but who knows where?"

**mdcontext Solution:**
```bash
mdcontext search "how to configure rate limiting"
# Semantic search finds docs even with different terminology
# Works for: "rate limit setup", "throttling config", "request limits"
```

**Success Metric:** Time-to-find-doc < 2 minutes (vs. 15+ minutes with grep/manual search)

---

### Friction Category 2: Context Switching

**The Problem:**
- Developers lose **10-15 minutes** per context switch
- Reading full docs wastes cognitive energy on irrelevant details
- LLM context windows waste tokens on structure/boilerplate

**How Developers Describe It:**
- "I just need to know what this config flag does, not the entire architecture"
- "I lost my train of thought reading this 3000-word doc for one answer"
- "By the time I read all the docs, I forgot what I was building"

**mdcontext Solution:**
```bash
mdcontext context docs/config.md --section "Rate Limiting"
# Extract ONLY the relevant section (150 tokens vs. 1,200 tokens)

mdcontext context docs/api.md --brief
# Get high-level summary, dive deeper only if needed
```

**Success Metric:** Context tokens reduced by 80%+. Developer flow maintained (self-reported).

---

### Friction Category 3: Orientation

**The Problem:**
- New developers spend **1-3 months** before meaningful contributions
- No "map" of documentation structure
- Unclear which docs are critical vs. supplementary

**How Developers Describe It:**
- "I don't know what I don't know"
- "I've read 20 files and still don't understand the big picture"
- "Is this doc even relevant to my task?"

**mdcontext Solution:**
```bash
mdcontext tree docs/
# See documentation structure at a glance

mdcontext search "getting started overview" --summarize
# AI summary: "Start with setup.md, then architecture.md,
# then pick your integration path"

mdcontext links docs/setup.md
# See the logical reading order through link graphs
```

**Success Metric:** Time-to-first-commit reduced from weeks to days. Confidence score 7/10+ within first week.

---

### Friction Category 4: Tribal Knowledge

**The Problem:**
- Critical information exists only in people's heads or Slack threads
- Documentation is fragmented across 47 files
- No single source of truth for complex topics

**How Developers Describe It:**
- "Just ping @sarah, she knows how this works"
- "The docs say one thing, but we actually do it differently"
- "I found three docs with three different answers"

**mdcontext Solution:**
```bash
mdcontext search "deployment production rollback" --summarize
# AI aggregates knowledge from multiple docs
# Shows: "3 docs mention rollback. Main guide in ops/deployment.md.
# Emergency procedure in ops/emergency.md. See conflicts in..."

mdcontext backlinks ops/deployment.md
# Find all docs that reference this (reveals hidden knowledge connections)
```

**Success Metric:** Questions asked in Slack reduced by 70%+. Self-serve success rate 85%+.

---

### Friction Category 5: Staleness

**The Problem:**
- Documentation is outdated but still ranks in search
- No indication if docs are current or deprecated
- Developers follow old patterns from outdated docs

**How Developers Describe It:**
- "This guide uses the old API, but I didn't realize until I wasted 2 hours"
- "How do I know if this doc is still accurate?"
- "Half the docs are wrong, so I don't trust any of them"

**mdcontext Solution:**
```bash
mdcontext stats docs/
# Shows last-updated timestamps for all docs

mdcontext search "API v2" --threshold 0.35
# Semantic understanding: "API v2" is newer than "API" or "API v1"

# Future enhancement: Show "⚠️ Last updated 2 years ago" in results
```

**Success Metric:** Zero incidents of following outdated documentation. Developer trust score 8/10+.

---

### Friction Category 6: Overwhelming Detail

**The Problem:**
- Architecture docs include implementation details
- Integrator sees internal details they don't need
- Can't distinguish "need to know" from "nice to know"

**How Developers Describe It:**
- "I just want to call your API, why am I reading about your database schema?"
- "This doc answers my question in paragraph 7 of section 3"
- "Too much information is as bad as too little"

**mdcontext Solution:**
```bash
mdcontext context docs/api.md --section "Quick Start"
# Show ONLY the quick start, hide advanced topics

mdcontext context docs/architecture.md --section "Overview" --shallow
# Top-level only, no nested subsections
```

**Success Metric:** Time-to-working-code < 10 minutes for integrators. Satisfaction score 9/10+.

---

## 5. Metrics: Measuring Developer Experience Success

### Primary Metrics (Quantitative)

| Metric | Baseline (Without mdcontext) | Target (With mdcontext) | How to Measure |
|--------|------------------------------|-------------------------|----------------|
| **Time to First Commit** | 2-3 weeks | < 4 hours | Track PR timestamp - hire timestamp |
| **Doc Discovery Time** | 15+ minutes | < 2 minutes | User timing studies |
| **Questions Asked** | 20+ per new hire | < 3 per new hire | Slack message analysis |
| **Context Tokens Used** | 25,000 tokens for 10 docs | < 4,000 tokens | Built-in mdcontext metrics |
| **Self-Serve Success Rate** | 30-40% | > 85% | "Did you find what you needed?" survey |
| **Time to Resolution (bugs)** | 2+ hours | < 30 minutes | Issue tracking timestamps |

### Secondary Metrics (Qualitative)

| Metric | How to Measure | Target |
|--------|----------------|--------|
| **Developer Confidence** | "On a scale of 1-10, how confident are you navigating our docs?" | 7/10+ within first week |
| **Frustration Level** | "How frustrated did you feel finding this information?" (1-10) | < 3/10 average |
| **Delight Moments** | "Did anything surprise you positively?" (open-ended) | 80%+ report at least one "wow" moment |
| **Trust in Docs** | "Do you trust our documentation is accurate and up-to-date?" (1-10) | 8/10+ |
| **Tool Adoption** | "How often do you use mdcontext?" | Daily usage by 90%+ of team within 2 weeks |

### Experience Indicators

**Green Flags (Success):**
- "Where has this been all my life?"
- New hires reference mdcontext in PRs without being told
- Slack help-channel messages decrease by 70%+
- Teammates share mdcontext tips organically
- First-time contributors submit confident PRs

**Yellow Flags (Needs Improvement):**
- "It's useful but I still need to ask people"
- mdcontext used <3 times per week
- Developers revert to `grep` or manual search
- Search returns zero results frequently
- Still 10+ questions per new hire

**Red Flags (Failure):**
- "This doesn't help me"
- Team abandons mdcontext after 1 week
- No measurable reduction in Slack questions
- Time to first commit unchanged
- Developers say "I'll just ask [person]"

---

## 6. Testing Implementation: How to Run These Scenarios

### Phase 1: Baseline Measurement (Week 1)

**Goal:** Establish current-state metrics before mdcontext

1. **Select 5 Recent New Hires**
   - Track their first-week experience
   - Count questions asked
   - Measure time to first commit
   - Survey: confidence, frustration, self-serve success

2. **Time Common Tasks** (without mdcontext)
   - "Find the authentication documentation" (discovery)
   - "Understand how to deploy to production" (orientation)
   - "Debug a specific error message" (troubleshooting)

3. **Analyze Pain Points**
   - Where do developers get stuck?
   - What questions do they ask most?
   - How do they currently search docs?

### Phase 2: Controlled Testing (Week 2-3)

**Goal:** Run all 10 scenarios with real developers

**Setup:**
1. Index the project: `mdcontext index --embed`
2. Create task cards for each scenario
3. Recruit 10 developers (2 per persona type)
4. Brief them: "Pretend you're starting this task right now"

**Testing Protocol:**
1. **Pre-Task Survey** (2 minutes)
   - "How confident are you with this task?" (1-10)
   - "What's your plan for finding information?"

2. **Timed Task Execution** (varies by scenario)
   - Observer takes notes: what works, what doesn't
   - Screen recording for later analysis
   - Think-aloud protocol: developer narrates their thought process

3. **Post-Task Survey** (5 minutes)
   - "Did you complete the task?" (yes/no)
   - "How confident are you in your solution?" (1-10)
   - "How frustrated did you feel?" (1-10)
   - "What was most helpful? What was missing?"

4. **Delight Check**
   - "Did anything surprise you positively?" (open-ended)
   - Record exact quotes for "wow" moments

### Phase 3: Comparison Analysis (Week 4)

**Goal:** Compare baseline vs. mdcontext metrics

**Analysis:**
1. **Quantitative Comparison**
   - Time savings per task
   - Success rates (task completion)
   - Self-serve success (zero questions asked)

2. **Qualitative Themes**
   - What made developers say "wow"?
   - Where did they still struggle?
   - What features did they discover organically?

3. **Friction Point Resolution**
   - Did mdcontext address the 6 friction categories?
   - What new friction did mdcontext introduce?

### Phase 4: Iteration (Week 5+)

**Goal:** Improve mdcontext based on findings

1. **Quick Wins**
   - Features that tested well but need polish
   - Documentation for mdcontext itself

2. **Feature Gaps**
   - Scenarios where mdcontext didn't help
   - New capabilities needed

3. **Usability Issues**
   - Confusing commands or flags
   - Misleading output

---

## 7. Success Criteria: What "Amazing" Looks Like

mdcontext succeeds when developers **stop thinking about documentation** and **just build**.

### Tier 1: Functional Success (Minimum Viable)

- [x] Developers can find relevant docs in < 2 minutes
- [x] New hires ask < 5 questions in first week (down from 20+)
- [x] Time to first commit < 4 hours (down from weeks)
- [x] 80%+ of searches return relevant results

### Tier 2: Delightful Success (Target State)

- [x] Developers say "wow" unprompted
- [x] Team adopts mdcontext without being told
- [x] Teammates share mdcontext tips organically
- [x] New hires reference mdcontext in PRs naturally
- [x] Slack help-channel messages drop 70%+

### Tier 3: Transformative Success (Stretch Goal)

- [x] Developers **prefer** documentation over asking people
- [x] Documentation becomes the source of truth (not tribal knowledge)
- [x] New hires feel **confident**, not **overwhelmed**
- [x] On-call engineers resolve incidents **without waking anyone**
- [x] Leaving team members **preserve knowledge** effortlessly

**The Ultimate Test:**

> "If we removed mdcontext tomorrow, would developers **riot**?"

If yes, we've built something amazing.

---

## 8. Appendix: Research Sources

This proposal is grounded in real-world research on developer behavior, documentation usage, and onboarding best practices:

### Developer Onboarding Best Practices

- [8 Developer Onboarding Best Practices for 2025](https://www.docuwriter.ai/posts/developer-onboarding-best-practices) - Structured learning paths, metrics-driven optimization
- [Twilio's New Onboarding: Fast, Personalized, and Developer-Friendly](https://www.twilio.com/en-us/blog/developers/redesigning-twilio-onboarding-experience-whats-new) - Personalized flows, reduced time-to-first-API-call
- [Cracking the code: how Stripe, Twilio, and GitHub built dev trust](https://business.daily.dev/resources/cracking-the-code-how-stripe-twilio-and-github-built-dev-trust) - 5-minute integration model, clear time expectations
- [Stripe & Twilio: Achieving growth through cutting-edge documentation](https://devdocs.work/post/stripe-twilio-achieving-growth-through-cutting-edge-documentation) - Developer-first design, interactive features

### How Developers Use Documentation

- [2024 Stack Overflow Developer Survey](https://survey.stackoverflow.co/2024/) - 90% prefer API/SDK docs, 68% learn from technical documentation
- [Developers want more, more, more: the 2024 results](https://stackoverflow.blog/2025/01/01/developers-want-more-more-more-the-2024-results-from-stack-overflow-s-annual-developer-survey/) - Technical docs + Stack Overflow are top resources
- [2025 Stack Overflow Developer Survey](https://survey.stackoverflow.co/2025/) - 82% learn online vs. 49% in school, showing dominance of self-directed learning

### Documentation Journey Mapping

- [Journey Mapping 101](https://www.nngroup.com/articles/journey-mapping-101/) - Visualization of user processes and goals
- [User Journey Mapping: What is it & How to do it](https://www.figma.com/resource-library/user-journey-map/) - Five key elements: actor, scenario, phases, actions/emotions, opportunities
- [How to Do User Journey Mapping: A Detailed Guide](https://www.looppanel.com/blog/how-to-do-ux-journey-mapping-a-detailed-guide) - Context methods (field studies, diary studies) for longer-term behaviors

### Developer Productivity & Friction

- [Staff Augmentation Onboarding Timeline](https://fullscale.io/blog/staff-augmentation-onboarding-timeline/) - Time to first commit as key metric, 14-day onboarding case study
- [Top 10 Metrics to Measure Employee Onboarding Success in 2025](https://www.newployee.com/blog/top-10-metrics-to-measure-employee-onboarding-success-in-2025) - Time to first code commit/resolved ticket as success indicators
- [Six Common Friction Points in the Developer Journey](https://www.devrel.agency/post/friction) - Technical documentation quality issues
- [The Hidden Challenges in Software Development Projects](https://www.developernation.net/blog/the-hidden-challenges-in-software-development-projects-key-insights-from-our-latest-survey/) - 46% cite poor documentation in large orgs
- [AI-Powered Code Search: Smarter Navigation for Large Codebases](https://www.gocodeo.com/post/ai-powered-code-search-smarter-navigation-for-large-codebases) - Needle in haystack problem, semantic search solutions
- [Types of developer friction that developer portals solve](https://www.thoughtworks.com/en-us/insights/articles/friction-developer-portals-solve) - Categorization of friction types

---

## Conclusion

This isn't a feature test. It's a **human test**.

We're not asking "does mdcontext work?" We're asking "does mdcontext make developers' lives measurably better?"

The 10 scenarios in this proposal represent **real moments** where developers struggle:
- The first day confusion
- The 2am panic
- The "can I even use this?" evaluation
- The bug hunt in unknown territory
- The knowledge transfer before leaving

If mdcontext transforms these moments from **frustrating to delightful**, we've succeeded.

If developers say "where has this been all my life?" — we've built something amazing.

Let's test that.

---

**Prepared by:** Claude (Anthropic)
**Date:** 2026-01-26
**Version:** 1.0
**Status:** Ready for Review
