# Nancy Prompt Factory - Complete Design

**Status**: ✅ Design Complete - Ready for Implementation
**Date**: 2026-01-24

---

## What We Built

A composable, extensible, discoverable prompt factory system for Nancy that:

- ✅ Uses **YAML for data** (beads) - not the buggy beads tool
- ✅ Uses **Markdown for instructions** (fragments)
- ✅ Uses **YAML for composition** (assemblers)
- ✅ Has clear mental models for "what goes where"
- ✅ Scales from 1 to 100+ projects across any domain
- ✅ Zero-config extensibility (drop in new fragments)
- ✅ Schema-validated with IDE autocomplete
- ✅ **Domain-agnostic design** - works for engineering, marketing, legal, creative, and more
- ✅ **Flat directory structure** - human-browsable, discoverable, no deep nesting
- ✅ **Provenance metadata** - full traceability from assembled prompts back to source fragments

---

## Research Foundation

### Phase 1: Initial Research (00.initiative.\*)

- Schema design patterns (Kubernetes CRDs, JSON Schema composition)
- Composability patterns (template engines, LangChain)
- Extensibility patterns (plugin architectures, auto-discovery)
- Discoverability mechanisms (CLI patterns, schema introspection)
- Content organization (MVC, Jamstack, IaC separation)

### Phase 2: Beads Evaluation (01.beads-evaluation.\*)

**Verdict**: Do NOT use beads tool (pre-1.0, buggy, data loss risks)
**Instead**: Keep "beads" concept, use YAML files

- Beads tool: 17/30 score (lowest)
- YAML: 27/30 (winner for hierarchical data)
- TOML: 26/30 (winner for simple configs)

### Phase 3: TOML Reality Check (02.toml-reality-check.\*)

**Verdict**: Drop TOML, use YAML + Markdown + JSON + SQLite

- TOML problems: Can't represent nested structures, no null type, verbose
- 2026 tools: JSON 45%, YAML 27%, TOML 23%
- Emerging formats: No clear winner (Pkl, KCL niche, CUE stable)
- Pattern: Zero-config > format choice

---

## Architecture

### Directory Structure

```
nancy/
├── templates/                    # Ships with Nancy
│   ├── fragments/               # Flat directory - all fragments at one level
│   │   ├── meta.principles.md
│   │   ├── meta.objectivity.md
│   │   ├── user.identity.md
│   │   ├── user.preferences.md
│   │   ├── eng.typescript.md
│   │   ├── eng.python.md
│   │   ├── eng.react.md
│   │   ├── marketing.tone.md
│   │   ├── marketing.brand.md
│   │   ├── legal.compliance.md
│   │   ├── creative.storytelling.md
│   │   └── workflow.linear.md
│   │
│   ├── assemblers/              # YAML composition rules
│   │   ├── task-init.yaml
│   │   └── marketing-brief.yaml
│   │
│   └── schemas/                 # JSON Schema validation
│       ├── bead.user.schema.json
│       ├── bead.project.schema.json
│       ├── fragment.schema.json
│       └── assembler.schema.json
│
└── ~/.nancy/                    # User data
    ├── config.yaml              # User preferences
    ├── beads/                   # Structured memory
    │   ├── user.yaml
    │   ├── projects/*.yaml
    │   └── styles/*.yaml
    └── cache/
        └── bubble-gum.db        # SQLite
```

**Key Benefits of Flat Structure:**

- **Human browsable**: All fragments visible in one directory listing
- **Easy discovery**: `ls templates/fragments/` shows everything
- **Clear naming**: Domain prefix makes purpose obvious (eng., marketing., legal.)
- **No navigation**: No drilling through nested folders
- **Autocomplete friendly**: Tab completion works better with flat structure
- **Mental model**: Fragments are referenced by dot notation everywhere

### The Three Layers

1. **Beads (YAML)** - Facts about users, projects, preferences
2. **Fragments (Markdown)** - Reusable prompt templates
3. **Assemblers (YAML)** - Composition rules

### Mental Model

**"Could a non-developer edit this in a form UI?"**

- YES → Bead (YAML data)
- NO → Fragment (Markdown template)

---

## What We Created

### Schemas (JSON Schema for validation)

✅ `templates/schemas/bead.user.schema.json`

- User identity, preferences, context
- Validates `~/.nancy/beads/user.yaml`

✅ `templates/schemas/bead.project.schema.json`

- Project metadata, tech stack, patterns, constraints
- Validates `~/.nancy/beads/projects/*.yaml`

✅ `templates/schemas/bead.style.schema.json`

- Language-specific code style preferences
- Validates `~/.nancy/beads/styles/*.yaml`

✅ `templates/schemas/fragment.schema.json`

- Fragment frontmatter metadata
- Priority, conditions, dependencies

✅ `templates/schemas/assembler.schema.json`

- Assembly rules and composition logic

### Example Fragments (Flat Structure)

✅ `templates/fragments/meta.principles.md`

- Core Nancy principles (objectivity, task management, tool usage)

✅ `templates/fragments/user.identity.md`

- User context injection with interpolation

✅ `templates/fragments/eng.typescript.md`

- TypeScript guidelines with conditional logic (POC vs Production)

✅ `templates/fragments/workflow.linear.md`

- Linear integration workflow instructions

### Example Assembler

✅ `templates/assemblers/task-init.yaml`

- Detection logic (language, framework, git worktrees)
- Fragment selection (always + conditional)
- Priority ordering
- Output configuration

### Working Examples

✅ `examples/beads/user.yaml`

- Stuart's identity, preferences, context

✅ `examples/beads/projects/nancy-bubble-gum.yaml`

- Project metadata, tech stack, patterns

✅ `examples/beads/styles/typescript.yaml`

- TypeScript production mode preferences

✅ `examples/output/assembled-prompt.md`

- Fully assembled prompt showing end result
- Includes provenance metadata in YAML frontmatter
- Shows inline fragment boundary markers

### Documentation

✅ `research/intelligence/03.architecture.md`

- Complete architecture specification
- Composition logic pseudo-code
- Extensibility patterns
- Discovery mechanisms

✅ `MENTAL-MODEL.md`

- Clear guide for "what goes where"
- Decision trees and examples
- Anti-patterns
- Quick reference table

✅ `research/intelligence/04.provenance.md`

- Complete provenance metadata specification
- Benefits and use cases
- Implementation details
- CLI commands for querying and diffing

---

## Key Design Decisions

### ✅ YAML over TOML

- Better for nested/hierarchical data
- LLM tools prefer it (CrewAI, Continue.dev, Aider)
- User expectations (package.json, docker-compose, GitHub Actions)
- Handles long text better

### ✅ Markdown for Fragments

- Human and AI readable
- YAML frontmatter for metadata
- Supports code blocks, formatting
- Industry standard (Cursor, Copilot use .md for context)

### ✅ JSON Schema for Validation

- IDE autocomplete (VS Code, JetBrains)
- Runtime validation
- Self-documenting
- TypeScript generation possible

### ✅ Flat Directory Structure

- **Human discoverability**: All fragments visible in single `ls` command
- **No deep nesting**: Eliminates navigation friction
- **Dot notation**: File naming matches reference format (`eng.typescript.md` → `eng.typescript`)
- **Domain prefixes**: Clear categorization without folders (eng., marketing., legal., etc.)
- **Better autocomplete**: Tab completion more effective with flat structure
- **Mental model alignment**: How you reference = how it's stored

### ✅ Filesystem-Based Discovery

- Zero-config extensibility
- Add `eng.rust.md` → auto-discovered
- Convention over configuration
- Clear file organization

### ✅ Priority-Based Ordering

- Predictable composition
- meta.\* (0-9), user.\* (10-19), eng.\* (50-59), marketing.\* (60-69), etc.
- Override via priority in frontmatter

### ✅ Conditional Inclusion

- Context-aware assembly
- "If TypeScript detected, include eng.typescript"
- "If user bead exists, include user.identity"
- Declarative rules in assembler

### ✅ Provenance Metadata

- **YAML frontmatter**: Rich metadata about which fragments, beads, and context were used
- **Inline markers**: HTML comments showing fragment boundaries in assembled output
- **Full traceability**: Jump from prompt section to source file for debugging/editing
- **Change detection**: Hash-based tracking of fragment and bead modifications
- **Reproducibility**: Recreate exact prompts given the same inputs
- **Impact analysis**: Find all prompts using a specific fragment

---

## Extensibility Examples

### Adding a New Domain (Zero-Config)

**Example: Adding Legal Domain**

**1. Create fragment**: `templates/fragments/legal.contracts.md`

```markdown
---
id: legal.contracts
conditions:
  - project.domain == "legal"
  - project.workType == "contracts"
priority: 65
---

# Legal Contract Guidelines

- Use clear, unambiguous language
- Follow jurisdictional requirements
- Include standard clauses
  ...
```

**2. Done.** Auto-discovered. No code changes.

### Adding an Engineering Language (Zero-Config)

**1. Create fragment**: `templates/fragments/eng.go.md`

```markdown
---
id: eng.go
conditions:
  - detected.language == "go"
priority: 50
---

# Go Guidelines

- Follow effective Go patterns
- Use gofmt for formatting
  ...
```

**2. Done.** Auto-discovered. No code changes.

### Adding a Marketing Fragment

**1. Create fragment**: `templates/fragments/marketing.seo.md`

```markdown
---
id: marketing.seo
conditions:
  - project.domain == "marketing"
  - project.channels contains "web"
priority: 60
---

# SEO Best Practices

- Focus on user intent
- Optimize meta descriptions
  ...
```

**2. Done.** Condition: `project.domain == "marketing"`

### User Customization

**Create bead**: `~/.nancy/beads/styles/go.yaml`

```yaml
language: go
preferences: "My specific Go style..."
```

Fragments automatically interpolate this data.

---

## Supported Domains

The flat structure and dot notation naming makes it easy to support any domain:

### Engineering (eng.\*)

- `eng.typescript.md`, `eng.python.md`, `eng.go.md`, `eng.rust.md`
- `eng.react.md`, `eng.vue.md`, `eng.nextjs.md`
- `eng.testing.md`, `eng.security.md`

### Marketing (marketing.\*)

- `marketing.tone.md`, `marketing.brand.md`, `marketing.seo.md`
- `marketing.email.md`, `marketing.social.md`
- `marketing.copywriting.md`, `marketing.analytics.md`

### Legal (legal.\*)

- `legal.contracts.md`, `legal.compliance.md`, `legal.privacy.md`
- `legal.terms.md`, `legal.gdpr.md`

### Creative (creative.\*)

- `creative.storytelling.md`, `creative.voice.md`, `creative.imagery.md`
- `creative.video.md`, `creative.design.md`

### Product (product.\*)

- `product.strategy.md`, `product.roadmap.md`, `product.metrics.md`
- `product.ux.md`, `product.research.md`

### Finance (finance.\*)

- `finance.reporting.md`, `finance.analysis.md`, `finance.forecasting.md`

### Operations (ops.\*)

- `ops.devops.md`, `ops.monitoring.md`, `ops.incident.md`

### Workflow (workflow.\*)

- `workflow.linear.md`, `workflow.git-worktree.md`, `workflow.subagents.md`

**Adding a new domain is as simple as creating a new fragment with the domain prefix.**

---

## Discovery & Tooling

### CLI Commands (To Be Implemented)

```bash
# List available fragments (flat structure, easy to browse)
nancy fragments list

# Filter by domain
nancy fragments list --domain eng
nancy fragments list --domain marketing

# Describe a fragment (using dot notation)
nancy fragments describe eng.typescript
nancy fragments describe marketing.seo

# List beads
nancy beads list

# Show bead schema
nancy beads schema

# Dry-run assembly
nancy assemble --dry-run
```

### IDE Integration

VS Code autocomplete for beads and assemblers via JSON Schema:

```json
{
  "yaml.schemas": {
    "nancy/schemas/bead.user.schema.json": "~/.nancy/beads/user.yaml",
    "nancy/schemas/bead.project.schema.json": "~/.nancy/beads/projects/*.yaml"
  }
}
```

---

## Implementation Roadmap

### Phase 1: Core Engine

- [ ] Bead loader (YAML parsing + validation)
- [ ] Fragment loader (Markdown + frontmatter parsing)
- [ ] Assembler loader (YAML parsing)
- [ ] Detection logic (language, framework, git features)
- [ ] Variable interpolation (simple `{{var}}` replacement)
- [ ] Conditional logic (`{{#if}}` blocks)
- [ ] Priority-based ordering
- [ ] Assembly engine (combine fragments)

### Phase 2: Initial Fragments

**Engineering Domain:**

- [ ] `eng.typescript.md`
- [ ] `eng.go.md`
- [ ] `eng.python.md`
- [ ] `eng.react.md`
- [ ] `eng.testing.md`

**Core & Meta:**

- [ ] `meta.principles.md`
- [ ] `meta.objectivity.md`
- [ ] `user.identity.md`
- [ ] `user.preferences.md`

**Workflows:**

- [ ] `workflow.linear.md`
- [ ] `workflow.git-worktree.md`
- [ ] `workflow.subagents.md`

**Example Other Domains** (optional):

- [ ] `marketing.tone.md`
- [ ] `legal.compliance.md`
- [ ] `creative.storytelling.md`

### Phase 3: CLI

- [ ] `nancy fragments list`
- [ ] `nancy fragments describe <id>`
- [ ] `nancy beads list`
- [ ] `nancy beads schema`
- [ ] `nancy assemble --dry-run`
- [ ] `nancy init` (onboarding flow)

### Phase 4: Validation

- [ ] JSON Schema validation on load
- [ ] Error messages for invalid beads
- [ ] Warnings for missing optional beads
- [ ] Schema migration scripts

### Phase 5: Caching

- [ ] Cache assembled prompts by hash
- [ ] Invalidate on bead/fragment changes
- [ ] SQLite storage for cache
- [ ] Cache statistics

### Phase 6: Advanced Features

- [ ] Bead composition (merge user + project + team)
- [ ] Fragment overrides (`~/.nancy/fragments/`)
- [ ] Multi-language project support
- [ ] Shell completion (bash, zsh, fish)
- [ ] LSP for fragment editing

---

## Migration from Current System

### Current State

- Using Linear as source of truth
- Prompt is `templates/task-init.md`
- Static, not composable

### Migration Steps

1. **Extract to beads**
   - User identity → `~/.nancy/beads/user.yaml`
   - Project metadata → `~/.nancy/beads/projects/*.yaml`

2. **Break down task-init.md**
   - Principles → `fragments/meta.principles.md`
   - Linear workflow → `fragments/workflow.linear.md`
   - Language-specific → `fragments/eng.*.md`

3. **Create assembler**
   - `assemblers/task-init.yaml` with composition rules

4. **Validate**
   - Run `nancy assemble --dry-run`
   - Compare output to original prompt

5. **Deploy**
   - Switch Nancy to use assembled prompts
   - Monitor for issues

---

## Success Criteria

- ✅ Add new language without touching core code
- ✅ Add new domain (marketing, legal, etc.) without touching core code
- ✅ User can customize style preferences in YAML file
- ✅ IDE autocomplete for beads
- ✅ Clear "what goes where" mental model
- ✅ System scales to 100+ projects across any domain
- ✅ Fragments are discoverable via CLI and flat directory browsing
- ✅ Assembly is deterministic and cacheable
- ✅ Human-browsable structure (no deep nesting)

---

## Open Questions & Design Decisions

### 1. Bead Composition Strategy

**Question**: How do we merge team + project + user beads?

**Options**:

- A. Deep merge with precedence (team < project < user)
- B. Explicit override fields
- C. Layer system (base + overlays)

**Recommendation**: A (deep merge) with explicit precedence documented

### 2. Fragment Override Mechanism

**Question**: Can users override shipped fragments?

**Options**:

- A. `~/.nancy/fragments/` (flat) takes precedence
- B. No overrides, only extend
- C. Override via assembler

**Recommendation**: A (user fragments directory with same flat structure)

### 3. Validation Strictness

**Question**: Hard fail or warnings on schema violations?

**Options**:

- A. Hard fail always
- B. Warnings in development, errors in CI
- C. Configurable strictness

**Recommendation**: B (warnings + errors)

### 4. Multi-Language Projects

**Question**: How to handle polyglot codebases?

**Options**:

- A. Support array in `detected.language`
- B. Primary + secondary languages
- C. Per-directory detection

**Recommendation**: A (array support, include all matching fragments)

### 5. Versioning Strategy

**Question**: How to handle schema evolution?

**Options**:

- A. `nancy_version` in beads + migration scripts
- B. Semantic versioning of schemas
- C. Automatic migration on Nancy updates

**Recommendation**: A + B (version in beads, semver schemas, migration scripts)

---

## Next Steps

**Immediate**:

1. Review this design with team
2. Identify any gaps or concerns
3. Prioritize implementation phases
4. Assign owners to each phase

**Short Term**:

1. Implement core engine (Phase 1)
2. Create initial fragment library (Phase 2)
3. Build CLI (Phase 3)

**Long Term**:

1. Gather user feedback
2. Iterate on fragment library
3. Add advanced features (Phase 6)

---

## Resources

**Research Documents**:

- `research/intelligence/00.initiative.*.md` - Initial composability research
- `research/intelligence/01.beads-evaluation.*.md` - Beads vs alternatives
- `research/intelligence/02.toml-reality-check.*.md` - TOML vs YAML analysis
- `research/intelligence/03.architecture.md` - Complete architecture spec

**Implementation References**:

- `templates/schemas/*.schema.json` - JSON Schemas
- `templates/fragments/*.md` - Example fragments
- `templates/assemblers/*.yaml` - Example assemblers
- `examples/*` - Working examples

**Guides**:

- `MENTAL-MODEL.md` - "What goes where" guide

---

**Status**: ✅ Ready for implementation

**Questions?** Review the mental model doc or architecture spec.

**Let's build it.** 🚀
