---
name: create-spec
description: Create a task specification (SPEC.md) through interactive requirements elicitation. Use when helping users define what they want to build before autonomous execution begins.
---

# Create Spec

## Process

### 1. Explore First

Before asking questions, understand the codebase:

```bash
ls -la
git log --oneline -10
find . -type f -name "*.ts" -o -name "*.py" -o -name "*.sh" | head -30
```

### 2. Elicit Requirements

- Ask ONE question at a time
- Offer 2-4 concrete options (plus "other")
- Confirm understanding: "So [paraphrase], correct?"
- Focus on WHAT, not HOW

### 3. Generate SPEC.md

```markdown
# Task: <name>

## Goal

<clear statement of objective>

## Success Criteria

- [ ] <verifiable outcome 1>
- [ ] <verifiable outcome 2>

## Constraints

- <limitation 1>

## Notes

<implementation guidance if needed>
```

### Good vs Bad Criteria

✅ "All existing tests pass"
✅ "New endpoint returns 200 for valid input"
❌ "Code is clean" (subjective)
❌ "Performance is good" (unmeasurable)
