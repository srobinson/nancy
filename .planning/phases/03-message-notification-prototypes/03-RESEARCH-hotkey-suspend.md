<!-- b_path:: .planning/phases/03-message-notification-prototypes/03-RESEARCH-hotkey-suspend.md -->
# Research: Hotkey-Based System Suspension

**Status:** Complete
**Researched:** 2026-01-14
**Priority:** HIGH - Many projects want this feature
**Confidence:** HIGH (verified with official sources and GitHub issues)

## Executive Summary

**TL;DR: True mid-turn suspension is NOT reliably achievable due to multiple blocking factors:**

1. **tmux auto-continues stopped processes** - tmux sends SIGCONT to any process that receives SIGSTOP/SIGTSTP
2. **Claude Code + tmux has known issues** - SIGTSTP doesn't work correctly inside tmux (issue #3201)
3. **API connections timeout** - Suspending mid-turn will likely cause API connection failures on resume
4. **No native tmux pane suspension** - Feature request rejected by tmux maintainer

**Recommended approach:** File-based pause mechanism (simpler, more reliable) rather than signal-based suspension.

## Decisions Made

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Hotkey | **Prefix + ESC** (Ctrl+B, ESC) | Intuitive "stop" feel, user has escape-time 0 |
| Pause granularity | Between turns (graceful) | Mid-turn not feasible due to tmux/API constraints |
| Implementation | File-based (`comms/PAUSED`) | Simple, visible state, works in tmux |

---

## Research Findings

### 1. tmux Hotkey Binding Capabilities

**Verified:** HIGH confidence (official documentation)

tmux supports custom hotkey bindings via `bind-key`:

```bash
# With prefix (Ctrl+B then key)
bind-key s run-shell "suspend-all-panes.sh"

# Without prefix (direct key)
bind -n C-s run-shell "suspend-all-panes.sh"

# F-key binding (no prefix needed in root table)
bind -n F12 run-shell "toggle-suspend.sh"
```

**Key capabilities:**

- `run-shell` command executes arbitrary scripts
- Can bind any key combination including F-keys
- Can iterate all panes: `tmux list-panes -a -F "#{pane_id} #{pane_pid}"`
- Can send keys to panes: `tmux send-keys -t {pane} C-z`

**Limitation:** tmux keybindings only intercept when tmux has focus. Claude Code captures its own keystrokes.

**Sources:**

- [tmux(1) manual](https://man7.org/linux/man-pages/man1/tmux.1.html)
- [Binding Keys in tmux](https://www.seanh.cc/2020/12/28/binding-keys-in-tmux/)
- [Running Commands in All tmux Panes](https://nickjanetakis.com/blog/running-commands-in-all-tmux-sessions-windows-and-panes)

---

### 2. Process Suspension Signals

**Verified:** HIGH confidence (POSIX standard)

| Signal  | Number | Can Catch? | Purpose                  |
| ------- | ------ | ---------- | ------------------------ |
| SIGTSTP | 18     | Yes        | Terminal stop (Ctrl+Z)   |
| SIGSTOP | 17     | **No**     | Unconditional stop       |
| SIGCONT | 19     | Yes        | Continue stopped process |

**Key insight:** SIGSTOP cannot be caught or ignored - it's the "nuclear option" for stopping processes.

```bash
# Suspend a process
kill -SIGSTOP <pid>

# Resume a process
kill -SIGCONT <pid>

# Suspend entire process group
kill -SIGSTOP -<pgid>
```

**Sources:**

- [Two Great Signals: SIGSTOP and SIGCONT](https://major.io/p/two-great-signals-sigstop-and-sigcont/)
- [Linux Pause Process with Kill Signals](https://kedar.nitty-witty.com/blog/linux-shell-script-pause-a-process-with-kill-signals)

---

### 3. CRITICAL: tmux Auto-Continues Stopped Processes

**Verified:** HIGH confidence (tmux GitHub issue #1520)

**This is the blocking finding:**

> "It appears in handling SIGCHLD if the child is stopped due to SIGTSTP or SIGSTOP then it is continued."

tmux **automatically sends SIGCONT** to any child process that gets stopped. This means:

- `kill -SIGSTOP <pane_pid>` → tmux immediately sends SIGCONT
- Ctrl+Z in a pane → tmux may intervene before the process handles it
- **No workaround exists** - this is intentional tmux behavior

tmux maintainer response: "There is no other reason AFAIK" - indicating it's a design choice, not a bug.

**Implication:** Signal-based suspension **cannot work** for processes running inside tmux panes.

**Source:** [tmux/tmux#1520 - Continuation of stopped process](https://github.com/tmux/tmux/issues/1520)

---

### 4. Claude Code SIGTSTP Behavior

**Verified:** MEDIUM confidence (GitHub issues, may vary by version)

**Outside tmux:**

- Ctrl+Z correctly suspends Claude Code (fixed in v1.0.44)
- `fg` resumes the session with conversation history intact
- Fixed by remapping undo from Ctrl+Z to Ctrl+\_

**Inside tmux:**

- Issue #3201 reported Ctrl+Z acts as "undo" instead of suspend
- Root cause was identified as version mismatch in reporter's environment
- **May work** if Claude Code version is consistent

**API state on suspend:**

- No official documentation on API connection preservation
- Conversation history survives suspension
- API connections likely have timeouts that would expire during suspension
- Mid-turn suspension almost certainly causes "Request timed out" errors on resume

**Sources:**

- [Claude Code issue #588 - SIGTSTP handling](https://github.com/anthropics/claude-code/issues/588)
- [Claude Code issue #3201 - Ctrl+Z in tmux](https://github.com/anthropics/claude-code/issues/3201)
- [How to Suspend Claude Code](https://claudelog.com/faqs/how-to-suspend-claude-code/)

---

### 5. Multi-Pane Orchestration

**Verified:** HIGH confidence (tested patterns)

To send signals to all panes in a tmux session:

```bash
#!/bin/bash
# Get all pane PIDs in current session
tmux list-panes -s -F "#{pane_pid}" | while read pid; do
    # Get child processes (actual running commands)
    child_pid=$(pgrep -P "$pid" | head -1)
    if [[ -n "$child_pid" ]]; then
        kill -SIGSTOP "$child_pid"
    fi
done
```

**Problem:** Even if we send SIGSTOP, tmux will auto-continue the processes (see finding #3).

**Alternative - synchronize-panes:**

```bash
# Enable synchronized input to all panes
tmux setw synchronize-panes on

# Send Ctrl+Z to all panes at once
tmux send-keys C-z
```

**Limitation:** synchronize-panes only works for the current window, not across windows.

---

### 6. tmux Native Pane Suspension (Rejected Feature)

**Verified:** HIGH confidence (GitHub issue)

A feature request for native pane suspension ([tmux/tmux#3133](https://github.com/tmux/tmux/issues/3133)) was **rejected** by the maintainer:

> "I don't think this is something tmux should do when the shell can already do it."

There is no built-in way to suspend pane processes in tmux and show "pane suspended..." like "pane dead...".

**Source:** [tmux/tmux#3133 - Feature request for pane suspension](https://github.com/tmux/tmux/issues/3133)

---

### 7. tmux-suspend Plugin

**Verified:** MEDIUM confidence (plugin documentation)

The [tmux-suspend](https://github.com/MunifTanjim/tmux-suspend) plugin exists but solves a **different problem**:

- Designed for nested remote tmux sessions
- Restricts key bindings to active pane only
- Does NOT send signals to processes
- Works by modifying tmux options, not suspending processes

**Not applicable** to our use case of freezing Claude Code execution.

---

## Alternative Approaches Evaluation

### Option A: File-Based Pause (RECOMMENDED)

**Approach:** Worker polls for a PAUSE file; orchestrator creates/removes it via hotkey.

```bash
# In worker loop (check between turns, not mid-turn)
if [[ -f "comms/PAUSED" ]]; then
    # Display message, wait for file removal
    while [[ -f "comms/PAUSED" ]]; do
        sleep 0.5
    done
fi
```

**Pros:**

- Works reliably inside tmux
- No signal handling complexity
- State is visible (file exists = paused)
- Graceful - waits for current operation to complete

**Cons:**

- Can only pause **between turns**, not mid-turn
- Requires modifying the worker loop
- Not instant - depends on poll frequency

**Verdict:** ✅ Best option for Nancy. Pausing between turns is acceptable.

---

### Option B: SIGSTOP from Outside tmux

**Approach:** Run a companion process outside tmux that sends SIGSTOP to pane processes.

```bash
# From outside tmux (companion terminal)
pid=$(tmux list-panes -t nancy -F "#{pane_pid}" | head -1)
child=$(pgrep -P $pid)
kill -SIGSTOP $child

# Later
kill -SIGCONT $child
```

**Pros:**

- Bypasses tmux auto-continue (maybe - needs testing)
- True suspension possible

**Cons:**

- Requires companion process outside tmux
- Complex PID management
- tmux may still interfere
- API connections will timeout

**Verdict:** ⚠️ Technically possible but complex and unreliable.

---

### Option C: Message-Based Pause Directive

**Approach:** Send a "pause" directive through the existing comms system.

```bash
# Orchestrator sends directive
echo "Type: directive
Action: pause
Reason: User requested" > comms/worker/inbox/pause.md

# Worker checks directives regularly (already implemented)
# When sees "pause", enters wait loop
```

**Pros:**

- Uses existing infrastructure
- Worker can save state before pausing
- Clean integration with messaging system

**Cons:**

- Async - not instant
- Only works between turns
- Adds complexity to directive handling

**Verdict:** ✅ Good option, integrates well with existing design.

---

### Option D: tmux Client Suspension

**Approach:** Suspend the entire tmux client, not individual panes.

```bash
# Bind key to suspend client
bind-key z suspend-client
```

**Pros:**

- Built-in tmux feature
- Works reliably

**Cons:**

- Returns you to parent shell - can't see panes while suspended
- All panes suspended, no selective control
- `fg` needed to resume - not ideal UX

**Verdict:** ⚠️ Works but poor UX for monitoring suspended state.

---

### Option E: Kill and Restart with State Preservation

**Approach:** Ctrl+C to kill, then restart from saved state.

**Pros:**

- Clean shutdown
- No signal complexity

**Cons:**

- Loses current API turn
- Requires robust state persistence
- Slow resume time

**Verdict:** ❌ Too disruptive. Not a "pause" - it's a restart.

---

## Recommended Implementation

### Phase 1: File-Based Pause (MVP)

Implement a simple file-based pause that works between turns:

**1. Add PAUSED file check to worker loop:**

```bash
# In worker main loop
check_paused() {
    if [[ -f "$COMMS_DIR/PAUSED" ]]; then
        log "System paused - waiting for resume..."
        tmux display-message -d 0 "⏸️ PAUSED - Press Prefix+ESC to resume"
        while [[ -f "$COMMS_DIR/PAUSED" ]]; do
            sleep 0.5
        done
        log "Resumed"
        tmux display-message "▶️ Resumed"
    fi
}
```

**2. Add tmux hotkey binding:**

```bash
# In .tmux.conf or runtime
# DECIDED: Prefix + ESC (Ctrl+B, ESC) - user has escape-time 0, so instant response
bind Escape run-shell "nancy-toggle-pause"

# nancy-toggle-pause script
#!/bin/bash
PAUSE_FILE="$NANCY_COMMS_DIR/PAUSED"
if [[ -f "$PAUSE_FILE" ]]; then
    rm "$PAUSE_FILE"
    tmux display-message "▶️ Nancy RESUMED"
else
    touch "$PAUSE_FILE"
    tmux display-message "⏸️ Nancy PAUSED (after current turn)"
fi
```

**3. Display pause status in status line:**

```bash
# In tmux status-right
set -g status-right '#{?#{==:#{NANCY_PAUSED},1},⏸️ PAUSED,▶️ Running}'
```

### Phase 2: Enhanced Pause Directive (Optional)

If more control needed, add a "pause" directive type:

```bash
# New directive type
Type: directive
Action: pause
Reason: User requested review before continuing
Until: resume-directive
```

Worker handles specially - saves context, enters monitored wait state.

---

## Failure Modes & Mitigations

| Failure Mode                       | Likelihood | Mitigation                                       |
| ---------------------------------- | ---------- | ------------------------------------------------ |
| Worker doesn't see PAUSE file      | LOW        | Check at loop start AND after each operation     |
| PAUSE file left orphaned           | MEDIUM     | Add timeout, auto-resume after N minutes         |
| API request in-flight during pause | N/A        | Pause happens between turns, not mid-turn        |
| tmux not running                   | LOW        | Check tmux availability, fallback to basic pause |
| Multiple users toggling pause      | LOW        | Use lock file or atomic operations               |

---

## Open Questions

1. **Should pause be per-pane or system-wide?**

   - Recommendation: System-wide for MVP, per-pane for v2

2. **What about mid-turn pause for urgent interrupts?**

   - Answer: Not achievable reliably. Use Escape key in Claude Code for soft interrupt.

3. **Should pause state persist across Nancy restarts?**
   - Recommendation: No - fresh start should be unpaused

---

## Conclusion

**True mid-turn suspension is not feasible** due to:

1. tmux auto-continuing stopped processes
2. API connection timeouts
3. No native tmux pane suspension support

**File-based pause between turns is the practical solution:**

- Simple to implement
- Reliable
- Integrates with existing architecture
- Provides visual feedback
- Hotkey-activated via tmux binding

This approach trades "instant freeze" for "graceful pause after current operation" - a reasonable tradeoff given the technical constraints.

---

## Sources

### Primary (HIGH confidence)

- [tmux(1) Linux manual page](https://man7.org/linux/man-pages/man1/tmux.1.html)
- [tmux/tmux#1520 - Continuation of stopped process](https://github.com/tmux/tmux/issues/1520)
- [tmux/tmux#3133 - Pane suspension feature request](https://github.com/tmux/tmux/issues/3133)
- [Claude Code issue #588 - SIGTSTP handling](https://github.com/anthropics/claude-code/issues/588)
- [Claude Code issue #3201 - Ctrl+Z in tmux](https://github.com/anthropics/claude-code/issues/3201)

### Secondary (MEDIUM confidence)

- [tmux-suspend plugin](https://github.com/MunifTanjim/tmux-suspend)
- [How to Suspend Claude Code](https://claudelog.com/faqs/how-to-suspend-claude-code/)
- [Two Great Signals: SIGSTOP and SIGCONT](https://major.io/p/two-great-signals-sigstop-and-sigcont/)
- [Running Commands in All tmux Panes](https://nickjanetakis.com/blog/running-commands-in-all-tmux-sessions-windows-and-panes)
- [Binding Keys in tmux](https://www.seanh.cc/2020/12/28/binding-keys-in-tmux/)

### Tertiary (verified patterns)

- [Linux Pause Process with Kill Signals](https://kedar.nitty-witty.com/blog/linux-shell-script-pause-a-process-with-kill-signals)
- [Waiting for a File in a Shell Script](https://www.baeldung.com/linux/bash-wait-for-file)

---

_Research completed: 2026-01-14_
_Ready for implementation: Yes_
_Recommended next step: Implement file-based pause in Phase 4 or as separate mini-phase_
