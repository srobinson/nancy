#!/usr/bin/env bash
# b_path:: src/notify/index.sh
# Notification module loader
# ------------------------------------------------------------------------------
#
# Provides a layered notification system for Nancy orchestration.
#
# Architecture:
#   ┌─────────────────────────────────────┐
#   │  watcher.sh - fswatch integration   │
#   │  Detects messages, triggers notify  │
#   └─────────────┬───────────────────────┘
#                 │
#   ┌─────────────┴───────────────────────┐
#   │  router.sh - Priority-based routing │
#   │  notify::worker_message()           │
#   └─────────────┬───────────────────────┘
#                 │
#   ┌─────────────┴───────────────────────┐
#   │         Primitives Layer            │
#   ├─────────────────────────────────────┤
#   │  os.sh     - macOS notifications    │
#   │  tmux.sh   - tmux popups            │
#   │  inject.sh - CLI prompt injection   │
#   │              (Claude Code specific) │
#   └─────────────────────────────────────┘
#
# Usage:
#   # Test all notification channels
#   notify::test all
#
#   # Process a worker message (called by watcher)
#   notify::worker_message "$task" "$message_file"
#
# ------------------------------------------------------------------------------

# Load primitives first (no dependencies on each other)
. "$NANCY_FRAMEWORK_ROOT/src/notify/os.sh"
. "$NANCY_FRAMEWORK_ROOT/src/notify/tmux.sh"
. "$NANCY_FRAMEWORK_ROOT/src/notify/inject.sh"

# Load router (depends on primitives)
. "$NANCY_FRAMEWORK_ROOT/src/notify/router.sh"

# Load watcher (depends on router + inject)
. "$NANCY_FRAMEWORK_ROOT/src/notify/watcher.sh"
