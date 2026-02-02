# TODO: Update Docs for Automatic Inbox Injection

**Created:** 2025-01-19
**Context:** Bidirectional push notifications now work - directives and messages are automatically injected into agent panes via tmux send-keys. Workers no longer need to poll.

## What Changed

The notification system (`src/notify/`) now:

1. Watches both inbox directories via fswatch
2. When orchestrator sends directive → `nancy inbox` auto-injected into worker pane
3. When worker sends message → `nancy messages` auto-injected into orchestrator pane

**Fix applied:** Removed Escape key from injection (was being echoed as `^[`)

---

## Files Requiring Updates

### CRITICAL - Worker Instructions

#### 1. `templates/PROMPT.md.template`

- **Line 35:** `"Check directives periodically"` → Should say directives are auto-injected
- **Line 41:** Manual `nancy inbox` example → Note as fallback only
- **Line 69:** Manual inbox check in completion criteria → Update

#### 2. `.humanwork/tasks/*/PROMPT.md` (active tasks)

- Same pattern as template
- Line 35: "Check directives periodically"
- Line 41: Manual `hw inbox` example

---

### HIGH - Skills

#### 3. `skills/check-directives/skill.md`

**This skill may need deprecation or major refactoring**

Current content teaches manual polling:

- Lines 10-14: Manual `nancy inbox` command
- Lines 30-34: "When to Check" - lists manual trigger points
- Lines 40-46: "Pre-Completion Check" with manual inbox verification

**Options:**

- A) Deprecate skill entirely (auto-injection handles it)
- B) Refactor to describe auto-injection, keep manual as fallback
- C) Rename to "inbox-fallback" or similar

#### 4. `skills/orchestrator/SKILL.md`

- Lines 35-39: "Checking Messages from Worker" still says manual `nancy messages`
- Should note messages are auto-injected now

---

### MEDIUM - Documentation

#### 5. `skills/check-tokens/SKILL.md`

- Line 5: "periodically during long tasks" language
- May want to adjust timing expectations

#### 6. `skills/README.md`

- Line 33: Documents check-directives skill triggers
- Update description to reflect auto-injection

#### 7. `src/cmd/inbox.sh`

- Lines 7-8: Help text defines manual commands
- Add note that these are fallback commands (auto-injection is primary)

---

### LOW - Planning Docs (optional)

#### 8. `.planning/phases/03-message-notification-prototypes/`

- Research docs about fswatch vs polling
- Could add completion notes about auto-injection implementation

---

## Recommended Message Updates

### Old (Manual Polling)

````
**Check directives periodically** - especially after completing major tasks.
The orchestrator may have guidance.

**Checking for messages:**
```bash
nancy inbox
````

```

### New (Auto-Injection)
```

**Directives arrive automatically** - when the orchestrator sends a directive,
`nancy inbox` will be injected into your pane automatically. No polling needed.

**Manual fallback (if needed):**

```bash
nancy inbox
```

```

---

## Testing Verification

Tested 2025-01-19:
- [x] Orchestrator → Worker injection works (removed ^[ escape issue)
- [x] Worker → Orchestrator injection works
- [x] fswatch detects new files in both inbox directories
- [x] tmux send-keys successfully injects commands

---

## Related Files (Implementation - No Changes Needed)

These files implement the auto-injection and are working correctly:
- `src/notify/inject.sh` - Injection logic
- `src/notify/watcher.sh` - fswatch bidirectional watcher
- `src/notify/router.sh` - Notification routing
```
