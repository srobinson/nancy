#!/usr/bin/env bash
# b_path:: src/cmd/notify-test.sh
# Test notification system
# ------------------------------------------------------------------------------

cmd::notify_test() {
    local test_type="${1:-all}"

    ui::header "🔔 Notification System Test"
    echo ""

    # Check capabilities
    echo "Checking notification capabilities..."
    local os_capability
    os_capability=$(notify::os_check)
    echo "  OS notifications: $os_capability"
    echo "  tmux: $(notify::tmux_check && echo "available" || echo "not in tmux")"
    echo "  fswatch: $(notify::check_fswatch 2>/dev/null && echo "available" || echo "not installed")"
    echo ""

    case "$test_type" in
        os)
            echo "Testing OS notification..."
            notify::os "Nancy Test" "This is a test notification from Nancy"
            ui::success "OS notification sent"
            ;;

        sound)
            echo "Testing sound..."
            notify::os_sound "Glass"
            ui::success "Sound played"
            ;;

        urgent)
            echo "Testing urgent notification (OS + sound)..."
            notify::os_urgent "Nancy Urgent" "This is an urgent test" "Urgent Test"
            ui::success "Urgent notification sent"
            ;;

        status)
            echo "Testing tmux status line (all clients)..."
            if notify::tmux_check; then
                notify::status_all "📬 Nancy test notification" 5000
                ui::success "Status message sent to all clients"
            else
                ui::error "Not in tmux session"
            fi
            ;;

        popup)
            echo "Testing tmux popup..."
            if notify::tmux_check; then
                notify::popup "Test Popup" "This is a test popup from Nancy.\n\nThe notification system is working correctly."
                ui::success "Popup displayed"
            else
                ui::error "Not in tmux session"
            fi
            ;;

        route-normal)
            echo "Testing normal priority routing..."
            notify::route "normal" "📊 Test Progress" "Worker completed step 1 of 5"
            ui::success "Normal notification routed"
            ;;

        route-urgent)
            echo "Testing urgent priority routing..."
            notify::route "urgent" "🚨 Test Blocker" "This is a test blocker message"
            ui::success "Urgent notification routed"
            ;;

        message)
            # Simulate exactly what the watcher does
            echo "Testing full message notification flow..."
            local test_file="/tmp/nancy-notify-test-$$.md"
            cat > "$test_file" << 'TESTMSG'
**Type:** progress
**From:** worker
**Priority:** normal

This is a test message simulating what a worker would send.
The notification system should process this and trigger alerts.
TESTMSG
            echo "Created test message: $test_file"
            echo ""
            echo "Calling notify::worker_message (same as watcher)..."
            notify::worker_message "test-task" "$test_file"
            local result=$?
            echo ""
            echo "notify::worker_message returned: $result"
            rm -f "$test_file"
            if [[ $result -eq 0 ]]; then
                ui::success "Message notification complete"
            else
                ui::error "Message notification failed"
            fi
            ;;

        all)
            echo "Running full notification test suite..."
            echo ""

            echo "1/5 OS notification..."
            notify::os "Nancy Test" "Test 1: Basic OS notification" "Step 1 of 5"
            sleep 1
            ui::success "  OS notification sent"

            echo "2/5 Sound..."
            notify::os_sound "Ping"
            sleep 0.5
            ui::success "  Sound played"

            echo "3/5 tmux status line..."
            if notify::tmux_check; then
                notify::status_all "📬 Nancy test (3/5)" 3000
                ui::success "  Status sent to all clients"
            else
                ui::muted "  Skipped (not in tmux)"
            fi
            sleep 1

            echo "4/5 Normal priority route..."
            notify::route "normal" "📊 Test Progress" "Normal priority test message"
            ui::success "  Normal route complete"
            sleep 1

            echo "5/5 Popup (press any key to dismiss)..."
            if notify::tmux_check; then
                notify::popup "Test Complete" "All notification channels tested!\n\n✓ OS notifications\n✓ Sound\n✓ tmux status\n✓ Priority routing\n✓ Popup"
                ui::success "  Popup dismissed"
            else
                ui::muted "  Skipped (not in tmux)"
            fi
            ;;

        *)
            echo "Usage: nancy notify-test [type]"
            echo ""
            echo "Types:"
            echo "  all          - Run full test suite (default)"
            echo "  os           - Test OS notification only"
            echo "  sound        - Test sound only"
            echo "  urgent       - Test urgent (OS + sound)"
            echo "  status       - Test tmux status line"
            echo "  popup        - Test tmux popup"
            echo "  route-normal - Test normal priority routing"
            echo "  route-urgent - Test urgent priority routing"
            echo "  message      - Test full message flow (simulates watcher)"
            return 1
            ;;
    esac

    echo ""
    ui::success "Test complete"
}
