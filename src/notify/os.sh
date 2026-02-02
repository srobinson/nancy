#!/usr/bin/env bash
# b_path:: src/notify/os.sh
# OS-level notifications (macOS implementation)
# ------------------------------------------------------------------------------
#
# Provides native OS notifications that appear in Notification Center.
# These are visible even when the terminal is not focused.
#
# Functions:
#   notify::os <title> <message> [subtitle]     - Basic notification
#   notify::os_sound <sound_name>               - Play system sound
#   notify::os_urgent <title> <message>         - Notification with sound
#   notify::os_with_click <title> <message> <command>  - Clickable (requires terminal-notifier)
#
# Platform: macOS 10.10+
# ------------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Platform Detection
# -----------------------------------------------------------------------------

notify::_is_macos() {
    [[ "$(uname -s)" == "Darwin" ]]
}

notify::_has_terminal_notifier() {
    command -v terminal-notifier &>/dev/null
}

# -----------------------------------------------------------------------------
# notify::os - Send basic OS notification
# Args: title, message, [subtitle]
# Uses osascript (built-in, no dependencies)
# -----------------------------------------------------------------------------
notify::os() {
    local title="$1"
    local message="$2"
    local subtitle="${3:-}"

    if ! notify::_is_macos; then
        return 1
    fi

    # terminal-notifier works reliably on macOS Sequoia
    # osascript display notification is broken from Terminal contexts
    if notify::_has_terminal_notifier; then
        local args=(-title "$title" -message "$message")
        [[ -n "$subtitle" ]] && args+=(-subtitle "$subtitle")
        terminal-notifier "${args[@]}" 2>/dev/null
        return $?
    fi

    # Fallback: display alert (modal dialog) - always works but blocks
    # Only use for urgent notifications
    return 1
}

# -----------------------------------------------------------------------------
# notify::os_sound - Play a system sound
# Args: sound_name (default: "default")
# Sound files are in /System/Library/Sounds/
# Common: Basso, Blow, Bottle, Frog, Funk, Glass, Hero, Morse, Ping, Pop,
#         Purr, Sosumi, Submarine, Tink
# -----------------------------------------------------------------------------
notify::os_sound() {
    local sound="${1:-default}"

    if ! notify::_is_macos; then
        return 1
    fi

    if [[ "$sound" == "default" ]]; then
        # Use afplay with a common alert sound
        afplay /System/Library/Sounds/Ping.aiff 2>/dev/null &
    else
        local sound_file="/System/Library/Sounds/${sound}.aiff"
        if [[ -f "$sound_file" ]]; then
            afplay "$sound_file" 2>/dev/null &
        else
            # Fallback to default
            afplay /System/Library/Sounds/Ping.aiff 2>/dev/null &
        fi
    fi
}

# -----------------------------------------------------------------------------
# notify::os_urgent - Notification with sound
# Args: title, message, [subtitle], [sound]
# Combines visual notification with audio alert
# -----------------------------------------------------------------------------
notify::os_urgent() {
    local title="$1"
    local message="$2"
    local subtitle="${3:-}"
    local sound="${4:-Glass}"

    notify::os "$title" "$message" "$subtitle"
    notify::os_sound "$sound"
}

# -----------------------------------------------------------------------------
# notify::os_with_click - Notification with click action
# Args: title, message, command_to_run
# Requires: terminal-notifier (brew install terminal-notifier)
# Falls back to basic notification if not available
# -----------------------------------------------------------------------------
notify::os_with_click() {
    local title="$1"
    local message="$2"
    local command="$3"
    local subtitle="${4:-}"
    local sound="${5:-default}"

    if ! notify::_is_macos; then
        log::debug "OS notifications not supported on this platform"
        return 1
    fi

    if notify::_has_terminal_notifier; then
        local args=(
            -title "$title"
            -message "$message"
        )
        [[ -n "$subtitle" ]] && args+=(-subtitle "$subtitle")
        [[ -n "$command" ]] && args+=(-execute "$command")
        [[ "$sound" != "none" ]] && args+=(-sound "$sound")

        terminal-notifier "${args[@]}" 2>/dev/null
    else
        # Fallback to basic notification
        notify::os "$title" "$message" "$subtitle"
        [[ "$sound" != "none" ]] && notify::os_sound "$sound"
    fi
}

# -----------------------------------------------------------------------------
# notify::os_check - Verify OS notification capability
# Returns: 0 if notifications are available, 1 otherwise
# Useful for graceful degradation
# -----------------------------------------------------------------------------
notify::os_check() {
    if ! notify::_is_macos; then
        echo "not-macos"
        return 1
    fi

    if notify::_has_terminal_notifier; then
        echo "terminal-notifier"
        return 0
    fi

    # osascript is always available on macOS
    echo "osascript"
    return 0
}
