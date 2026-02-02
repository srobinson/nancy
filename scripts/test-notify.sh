#!/usr/bin/env bash
# b_path:: scripts/test-notify.sh
# Test notification system end-to-end
# Run from project root: ./scripts/test-notify.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source Nancy
source "$PROJECT_ROOT/nancy"

echo "=== Notification System Test ==="
echo ""

# Test 1: Check fswatch
echo "1. Checking fswatch..."
if notify::check_fswatch; then
    echo "   ✓ fswatch available"
else
    echo "   ✗ fswatch NOT available"
    echo "   Install with: brew install fswatch"
    exit 1
fi

# Test 2: Check tmux
echo "2. Checking tmux environment..."
if [[ -n "${TMUX:-}" ]]; then
    echo "   ✓ Running in tmux"
else
    echo "   ✗ NOT in tmux (some tests will be skipped)"
fi

# Test 3: Test notify functions exist
echo "3. Checking notify functions..."
for fn in notify::message notify::popup notify::bell notify::worker_message notify::watch_inbox; do
    if type "$fn" &>/dev/null; then
        echo "   ✓ $fn"
    else
        echo "   ✗ $fn NOT found"
        exit 1
    fi
done

# Test 4: Create test message and verify reading
echo "4. Testing message file handling..."
TEST_DIR=$(mktemp -d)
TEST_MSG="$TEST_DIR/20260113T120000Z-001.md"
cat > "$TEST_MSG" << 'EOF'
# Message

**Type:** progress
**From:** worker
**Priority:** normal
**Time:** 2026-01-13T12:00:00Z

## Content

Test message for notification system.
EOF

if [[ -f "$TEST_MSG" ]]; then
    echo "   ✓ Test message created"
    TYPE=$(grep "^\*\*Type:\*\*" "$TEST_MSG" | sed 's/.*\*\* //')
    echo "   ✓ Extracted type: $TYPE"
else
    echo "   ✗ Failed to create test message"
    exit 1
fi

# Cleanup
rm -rf "$TEST_DIR"

echo ""
echo "=== All tests passed ==="
echo ""
echo "To test live notification:"
echo "1. Start orchestration: nancy orchestrate <task>"
echo "2. In worker pane, run: /send-message"
echo "3. Watch for notification in orchestrator pane"
