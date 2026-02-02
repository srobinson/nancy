# Nancy + Linear Integration Proposal

## Vision

Linear becomes the single source of truth for work. Nancy workers execute against Linear issues instead of local SPEC files. All progress, context, and status flows through Linear.

## Current Nancy Architecture

```
.nancy/tasks/{task}/
├── SPEC.md          # Requirements (manual)
├── PROMPT.md        # Worker prompt (template)
├── sessions/        # Conversation history
├── comms/           # Orchestrator ↔ Worker messaging
└── COMPLETE         # Completion marker
```

**Key integration points:**

- `src/task/task.sh`: Task CRUD, completion check
- `src/task/session.sh`: Session ID generation (`nancy-{task}-iter{n}`)
- `src/cmd/start.sh`: Main loop, template substitution
- `templates/PROMPT.md.template`: Worker instructions

## Proposed Workflow

### Interactive Mode (You + Claude)

```
┌─────────────────────────────────────────────────────────────┐
│  1. Discuss idea                                            │
│  2. Create Linear issue (Backlog)                          │
│  3. Flesh out when ready                                    │
│  4. Move to Todo when spec is complete                      │
└─────────────────────────────────────────────────────────────┘
```

### Worker Mode (Autonomous)

```
┌─────────────────────────────────────────────────────────────┐
│  1. Worker queries: list_issues(state="Todo", priority)     │
│  2. Picks highest priority issue                            │
│  3. update_issue(state="In Progress")                       │
│  4. create_comment("🤖 Starting - Session: {session_id}")   │
│  5. Work loop (reads issue description as spec)             │
│  6. Periodic progress comments                              │
│  7. create_comment("✅ Complete - {summary}")               │
│  8. update_issue(state="In Review")                         │
└─────────────────────────────────────────────────────────────┘
```

### Review Mode (Human)

```
┌─────────────────────────────────────────────────────────────┐
│  1. Review "In Review" issues                               │
│  2. Check linked PR/commits                                 │
│  3. Approve → Done  OR  Request changes → Todo             │
└─────────────────────────────────────────────────────────────┘
```

## Integration Design

### Phase 1: Linear-Aware Worker

**Changes:**

1. New skill: `/linear-sync` - sync issue ↔ local task
2. Worker prompt includes Linear issue ID
3. Progress posts to Linear comments
4. Completion updates Linear state

**PROMPT.md additions:**

```markdown
# Nancy Worker - {{TASK_NAME}}

**Session:** `{{SESSION_ID}}`
**Linear Issue:** `{{LINEAR_ISSUE_ID}}`

## Linear Integration

On start, you have already been assigned this Linear issue.
Post progress updates as comments on the issue.
When complete, the orchestrator will move to "In Review".
```

### Phase 2: Linear as Task Source

**Changes:**

1. `nancy start` queries Linear for Todo issues
2. No local SPEC.md - issue description IS the spec
3. Task name derived from issue identifier (e.g., `ALP-75`)
4. Session links back to Linear issue

**Flow:**

```bash
nancy start
# → Queries Linear: "What's highest priority Todo?"
# → ALP-75: "Implement cost estimations"
# → Creates local task dir: .nancy/tasks/ALP-75/
# → Updates Linear: In Progress
# → Starts worker with issue context
```

### Phase 3: Full Bidirectional Sync

**Changes:**

1. Comments sync both directions
2. Orchestrator directives via Linear comments (`@nancy pause`)
3. Worker responses appear in Linear
4. Review workflow integrated

## Technical Implementation

### New Files

```
src/linear/
├── client.sh       # MCP tool wrappers
├── sync.sh         # Issue ↔ Task sync
└── hooks.sh        # Lifecycle hooks

skills/linear-sync/
├── SKILL.md        # Skill definition
└── invoke.sh       # Sync logic
```

### Hook Points

**on_worker_start:**

```bash
linear::update_issue "$issue_id" --state "In Progress"
linear::create_comment "$issue_id" "🤖 Starting - Session: $session_id"
```

**on_progress (periodic):**

```bash
linear::create_comment "$issue_id" "📊 Progress: $summary"
```

**on_worker_complete:**

```bash
linear::create_comment "$issue_id" "✅ Complete: $summary"
linear::update_issue "$issue_id" --state "In Review"
```

### Configuration

```yaml
# .nancy/config.yaml
linear:
  enabled: true
  project: "Nancy"
  team: "Alphabio"

  pick:
    state: "Todo"
    order_by: "priority"
    labels: [] # Optional filter

  states:
    working: "In Progress"
    complete: "In Review"

  comments:
    on_start: true
    include_session: true
    progress_interval: "5m" # Or "never"
```

## Migration Path

### Today (No Breaking Changes)

- Add `/linear-sync` skill for manual sync
- Test with mdcontext project issues

### Next

- Add hooks to post comments on worker events
- Test automatic status transitions

### Later

- Make Linear the primary task source
- Remove dependency on local SPEC.md
- Full bidirectional comment sync

## Open Questions

1. **Review workflow**: Separate reviewer agent? Or human-only?
2. **Multiple projects**: How to scope which project worker pulls from?
3. **Dependencies**: Should worker respect Linear blockers?
4. **Cycles**: Integrate with Linear sprints?

## Success Criteria

- [ ] Worker can query Linear for highest priority Todo
- [ ] Worker updates issue state on start/complete
- [ ] Progress comments appear on Linear issue
- [ ] Session ID traceable in Linear
- [ ] No loss of context across iterations
