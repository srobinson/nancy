#!/usr/bin/env bash
# b_path:: src/notify/tmux.sh
# tmux notification primitives for Nancy
# ------------------------------------------------------------------------------
#
# Provides tmux-based notifications: status line messages and popups.
#
# Key insight: tmux display-message flags work as follows:
#   -c target-client  : WHERE the message appears (which client's status bar)
#   -t target-pane    : WHAT data is used for format variable expansion
#   -d delay          : How long the message stays visible (milliseconds)
#
# Functions:
#   notify::tmux_check                           - Verify tmux environment
#   notify::status <message> [delay_ms]          - Message to current client
#   notify::status_all <message> [delay_ms]      - Message to ALL clients
#   notify::popup <title> <content> [width] [height]  - Blocking popup overlay
#
# ------------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# notify::tmux_check - Verify we're in a tmux session
# Returns: 0 if in tmux, 1 otherwise
# -----------------------------------------------------------------------------
notify::tmux_check() {
    if [[ -z "${TMUX:-}" ]]; then
        return 1
    fi
    return 0
}

# -----------------------------------------------------------------------------
# notify::_get_clients - Get list of all tmux clients
# Returns: newline-separated list of client names
# -----------------------------------------------------------------------------
notify::_get_clients() {
    tmux list-clients -F "#{client_name}" 2>/dev/null
}

# -----------------------------------------------------------------------------
# notify::_get_session - Get current session name
# Returns: session name string
# -----------------------------------------------------------------------------
notify::_get_session() {
    tmux display-message -p '#{session_name}' 2>/dev/null
}

# -----------------------------------------------------------------------------
# notify::status - Display message in current client's status line
# Args: message, [delay_ms=5000]
# Non-blocking, auto-dismisses after delay
# -----------------------------------------------------------------------------
notify::status() {
    local message="$1"
    local delay_ms="${2:-5000}"

    notify::tmux_check || return 1

    tmux display-message -d "$delay_ms" "$message" 2>/dev/null
}

# -----------------------------------------------------------------------------
# notify::status_all - Display message to ALL connected clients
# Args: message, [delay_ms=5000]
# Ensures every terminal sees the notification
# -----------------------------------------------------------------------------
notify::status_all() {
    local message="$1"
    local delay_sec="${2:-3}"

    notify::tmux_check || return 1

    # tmux display-message to status line is unreliable across configurations
    # Use a brief auto-dismissing popup instead
    local tmux_version
    tmux_version=$(tmux -V | grep -oE '[0-9]+\.[0-9]+' | head -1)
    local major="${tmux_version%.*}"

    if [[ "$major" -ge 3 ]]; then
        # Use popup that auto-dismisses
        tmux display-popup -E -w 60% -h 6 "echo ''; echo '  $message'; echo ''; sleep $delay_sec" &
    fi
}

# -----------------------------------------------------------------------------
# notify::popup - Display blocking popup overlay
# Args: title, content (string or file path), [width=60%], [height=40%]
# Blocks until user presses a key
# For urgent notifications that require acknowledgment
# -----------------------------------------------------------------------------
notify::popup() {
    local title="$1"
    local content="$2"
    local width="${3:-60%}"
    local height="${4:-40%}"

    notify::tmux_check || return 1

    # Check tmux version supports popups (3.2+)
    local tmux_version
    tmux_version=$(tmux -V | grep -oE '[0-9]+\.[0-9]+' | head -1)
    local major minor
    major="${tmux_version%.*}"
    minor="${tmux_version#*.}"

    if [[ "$major" -lt 3 ]] || { [[ "$major" -eq 3 ]] && [[ "$minor" -lt 2 ]]; }; then
        # Fallback to status message for older tmux
        notify::status_all "⚠️  $title: $content" 10000
        return 1
    fi

    # Determine if content is a file or string
    local display_cmd
    if [[ -f "$content" ]]; then
        display_cmd="cat '$content'; echo ''; echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'; echo 'Press any key to dismiss...'; read -rsn1"
    else
        # Use printf to interpret escape sequences like \n
        display_cmd="printf '%b\n' '$content'; echo ''; echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'; echo 'Press any key to dismiss...'; read -rsn1"
    fi

    tmux display-popup \
        -T " $title " \
        -w "$width" \
        -h "$height" \
        -E "bash -c \"$display_cmd\"" 2>/dev/null
}

# -----------------------------------------------------------------------------
# notify::popup_nonblocking - Display popup that auto-dismisses
# Args: title, content, [timeout_sec=5], [width=50%], [height=30%]
# Shows briefly then closes automatically
# -----------------------------------------------------------------------------
notify::popup_brief() {
    local title="$1"
    local content="$2"
    local timeout="${3:-5}"
    local width="${4:-50%}"
    local height="${5:-30%}"

    notify::tmux_check || return 1

    # Check tmux version
    local tmux_version
    tmux_version=$(tmux -V | grep -oE '[0-9]+\.[0-9]+' | head -1)
    local major="${tmux_version%.*}"

    if [[ "$major" -lt 3 ]]; then
        notify::status_all "$title: $content" 5000
        return 1
    fi

    local display_cmd
    if [[ -f "$content" ]]; then
        display_cmd="cat '$content'; sleep $timeout"
    else
        display_cmd="printf '%b\n' '$content'; sleep $timeout"
    fi

    # Run in background so it doesn't block
    tmux display-popup \
        -T " $title " \
        -w "$width" \
        -h "$height" \
        -E "bash -c \"$display_cmd\"" 2>/dev/null &
}

# -----------------------------------------------------------------------------
# notify::window_flag - Set visual flag on a window (activity indicator)
# Args: session:window target
# Creates a visual indicator in tmux window list
# -----------------------------------------------------------------------------
notify::window_flag() {
    local target="$1"

    notify::tmux_check || return 1

    # Send a bell to trigger the window flag
    # This requires monitor-bell to be on
    tmux send-keys -t "$target" "$(printf '\a')" 2>/dev/null
}
