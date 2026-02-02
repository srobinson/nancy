# Nancy Prompt Factory - Mental Model

**A clear guide for knowing what goes where and why.**

---

## The Core Question

> **"Could a non-developer edit this in a form UI?"**

- **YES** → It's data → Put it in a **Bead** (YAML)
- **NO** → It's instructions → Put it in a **Fragment** (Markdown)

---

## The Three Layers

```
┌─────────────────────────────────────────────┐
│  1. BEADS (Data)                            │
│  Facts about users, projects, preferences   │
│  ~/.nancy/beads/*.yaml                      │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│  2. FRAGMENTS (Instructions)                │
│  Reusable prompt templates                  │
│  fragments/{domain}.{category}.{name}.md    │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│  3. ASSEMBLERS (Rules)                      │
│  How to combine beads + fragments           │
│  assemblers/*.yaml                          │
└─────────────────────────────────────────────┘
```

---

## Layer 1: Beads (The WHAT)

**Purpose**: Structured data that varies per user/project

### What belongs in beads?

- ✅ User's name, role, experience level
- ✅ Project description, tech stack
- ✅ Code style preferences (camelCase vs snake_case)
- ✅ Preferred testing framework
- ✅ Active Linear issues
- ✅ Team size, members
- ✅ Timezone, working hours

### What does NOT belong in beads?

- ❌ "You are working with {{user.name}}" (that's a fragment)
- ❌ "Use strict TypeScript mode" (that's a fragment)
- ❌ "Follow these principles..." (that's a fragment)
- ❌ Assembly logic (that's an assembler)

### Example Bead

```yaml
# ~/.nancy/beads/user.yaml
nancy_version: "1.0"
identity:
  name: Stuart
  role: Senior Developer
  communication_style: direct, technical
```

**Think of it as**: A database record, a config file, a form submission

---

## Layer 2: Fragments (The HOW)

**Purpose**: Reusable prompt instructions that reference bead data

### What belongs in fragments?

- ✅ "You are working with {{user.identity.name}}, a {{user.identity.role}}"
- ✅ "Use strict TypeScript mode with explicit types"
- ✅ "Follow these core principles..."
- ✅ Conditional logic: "If POC mode, then..."
- ✅ Instructions to the LLM

### What does NOT belong in fragments?

- ❌ Actual user names (that's in beads)
- ❌ Actual project descriptions (that's in beads)
- ❌ Which fragments to include when (that's in assemblers)

### Example Fragment

```markdown
---
id: user.identity
priority: 10
---

You are working with **{{user.identity.name}}**, {{user.identity.role}}.

{{user.identity.summary}}

Communication style: {{user.identity.communication_style}}
```

**Think of it as**: A template, a component, a reusable instruction block

### How Fragments Appear in Assembled Prompts

When fragments are assembled into a final prompt, they include **provenance metadata** for traceability:

```markdown
---
provenance:
  fragments:
    - id: user.identity
      file: templates/fragments/user.identity.md
      version: 1.0.0
      priority: 10
      hash: d5e6f7a8b9c0d1e2
---

<!-- BEGIN: user.identity | priority: 10 | templates/fragments/user.identity.md -->

You are working with **Stuart**, Senior Developer.
...

<!-- END: user.identity -->
```

The inline markers (`<!-- BEGIN -->` and `<!-- END -->`) make it easy to:

- Trace a prompt section back to its source fragment
- Know which file to edit when you need to change something
- Debug issues by seeing exactly which fragments were included

---

## Domain Organization

Nancy uses a **flat directory structure** with domain-prefixed naming to organize fragments across different fields and use cases.

### What are domains?

Domains represent different areas of work where Nancy can assist:

- **eng**: Engineering (languages, frameworks, tools)
- **marketing**: Marketing content, campaigns, copy
- **legal**: Legal documents, contracts, compliance
- **creative**: Design, writing, content creation
- **workflows**: Cross-domain processes (Linear, Git)
- **meta**: Core Nancy behavior and principles

### Naming Convention

All fragments follow this pattern:

```
{domain}.{category}.{name}.md
```

Examples:

- `eng.lang.typescript.md` - TypeScript language guidelines
- `eng.framework.react.md` - React framework patterns
- `marketing.copy.email.md` - Email copywriting guidelines
- `legal.contract.nda.md` - NDA contract templates
- `creative.writing.blogpost.md` - Blog post writing style
- `workflows.linear.md` - Linear workflow integration

### Why Flat Structure?

The flat structure makes it **easier for humans to discover** what's available:

1. **One directory to browse**: All fragments in `fragments/` instead of nested folders
2. **Scannable names**: Domain prefix tells you what it's for at a glance
3. **No navigation**: No need to drill through `fragments/languages/`, `fragments/frameworks/`, etc.
4. **Easy alphabetical sorting**: Related fragments group together naturally
5. **Simple to add**: Just create `domain.category.name.md` - no folder structure to create

### Domain-Agnostic Design

Nancy isn't just for engineers. The same system works for:

**Marketing Team**:

```
fragments/marketing.copy.social.md
fragments/marketing.campaign.launch.md
fragments/marketing.analytics.reporting.md
```

**Legal Team**:

```
fragments/legal.contract.saas.md
fragments/legal.privacy.gdpr.md
fragments/legal.compliance.sox.md
```

**Creative Team**:

```
fragments/creative.design.brandguide.md
fragments/creative.writing.pressrelease.md
fragments/creative.video.script.md
```

Each domain can have its own beads, fragments, and assemblers - all using the same Nancy infrastructure.

---

## Layer 3: Assemblers (The RULES)

**Purpose**: Define which fragments to include and how to compose them

### What belongs in assemblers?

- ✅ "Always include meta/principles"
- ✅ "If TypeScript detected, include languages/typescript"
- ✅ "If user bead exists, include user/identity"
- ✅ Priority/ordering rules
- ✅ Detection logic (what language, framework, etc.)

### Example Assembler

```yaml
fragments:
  always:
    - meta/principles

  conditional:
    - if: detected.language == "typescript"
      include: languages/typescript
```

**Think of it as**: A recipe, assembly instructions, a rule engine

---

## Decision Tree

When you have some information, ask:

### 1. Is it a FACT or an INSTRUCTION?

```
Is it a fact about the world?
├─ YES → Bead
└─ NO → Fragment or Assembler
```

Examples:

- "Stuart is a senior developer" → **Fact** → Bead
- "You are working with Stuart" → **Instruction** → Fragment

### 2. Does it CHANGE per user/project or STAY THE SAME?

```
Does this change per user/project?
├─ YES → Bead
└─ NO → Fragment (ships with Nancy)
```

Examples:

- "My preferred indent is 2 spaces" → **Changes** → Bead (styles/typescript.yaml)
- "Use TypeScript's type system effectively" → **Same for everyone** → Fragment

### 3. Is it DATA or LOGIC?

```
Is it queryable data or control flow?
├─ Data → Bead
└─ Logic → Fragment or Assembler
```

Examples:

- `mode: "production"` → **Data** → Bead
- `{{#if mode == "production"}}...{{/if}}` → **Logic** → Fragment
- `if: detected.language == "typescript"` → **Logic** → Assembler

---

## Common Scenarios

### Scenario: User prefers camelCase for variables

**Where?** → `~/.nancy/beads/styles/typescript.yaml`

```yaml
naming:
  variables: camelCase
```

**Why bead?** It's a fact about the user's preference, would work in a form UI.

---

### Scenario: Instructions for using Linear

**Where?** → `fragments/workflows.linear.md`

```markdown
# Linear Integration Workflow

Use Linear MCP tools to manage work:

- `mcp__linear-server__list_issues`
- ...
```

**Why fragment?** It's instructions, same for everyone, teaches the LLM what to do.

---

### Scenario: "Include TypeScript fragment when .ts files detected"

**Where?** → `assemblers/task-init.yaml`

```yaml
conditional:
  - if: detected.language == "typescript"
    include: eng.lang.typescript
```

**Why assembler?** It's composition logic, defines when to include what.

---

### Scenario: Stuart's summary about himself

**Where?** → `~/.nancy/beads/user.yaml`

```yaml
identity:
  summary: "35 year old senior developer..."
```

**Why bead?** It's data about Stuart, specific to him, would go in a form field.

---

### Scenario: Template using Stuart's summary

**Where?** → `fragments/meta.user.identity.md`

```markdown
You are working with **{{user.identity.name}}**.

{{user.identity.summary}}
```

**Why fragment?** It's the template that USES the data, provides structure.

---

## The "Form UI Test" in Detail

Imagine building a form UI for Nancy onboarding:

```
┌─────────────────────────────────────────┐
│ Nancy Onboarding                        │
├─────────────────────────────────────────┤
│                                         │
│ What's your name?                       │
│ [_________________________________]     │ ← Bead
│                                         │
│ What's your role?                       │
│ [_________________________________]     │ ← Bead
│                                         │
│ Communication style?                    │
│ [_________________________________]     │ ← Bead
│                                         │
│ Preferred variable naming?              │
│ ○ camelCase  ○ snake_case              │ ← Bead
│                                         │
│         [Save Preferences]              │
└─────────────────────────────────────────┘
```

Everything in that form → **Bead**

Everything NOT in that form (like "You are working with...") → **Fragment**

---

## Extension Patterns

### Adding a New Language

**1. Create Fragment** (ships with Nancy)

File: `fragments/eng.lang.rust.md`

```markdown
---
id: eng.lang.rust
conditions:
  - detected.language == "rust"
priority: 50
---

# Rust Guidelines

- Follow Clippy recommendations
- ...
```

**2. Auto-discovered** via:

- Filename convention: `eng.lang.*.md`
- Condition in frontmatter
- No code changes needed
- Flat structure makes it easy to find: just look in `fragments/` directory

**3. User can override** with bead (optional)

File: `~/.nancy/beads/styles/rust.yaml`

```yaml
language: rust
preferences: "My specific Rust style..."
```

---

### Adding a Marketing Fragment

**1. Create Fragment** (ships with Nancy or user-created)

File: `fragments/marketing.copy.email.md`

```markdown
---
id: marketing.copy.email
conditions:
  - task.type == "email_campaign"
priority: 60
---

# Email Copywriting Guidelines

- Subject lines: 6-8 words
- Opening hook in first 2 sentences
- Clear CTA above the fold
- Mobile-first formatting
```

**2. Auto-discovered** via:

- Domain prefix: `marketing.*`
- Visible at a glance in flat directory
- No nested folders to navigate

**3. Works with marketing-specific beads**

File: `~/.nancy/beads/marketing/brand.yaml`

```yaml
brand:
  voice: friendly, professional
  tone: conversational
  audience: B2B SaaS founders
```

---

### Adding a New Project

**User action**: Create bead

File: `~/.nancy/beads/projects/my-app.yaml`

```yaml
nancy_version: "1.0"
name: my-app
summary: "My awesome application"
type: production
tech_stack:
  languages: [TypeScript]
```

**System**: Automatically picked up by assembler

No Nancy updates needed. Just create the file.

---

## Anti-Patterns

### ❌ DON'T: Put instructions in beads

```yaml
# BAD - instructions don't belong in beads
instructions: "Always use strict mode and explicit types"
```

Instead → Put in fragment, reference bead data if needed

---

### ❌ DON'T: Put user-specific data in fragments

```markdown
<!-- BAD - Stuart's name hardcoded in fragment -->

You are working with Stuart.
```

Instead → Use interpolation: `{{user.identity.name}}`

---

### ❌ DON'T: Put composition logic in fragments

```markdown
<!-- BAD - fragment deciding what to include -->

{{#if typescript}}
{{include languages/typescript}}
{{/if}}
```

Instead → Put inclusion logic in assembler

---

## Quick Reference

### Placement Guide

| Question                | Bead | Fragment | Assembler |
| ----------------------- | ---- | -------- | --------- |
| Can it go in a form?    | ✅   | ❌       | ❌        |
| Same for everyone?      | ❌   | ✅       | ✅        |
| User-specific?          | ✅   | ❌       | ❌        |
| Instructions to LLM?    | ❌   | ✅       | ❌        |
| Composition rules?      | ❌   | ❌       | ✅        |
| Queryable data?         | ✅   | ❌       | ❌        |
| Contains {{variables}}? | ❌   | ✅       | ❌        |
| Changes per project?    | ✅   | ❌       | ❌        |
| Ships with Nancy?       | ❌   | ✅       | ✅        |

### Fragment Naming Examples

| Domain    | Category   | Name       | Filename                        |
| --------- | ---------- | ---------- | ------------------------------- |
| eng       | lang       | typescript | `eng.lang.typescript.md`        |
| eng       | framework  | react      | `eng.framework.react.md`        |
| eng       | tool       | git        | `eng.tool.git.md`               |
| marketing | copy       | email      | `marketing.copy.email.md`       |
| marketing | campaign   | launch     | `marketing.campaign.launch.md`  |
| legal     | contract   | saas       | `legal.contract.saas.md`        |
| legal     | privacy    | gdpr       | `legal.privacy.gdpr.md`         |
| creative  | writing    | blogpost   | `creative.writing.blogpost.md`  |
| creative  | design     | brandguide | `creative.design.brandguide.md` |
| workflows | linear     | -          | `workflows.linear.md`           |
| meta      | principles | -          | `meta.principles.md`            |

**All fragments live in**: `fragments/` directory (flat, no subdirectories)

---

## Provenance in Assembled Prompts

Every assembled prompt includes **provenance metadata** that tracks:

### What's Included

- **Which fragments** were used (with file paths, versions, and hashes)
- **Which beads** provided data (with file paths and hashes)
- **What was detected** (language, framework, git features)
- **When it was assembled** (timestamp)
- **How to reproduce it** (cache key)

### Benefits

1. **Easy debugging**: See which fragment caused an issue and jump to the source file
2. **Version control**: Track exactly which version of each fragment was used
3. **Modification tracking**: Know when fragments or beads change via hash comparison
4. **Reproducibility**: Recreate exact prompts given the same inputs
5. **Impact analysis**: Find all prompts using a specific fragment before making changes

### Example

```markdown
---
provenance:
  assembler:
    name: task-init
    version: 1.0

  fragments:
    - id: core.principles
      file: templates/fragments/core.principles.md
      hash: a4f3b2c1d5e6f7a8

    - id: user.identity
      file: templates/fragments/user.identity.md
      hash: d5e6f7a8b9c0d1e2

  beads:
    - file: beads/user.yaml
      hash: f3a4b5c6d7e8f9a0
---

<!-- BEGIN: core.principles | templates/fragments/core.principles.md -->

...

<!-- END: core.principles -->

<!-- BEGIN: user.identity | templates/fragments/user.identity.md -->

...

<!-- END: user.identity -->
```

See `research/intelligence/04.provenance.md` for complete details.

---

## Summary

**Beads**: Facts (name: "Stuart", mode: "production")

**Fragments**: Instructions ("Use {{mode}} standards")

**Assemblers**: Rules ("If TypeScript, include lang.typescript")

**The line**: If a non-developer could edit it in a form, it's a bead. If not, it's a fragment or assembler.

**When in doubt**: Ask "Is this teaching the LLM how to behave (fragment) or telling it facts about the world (bead)?"
