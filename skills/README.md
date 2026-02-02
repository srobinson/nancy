<!-- b_path:: skills/README.md -->

# Nancy Skills

Custom Claude Code skills for the Nancy orchestration system.

## Overview

Skills are markdown files with YAML frontmatter that Claude Code loads at session start. Each skill provides context and instructions for specific tasks. Nancy skills enable bidirectional communication between orchestrator and worker agents.

## Character Budget

Claude Code has a **15,000 character limit** for combined skill content.

**Current usage:** ~9,000 characters (60% of budget)

| Skill            | Size      | Description                     |
| ---------------- | --------- | ------------------------------- |
| session-history  | 2,221     | Access CLI session history      |
| check-tokens     | 2,104     | Monitor context usage           |
| orchestrator     | 1,831     | Supervise worker agents         |
| create-spec      | 1,061     | Create task specifications      |
| check-directives | 929       | Check for orchestrator messages |
| send-message     | 509       | Send messages to orchestrator   |
| update-spec      | 378       | Mark criteria complete          |
| **Total**        | **9,033** |                                 |

## Skill Inventory

| Name             | Primary Triggers                                         | Purpose                                        |
| ---------------- | -------------------------------------------------------- | ---------------------------------------------- |
| check-tokens     | "check context", "token usage", "how much context"       | Monitor context window and get recommendations |
| session-history  | "last session", "what did we do", "continue work"        | Access and summarize past sessions             |
| check-directives | "check inbox", "orchestrator messages", "any directives" | Process messages from orchestrator             |
| send-message     | "send message", "report blocker", "request review"       | Communicate with orchestrator                  |
| create-spec      | "create spec", "define task", "what to build"            | Interactive requirements elicitation           |
| update-spec      | "mark complete", "check off criterion"                   | Track success criteria completion              |
| orchestrator     | "orchestrate", "supervise worker", "monitor task"        | Run orchestrator mode                          |

## Best Practices Applied

Based on research in `.planning/phases/3.1-skills-deep-dive/3.1-RESEARCH.md`:

1. **Single-line descriptions** - Entire description on one line
2. **Prettier-ignore comments** - `# prettier-ignore` before description to prevent reformatting
3. **Third-person voice** - "Check context..." not "I check context..."
4. **Trigger-rich language** - Multiple natural language phrases that invoke the skill

## Maintenance Notes

### Adding New Skills

1. Create `skills/<name>/SKILL.md` with standard frontmatter
2. Keep skill files under 2,500 characters when possible
3. Update this README with new skill entry
4. Test that skill triggers correctly in fresh session

### Frontmatter Format

```yaml
---
name: skill-name
description: Single-line description with trigger phrases. Use when X, Y, or Z.
---
```

### Character Budget Management

If approaching 15k limit:

- Consolidate related skills
- Move detailed instructions to referenced files
- Keep SKILL.md as routing/summary only

---

_Last updated: 2026-01-13_
