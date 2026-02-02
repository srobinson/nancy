---
id: eng.workflow.nancy-issues
domain: eng
category: workflow
name: nancy-issues
title: Nancy Issue Organization
description: How to structure Linear issues for Nancy autonomous execution
version: 1.0.0
priority: 72
conditions:
  - context.tool == "nancy"
tags: ["workflow", "linear", "nancy", "issues"]
---

# Nancy Ways of Working: Issue Organization

## Core Pattern: Parent → Subs

Nancy's execution model:

* **Parent Issue** = The feature/outcome (the WHAT) + acceptance criteria (the WHY)
* **Sub-Issues** = Implementation steps (the HOW)
* **Worker Loop** = Nancy iterates through all sub-issues sequentially
* **Completion** = All subs Worker Done → Parent marked "Worker Done" → PR review

## Golden Rule: Batch Your Work

**❌ Anti-pattern:** Parent with 1 sub-issue

* Creates unnecessary iteration overhead
* Makes progress tracking tedious
* Wastes review cycles

**✅ Pattern:** Parent with meaningful sub-issues (typically 3-20, can be 100+)

* Each sub is a discrete, completable unit of work
* Sub represents ~1-4 hours of focused implementation
* Subs can be completed independently when possible

## Breaking Down Features

### Small Feature (3-10 subs)

Example: "Add user profile export"

* Sub 1: Add export button to profile UI
* Sub 2: Implement CSV generation logic
* Sub 3: Add JSON export format
* Sub 4: Add download handling
* Sub 5: Update tests

### Medium Feature (10-30 subs)

Example: "Implement authentication system"

* Group by component:
  * Subs 1-5: Database schema and models
  * Subs 6-12: API endpoints
  * Subs 13-18: UI components
  * Subs 19-25: Integration tests
  * Subs 26-30: Documentation

### Large Feature (30-100+ subs)

Example: "Build analytics dashboard"

* **Phase 1: Data Layer** (Subs 1-20)
* **Phase 2: API Layer** (Subs 21-45)
* **Phase 3: UI Components** (Subs 46-80)
* **Phase 4: Integration** (Subs 81-100)

Use sub-issue descriptions to indicate phase/grouping.

## When NOT to Create a Parent

Only Parent Issues with a **HotFix** label will be worked on without sub-issues:

* Fix typo in README
* Update dependency version
* Add single console.log for debugging

## Questions to Ask

Before creating parent + subs:

1. Does this feature have multiple distinct implementation steps?
2. Will Nancy benefit from iterating through discrete chunks?
3. Can I break this into 3+ meaningful sub-issues?

If no to any → Consider a HotFix issue instead.

---

**Source**: Linear document "Nancy Ways of Working: Issue Organization" (meta project)
**Last Updated**: 2026-01-24
