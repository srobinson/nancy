---
id: lang.typescript
description: TypeScript coding guidelines
requires:
  - "beads: styles.typescript (optional)"
conditions:
  - "detected.language == 'typescript'"
priority: 50
section: coding_guidelines
version: "1.0"
tags: ["language", "typescript"]
---

# TypeScript Guidelines

{{#if beads.styles.typescript}}

## Project Style Configuration

**Mode**: {{beads.styles.typescript.mode}}

{{#if beads.styles.typescript.mode == "production"}}

### Production Standards

- Use strict TypeScript mode with explicit types
- Comprehensive error handling required
- No `any` types without justification and inline comments
- Type safety is paramount

{{else if beads.styles.typescript.mode == "poc"}}

### POC/Prototype Mode

- Speed over perfection
- `any` is acceptable for rapid iteration
- Focus on proving the concept
- Refactor for type safety later

{{/if}}

{{#if beads.styles.typescript.naming}}

### Naming Conventions

- Variables: {{beads.styles.typescript.naming.variables}}
- Functions: {{beads.styles.typescript.naming.functions}}
- Classes: {{beads.styles.typescript.naming.classes}}
  {{/if}}

{{#if beads.styles.typescript.formatting}}

### Formatting

- Quotes: {{beads.styles.typescript.formatting.quotes}}
- Semicolons: {{beads.styles.typescript.formatting.semicolons}}
- Indent: {{beads.styles.typescript.formatting.indent_size}} {{beads.styles.typescript.formatting.indent_style}}
  {{/if}}

{{#if beads.styles.typescript.preferences}}

### Additional Preferences

{{beads.styles.typescript.preferences}}
{{/if}}

{{else}}

## General TypeScript Guidelines

- Follow existing patterns in the codebase
- Use TypeScript's type system effectively
- Prefer type inference where appropriate
- Explicit types for public APIs and complex logic
  {{/if}}

## Best Practices

- Avoid premature abstraction
- Keep functions small and focused
- Use descriptive variable names
- Comment complex logic, not obvious code
