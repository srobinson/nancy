# skills.sh Research

> Research Date: 2026-01-27
> Status: Active exploration

## Overview

**skills.sh** is Vercel's "npm for AI agents" - a registry and package manager for modular agent skills. Launched January 21, 2026.

- **URL**: https://skills.sh/
- **CLI**: `npx skills`
- **Positioning**: The Agent Skills Directory

## API Endpoints (Undocumented)

### 1. Search Skills

```
GET https://skills.sh/api/search?q=<query>
```

**Response:**
```json
{
  "query": "react",
  "searchType": "fuzzy",
  "skills": [
    {
      "id": "vercel-react-best-practices",
      "name": "vercel-react-best-practices",
      "installs": 56409,
      "topSource": "vercel-labs/agent-skills"
    }
  ],
  "count": 20,
  "duration_ms": 5
}
```

### 2. List All Skills (Popularity Sorted)

```
GET https://skills.sh/api/skills
```

**Response:**
```json
{
  "skills": [
    {"id": "vercel-react-best-practices", "installs": 56448, "topSource": "vercel-labs/agent-skills"},
    {"id": "web-design-guidelines", "installs": 42996, "topSource": "vercel-labs/agent-skills"},
    ...
  ],
  "hasMore": true
}
```

### Top Skills by Installs (Jan 2026)

| Skill | Installs | Source |
|-------|----------|--------|
| vercel-react-best-practices | 56k | vercel-labs |
| web-design-guidelines | 43k | vercel-labs |
| remotion-best-practices | 39k | remotion-dev |
| frontend-design | 20k | anthropics |
| find-skills | 12.8k | vercel-labs |
| skill-creator | 11.5k | anthropics |
| agent-browser | 9.2k | vercel-labs |
| seo-audit | 5.7k | coreyhaines31 |

### NOT Available

- `/api/trending` - 404
- `/api/categories` - 404
- `/api/skills/<id>` - 404 (no detail endpoint)

## Getting Skill Content

Skill content lives on GitHub. Pattern to fetch SKILL.md:

```
https://raw.githubusercontent.com/<owner>/<repo>/main/skills/<skill-folder>/SKILL.md
```

**Important:** The skill folder name may differ from the ID:
- ID: `vercel-react-best-practices`
- Folder: `react-best-practices`

Use GitHub API to discover exact paths:
```
GET https://api.github.com/repos/<owner>/<repo>/contents/skills
```

## SKILL.md File Format

Skills use YAML frontmatter + markdown body:

```markdown
---
name: vercel-react-best-practices
description: React and Next.js performance optimization guidelines...
license: MIT
metadata:
  author: vercel
  version: "1.0.0"
---

# Vercel React Best Practices

## When to Apply

Reference these guidelines when:
- Writing new React components or Next.js pages
- Implementing data fetching
- Reviewing code for performance issues

## Rule Categories by Priority

| Priority | Category | Impact |
|----------|----------|--------|
| 1 | Eliminating Waterfalls | CRITICAL |
| 2 | Bundle Size Optimization | CRITICAL |
...
```

### Key Sections

1. **Frontmatter** - name, description, license, metadata
2. **When to Apply** - Trigger conditions
3. **Rule Categories** - Organized guidelines
4. **Quick Reference** - Actionable rules

## CLI Commands

| Command | Purpose |
|---------|---------|
| `skills find [query]` | Search for skills (works non-interactively) |
| `skills add <package>` | Install a skill |
| `skills init [name]` | Create a new skill |
| `skills check` | Check for updates |
| `skills update` | Update all skills |
| `skills add <pkg> -l` | List available skills in a repo |

### Install Flags

- `-g, --global` - Install globally (user-level)
- `-s, --skill <names>` - Specify skill names
- `-y, --yes` - Skip confirmation prompts
- `-a, --agent <agents>` - Target specific agents (claude-code, cursor, etc.)
- `--all` - Install all skills to all agents

### Install Command Pattern

```bash
npx skills add <topSource>@<id> -g -y
# Example:
npx skills add vercel-labs/agent-skills@vercel-react-best-practices -g -y
```

## URL Patterns

- **Registry**: `https://skills.sh/<owner>/<repo>/<skill-name>`
- **Install via URL**: `npx skills add https://github.com/<owner>/<repo> --skill <skill-name>`

## Major Skill Publishers

| Publisher | Repo | Notable Skills |
|-----------|------|----------------|
| vercel-labs | agent-skills | vercel-react-best-practices, web-design-guidelines |
| anthropics | skills | frontend-design, skill-creator, pdf, mcp-builder |
| remotion-dev | skills | remotion-best-practices |
| expo | skills | building-native-ui, upgrading-expo |
| coreyhaines31 | marketingskills | seo-audit, copywriting, marketing-psychology |
| supabase | agent-skills | supabase-postgres-best-practices |
| better-auth | skills | better-auth-best-practices |

---

## Opportunity for Nancy

**Dynamic capability acquisition at runtime:**

1. Worker encounters unfamiliar task domain
2. Query skills.sh API for relevant skills
3. Install skill with `npx skills add ... -g -y`
4. Skill instructions become available to agent
5. Execute task with enhanced capabilities

### Implementation Options

1. **MCP Tool** - Add `search_skills` and `install_skill` tools
2. **Built-in Skill** - Create a "find-skills" skill for Nancy
3. **Pre-flight Check** - Before task execution, check if relevant skills exist

### Integration Flow

```
[Task Received]
    → Extract domain keywords
    → GET https://skills.sh/api/search?q=<keywords>
    → Filter by installs threshold (e.g., >1000)
    → Check if not already installed
    → npx skills add <topSource>@<id> -g -y
    → Continue with enhanced capabilities
```

---

## Open Questions

- [x] Is there a skill detail/content API endpoint? **NO - fetch from GitHub**
- [ ] Rate limits on the search API?
- [x] Can we get skill content (SKILL.md) via API? **Via GitHub raw**
- [x] Categories/tags API endpoint? **NO**
- [x] Trending/popular endpoint? **NO - use `/api/skills` sorted by installs**

## Filesystem Layout

### Install Locations

```
~/.agents/skills/<skill-name>/       # Actual skill content (SKILL.md + assets)
~/.claude/skills/<skill-name>/       # Symlinks to ~/.agents/skills/
```

### Installed Skill Structure

```
~/.agents/skills/frontend-design/
├── SKILL.md                         # Main skill instructions
└── [optional assets]

~/.claude/skills/frontend-design → ../../.agents/skills/frontend-design
```

### Check if Skill is Installed

```bash
# Check symlink exists
ls -la ~/.claude/skills/<skill-name>

# Or check actual content
test -f ~/.agents/skills/<skill-name>/SKILL.md && echo "installed"
```

### Custom (Local) Skills

Non-symlinked directories in `~/.claude/skills/` are custom/local skills:

```
~/.claude/skills/
├── agent-browser -> ../../.agents/skills/agent-browser    # installed
├── frontend-design -> ../../.agents/skills/frontend-design # installed
├── create-spec/                                            # custom
├── nancy/                                                  # custom
└── nancy-check-directives/                                 # custom
```

---

## Next Steps

1. ~~Explore more API endpoints~~ DONE
2. ~~Examine actual SKILL.md file format in detail~~ DONE
3. ~~Investigate where installed skills end up on filesystem~~ DONE
4. Prototype integration with Nancy
5. Test dynamic skill installation flow
