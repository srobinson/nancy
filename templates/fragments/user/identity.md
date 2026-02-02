---
id: user.identity
description: User identity and context injection
requires:
  - "beads: user.identity"
priority: 10
section: role_and_context
version: "1.0"
tags: ["user", "context"]
---

# Working Context

You are working with **{{user.identity.name}}**, {{user.identity.role}}.

{{user.identity.summary}}

**Communication style**: {{user.identity.communication_style}}

{{#if user.preferences}}

## User Preferences

{{#if user.preferences.code_review}}

- Code review: {{user.preferences.code_review}}
  {{/if}}
  {{#if user.preferences.testing}}
- Testing approach: {{user.preferences.testing}}
  {{/if}}
  {{#if user.preferences.documentation}}
- Documentation: {{user.preferences.documentation}}
  {{/if}}
  {{/if}}
