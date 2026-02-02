#!/usr/bin/env bash
# b_path:: src/notify/router.sh
# Notification router - routes messages to appropriate notification channels
# ------------------------------------------------------------------------------
#
# This is the main entry point for notifications. It examines message metadata
# and routes to the appropriate notification channels based on priority.
#
# Priority Levels:
#   urgent  → OS notification + sound + tmux popup (blocking)
#   normal  → OS notification + tmux status (all clients)
#   low     → tmux status only
#
# Functions:
#   notify::route <priority> <title> <message> [file]  - Route notification
#   notify::worker_message <task> <message_file>       - Process worker message
#
# ------------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# notify::_extract_metadata - Parse message file for metadata
# Args: file_path
# Sets global variables: _MSG_TYPE, _MSG_PRIORITY, _MSG_FROM, _MSG_CONTENT
# -----------------------------------------------------------------------------
notify::_extract_metadata() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        _MSG_TYPE="unknown"
        _MSG_PRIORITY="normal"
        _MSG_FROM="unknown"
        _MSG_CONTENT=""
        return 1
    fi

    # Extract headers (format: **Key:** value)
    _MSG_TYPE=$(grep -m1 '^\*\*Type:\*\*' "$file" 2>/dev/null | sed 's/.*\*\*Type:\*\*[[:space:]]*//' | tr -d '\r')
    _MSG_PRIORITY=$(grep -m1 '^\*\*Priority:\*\*' "$file" 2>/dev/null | sed 's/.*\*\*Priority:\*\*[[:space:]]*//' | tr -d '\r')
    _MSG_FROM=$(grep -m1 '^\*\*From:\*\*' "$file" 2>/dev/null | sed 's/.*\*\*From:\*\*[[:space:]]*//' | tr -d '\r')

    # Default priority if not specified
    _MSG_PRIORITY="${_MSG_PRIORITY:-normal}"
    _MSG_TYPE="${_MSG_TYPE:-message}"
    _MSG_FROM="${_MSG_FROM:-worker}"

    # Extract content (everything after the headers)
    # Skip lines starting with ** until we hit content
    _MSG_CONTENT=$(awk '
        /^\*\*[A-Za-z]+:\*\*/ { next }
        /^[[:space:]]*$/ && !started { next }
        { started=1; print }
    ' "$file" | head -c 500)

    # Trim whitespace
    _MSG_CONTENT=$(echo "$_MSG_CONTENT" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
}

# -----------------------------------------------------------------------------
# notify::_format_title - Format notification title based on message type
# Args: type, from
# Returns: formatted title string
# -----------------------------------------------------------------------------
notify::_format_title() {
    local type="$1"
    local from="${2:-worker}"

    case "$type" in
        blocker)
            echo "🚨 Blocker from $from"
            ;;
        progress)
            echo "📊 Progress Update"
            ;;
        review-request)
            echo "👀 Review Requested"
            ;;
        *)
            echo "📬 Message from $from"
            ;;
    esac
}

# -----------------------------------------------------------------------------
# notify::_format_icon - Get icon for message type
# Args: type
# Returns: emoji icon
# -----------------------------------------------------------------------------
notify::_format_icon() {
    local type="$1"

    case "$type" in
        blocker)        echo "🚨" ;;
        progress)       echo "📊" ;;
        review-request) echo "👀" ;;
        directive)      echo "📋" ;;
        guidance)       echo "💡" ;;
        stop)           echo "🛑" ;;
        *)              echo "📬" ;;
    esac
}

# -----------------------------------------------------------------------------
# notify::route - Route notification based on priority
# Args: priority, title, message, [file]
# Sends to appropriate channels based on priority level
# -----------------------------------------------------------------------------
notify::route() {
    local priority="$1"
    local title="$2"
    local message="$3"
    local file="${4:-}"

    case "$priority" in
        urgent)
            # Maximum visibility: OS notification with sound + popup
            notify::os_urgent "$title" "$message"
            if [[ -n "$file" ]]; then
                notify::popup "$title" "$file"
            else
                notify::popup "$title" "$message"
            fi
            ;;

        normal)
            # OS notification + brief popup
            notify::os "$title" "$message"
            notify::status_all "$title: $(echo "$message" | head -c 80)" 3
            ;;

        low)
            # Minimal: brief popup only
            notify::status_all "$title: $(echo "$message" | head -c 80)" 2
            ;;

        *)
            # Default to normal
            notify::os "$title" "$message"
            notify::status_all "$title: $(echo "$message" | head -c 80)" 3
            ;;
    esac
}

# -----------------------------------------------------------------------------
# notify::worker_message - Process and route a worker message file
# Args: task, message_file
# Main entry point called by the watcher
# -----------------------------------------------------------------------------
notify::worker_message() {
    local task="$1"
    local message_file="$2"

    if [[ -z "$task" || ! -f "$message_file" ]]; then
        return 1
    fi

    # Extract metadata from message
    notify::_extract_metadata "$message_file"

    # Format title and prepare notification
    local title
    title=$(notify::_format_title "$_MSG_TYPE" "$_MSG_FROM")

    # Create short preview for status line
    local preview
    preview=$(echo "$_MSG_CONTENT" | head -1 | head -c 60)
    [[ ${#_MSG_CONTENT} -gt 60 ]] && preview="${preview}..."

    # Blockers are always urgent
    local effective_priority="$_MSG_PRIORITY"
    [[ "$_MSG_TYPE" == "blocker" ]] && effective_priority="urgent"

    notify::route "$effective_priority" "$title" "$preview" "$message_file"
}

# -----------------------------------------------------------------------------
# notify::test - Test notification system
# Useful for verifying all channels work
# -----------------------------------------------------------------------------
notify::test() {
    local level="${1:-all}"

    echo "Testing notification system..."

    case "$level" in
        os)
            echo "Testing OS notification..."
            notify::os "Nancy Test" "This is a test notification"
            ;;
        sound)
            echo "Testing sound..."
            notify::os_sound "Glass"
            ;;
        status)
            echo "Testing tmux status..."
            notify::status_all "📬 Nancy test message" 3000
            ;;
        popup)
            echo "Testing popup..."
            notify::popup "Test Popup" "This is a test popup.\n\nIt should display and wait for a key press."
            ;;
        all)
            echo "1. OS notification..."
            notify::os "Nancy Test" "Testing OS notifications" "Test 1 of 4"
            sleep 1

            echo "2. Sound..."
            notify::os_sound "Glass"
            sleep 1

            echo "3. Status line..."
            notify::status_all "📬 Nancy test - status line" 5000
            sleep 1

            echo "4. Popup (press any key to dismiss)..."
            notify::popup "Test Complete" "All notification channels tested successfully!"
            ;;
    esac

    echo "Test complete."
}
