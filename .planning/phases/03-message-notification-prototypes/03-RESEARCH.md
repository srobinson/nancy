<!-- b_path:: .planning/phases/03-message-notification-prototypes/03-RESEARCH.md -->

# Phase 3: Message Notification Prototypes - Research

**Researched:** 2026-01-13
**Domain:** tmux notifications, signal handling, file watching on macOS
**Confidence:** HIGH

<research_summary>

## Summary

Researched mechanisms to notify the orchestrator pane when worker sends messages. Three prototype approaches identified: tmux display-message/popup, signal handling (SIGUSR1/SIGUSR2), and file watchers (fswatch).

Key finding: tmux has excellent notification primitives (display-message, display-popup, bell/activity alerts). Signal handling is powerful but Claude Code doesn't currently support signal-triggered prompts (it's a feature request). File watching via fswatch is the most flexible cross-platform approach.

**Primary recommendation:** Combine tmux display-message for visual notification in the Logs pane with fswatch watching the orchestrator inbox. The Logs pane can then relay notifications using tmux display-message to the orchestrator pane's status line. Signal-based approach is elegant but requires Claude Code feature support that doesn't exist yet.
</research_summary>

<standard_stack>

## Standard Stack

### Core

| Library           | Version | Purpose              | Why Standard                                         |
| ----------------- | ------- | -------------------- | ---------------------------------------------------- |
| tmux              | 3.6+    | Terminal multiplexer | Already required by Nancy, has display-message/popup |
| fswatch           | 1.18.3  | File change monitor  | Cross-platform, uses native FSEvents on macOS        |
| terminal-notifier | 2.0+    | macOS notifications  | Native macOS alerts from CLI                         |

### Supporting

| Library   | Version  | Purpose         | When to Use                             |
| --------- | -------- | --------------- | --------------------------------------- |
| jq        | 1.6+     | JSON parsing    | Already in Nancy, parse message content |
| bash trap | built-in | Signal handling | Simple signal-based IPC                 |

### Alternatives Considered

| Instead of        | Could Use     | Tradeoff                                            |
| ----------------- | ------------- | --------------------------------------------------- |
| fswatch           | kqueue direct | kqueue doesn't scale well, limited file descriptors |
| fswatch           | polling loop  | Resource intensive, adds latency                    |
| display-message   | display-popup | Popup blocks input, message is non-blocking         |
| terminal-notifier | osascript     | terminal-notifier has clickable actions             |

**Installation:**

```bash
# fswatch (if not installed)
brew install fswatch

# terminal-notifier (optional, for system notifications)
brew install terminal-notifier
```

</standard_stack>

<architecture_patterns>

## Architecture Patterns

### Recommended Project Structure

```
src/
├── comms/           # Existing - message send/receive
├── notify/          # NEW - notification mechanisms
│   ├── index.sh     # Module loader
│   ├── tmux.sh      # tmux display-message/popup/bell
│   ├── watcher.sh   # fswatch-based file watching
│   └── signal.sh    # Signal handling (future)
└── cmd/
    └── internal.sh  # Updated _logs to use notification
```

### Pattern 1: Logs Pane as Message Relay

**What:** Repurpose the Logs pane to watch orchestrator inbox and relay notifications
**When to use:** Primary pattern - non-blocking, uses existing pane
**Example:**

```bash
# In _logs command - watch orchestrator inbox
cmd::_logs_v2() {
    local task="$1"
    local inbox_dir="$NANCY_TASK_DIR/$task/comms/orchestrator/inbox"

    # Watch for new messages
    fswatch -0 "$inbox_dir" | while read -d "" event; do
        if [[ "$event" == *.md ]]; then
            # Display notification in orchestrator pane status
            tmux display-message -t "nancy-${task}.0" \
                "Worker message: $(basename "$event")"

            # Also display in logs pane
            echo "[$(date +%H:%M:%S)] New message: $(basename "$event")"
        fi
    done
}
```

### Pattern 2: tmux Display Message (Non-Blocking)

**What:** Show transient message in status line without interrupting user
**When to use:** Quick alerts that don't need acknowledgment
**Example:**

```bash
# Source: tmux man page
# Display message in specific pane's client status line
tmux display-message -t "$target_pane" "Worker needs attention"

# With delay (milliseconds) before auto-dismiss
tmux display-message -d 5000 -t "$target_pane" "Task complete"

# Print to stdout instead (useful for logging)
tmux display-message -p "#{pane_current_command}"
```

### Pattern 3: tmux Display Popup (Modal, Blocking)

**What:** Floating window overlay that requires dismissal
**When to use:** Urgent messages that need acknowledgment (use sparingly)
**Example:**

```bash
# Source: tmux 3.2+ man page
# Simple popup showing message content
tmux display-popup -t "nancy-${task}.0" \
    -w 60% -h 30% \
    -E "cat '$message_file'; echo 'Press Enter to dismiss'; read"

# Popup with custom styling
tmux display-popup -s "bg=red,fg=white" \
    -T "URGENT: Worker Blocked" \
    -E "cat '$message_file'"
```

### Pattern 4: tmux Bell/Activity Alert

**What:** Use tmux's built-in alert system for window flagging
**When to use:** Subtle notification that doesn't interrupt
**Example:**

```bash
# Send ASCII BEL to trigger bell alert
printf '\a'

# Configure tmux to show visual indicator
# In tmux.conf or via commands:
tmux set-option -g visual-bell on
tmux set-option -g bell-action any
```

### Anti-Patterns to Avoid

- **Using display-popup for every message:** Popup blocks input, annoying for frequent updates
- **Polling for file changes:** Use fswatch event-driven approach instead
- **SIGUSR1 to Claude Code:** Not currently supported, would terminate process
- **Writing to orchestrator's terminal:** Don't use send-keys to inject text into Claude session
  </architecture_patterns>

<dont_hand_roll>

## Don't Hand-Roll

| Problem              | Don't Build               | Use Instead                  | Why                                |
| -------------------- | ------------------------- | ---------------------------- | ---------------------------------- |
| File watching        | Polling loop with ls/stat | fswatch                      | Event-driven, uses native FSEvents |
| macOS notifications  | osascript wrapper         | terminal-notifier            | Has click actions, better API      |
| Message queuing      | Custom queue impl         | Existing comms/inbox pattern | Already built, tested              |
| Cross-pane messaging | Complex IPC               | tmux display-message         | Built into tmux, reliable          |
| Persistent popup     | Custom overlay            | tmux display-popup           | Native, handles terminal resize    |

**Key insight:** tmux 3.x has comprehensive notification primitives. File watching on macOS should use FSEvents via fswatch, not kqueue (file descriptor limits) or polling (resource waste).
</dont_hand_roll>

<common_pitfalls>

## Common Pitfalls

### Pitfall 1: display-popup Blocks Input

**What goes wrong:** User can't type in orchestrator pane while popup is visible
**Why it happens:** Popup is modal, captures all input
**How to avoid:** Use display-message for most notifications, popup only for urgent/blocking messages
**Warning signs:** Users complaining about workflow interruption

### Pitfall 2: fswatch Not Installed

**What goes wrong:** Prototype fails on fresh system
**Why it happens:** fswatch is not a macOS default, requires homebrew
**How to avoid:** Check for fswatch, provide fallback or clear install instructions
**Warning signs:** "command not found: fswatch"

### Pitfall 3: Signal Handling Kills Claude Code

**What goes wrong:** Sending SIGUSR1 to Claude Code PID terminates it
**Why it happens:** Claude Code doesn't trap SIGUSR1/2, default action is terminate
**How to avoid:** Don't send signals to Claude Code process directly - signal feature is proposed but not implemented
**Warning signs:** Claude Code exits unexpectedly

### Pitfall 4: File Descriptor Exhaustion with kqueue

**What goes wrong:** Watching many files causes errors
**Why it happens:** kqueue requires one FD per watched file
**How to avoid:** Use fswatch with FSEvents monitor (default on macOS)
**Warning signs:** "too many open files" errors

### Pitfall 5: Race Condition on Message Read

**What goes wrong:** Message displayed before fully written
**Why it happens:** fswatch fires on file creation, content may be incomplete
**How to avoid:** Wait briefly after creation event, or watch for close_write event
**Warning signs:** Truncated or empty message content
</common_pitfalls>

<code_examples>

## Code Examples

Verified patterns from research:

### File Watcher with fswatch

```bash
# Source: fswatch GitHub docs
# Watch directory for new .md files
fswatch -0 --event Created "$inbox_dir" | while read -d "" event; do
    if [[ "$event" == *.md ]]; then
        # Small delay to ensure file is fully written
        sleep 0.1
        notify::send "$event"
    fi
done
```

### tmux Display Message to Specific Pane

```bash
# Source: tmux man page
# Target syntax: session:window.pane
local win="nancy-${task}"
tmux display-message -t "${win}.0" "New message from worker"

# With format variables
tmux display-message -t "${win}.0" \
    "Message at #{t:window_activity}: $(basename "$file")"
```

### tmux Display Popup for Urgent Messages

```bash
# Source: tmux man page (v3.2+)
tmux display-popup \
    -t "${win}.0" \
    -w 70% -h 40% \
    -T "Worker Blocked" \
    -E "cat '$message_file'; echo; echo 'Press any key...'; read -n1"
```

### Claude Code Stop Hook for Notifications

```json
// Source: Claude Code hooks documentation
// ~/.claude/settings.json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "tmux display-message -t nancy-${TASK}.0 'Worker finished'"
          }
        ]
      }
    ]
  }
}
```

### Bash Signal Trap (for Logs Pane, not Claude)

```bash
# Source: bash trap documentation
# Trap SIGUSR1 in a bash script (NOT Claude Code)
handle_signal() {
    echo "Received notification signal"
    check_inbox
}
trap handle_signal SIGUSR1

# Send signal from another process
kill -SIGUSR1 $logs_pane_pid
```

</code_examples>

<sota_updates>

## State of the Art (2025-2026)

| Old Approach         | Current Approach      | When Changed    | Impact                                    |
| -------------------- | --------------------- | --------------- | ----------------------------------------- |
| inotifywait on macOS | fswatch with FSEvents | fswatch 1.0     | Native macOS support, no Linux dependency |
| tmux custom scripts  | tmux display-popup    | tmux 3.2 (2021) | Native floating windows                   |
| Manual polling       | fswatch event-driven  | Always          | Better performance, lower latency         |

**New tools/patterns to consider:**

- **tmux display-popup:** Native popup windows (3.2+), use for modal alerts
- **Claude Code hooks:** Can trigger notifications on Stop event, but no signal support yet
- **terminal-notifier:** Click actions can execute commands, including tmux navigation

**Deprecated/outdated:**

- **inotifywait on macOS:** Use fswatch instead
- **kqueue direct for large directories:** Use FSEvents via fswatch
- **SIGUSR1 to Claude Code:** Not implemented - feature request #11890 is open

**Claude Code Hooks Limitations:**

- No signal-triggered prompts (SIGUSR1/2 support is a feature request)
- Stop hook doesn't fire on user interrupt
- Notification hook has limited matchers
  </sota_updates>

<open_questions>

## Open Questions

Things that couldn't be fully resolved:

1. **Best UX for urgent vs non-urgent notifications**
   - What we know: display-message is non-blocking, display-popup is blocking
   - What's unclear: User preference for when to use each
   - Recommendation: Prototype both, let user configure via priority levels

2. **fswatch installation as dependency**
   - What we know: fswatch is not default on macOS, requires brew
   - What's unclear: Whether to make it required or provide fallback
   - Recommendation: Check availability, provide clear error message with install instructions

3. **Signal support in Claude Code**
   - What we know: Feature request #11890 proposes SIGUSR1/2 support
   - What's unclear: If/when this will be implemented
   - Recommendation: Design for current constraints, signal support can be added later
     </open_questions>

<sources>
## Sources

### Primary (HIGH confidence)

- tmux man page (v3.6a) - display-message, display-popup, alerts
- [fswatch GitHub](https://github.com/emcrisostomo/fswatch) - file watching on macOS
- [Claude Code hooks documentation](https://code.claude.com/docs/en/hooks) - Stop/Notification hooks

### Secondary (MEDIUM confidence)

- [tmux Advanced Use wiki](https://github.com/tmux/tmux/wiki/Advanced-Use) - alerts, notifications
- [Claude Code notification blog](https://quemy.info/2025-08-04-notification-system-tmux-claude.html) - full notification system implementation
- [Bash signal handling](https://linuxsimply.com/bash-scripting-tutorial/process-and-signal-handling/signals-handling/) - trap command

### Tertiary (LOW confidence - needs validation)

- [Claude Code signal feature request #11890](https://github.com/anthropics/claude-code/issues/11890) - SIGUSR1/2 proposal (not implemented)
  </sources>

<metadata>
## Metadata

**Research scope:**

- Core technology: tmux notification mechanisms
- Ecosystem: fswatch, terminal-notifier, bash signals
- Patterns: File watching, display-message, display-popup
- Pitfalls: Blocking popups, missing fswatch, signal termination

**Confidence breakdown:**

- Standard stack: HIGH - tmux is already required, fswatch well-documented
- Architecture: HIGH - patterns from official tmux docs
- Pitfalls: HIGH - verified through research
- Code examples: HIGH - from man pages and official docs

**Research date:** 2026-01-13
**Valid until:** 2026-02-13 (30 days - tmux ecosystem stable)
</metadata>

---

_Phase: 03-message-notification-prototypes_
_Research completed: 2026-01-13_
_Ready for planning: yes_
