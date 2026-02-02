#!/bin/bash

# Generic token monitoring script for worker agents
# Usage: monitor-tokens.sh <TASK_ID> [CHECK_INTERVAL] [PROJECT_DIR]
#
# Arguments:
#   TASK_ID         - Required. The task ID to monitor (e.g., ALP-139)
#   CHECK_INTERVAL  - Optional. Check interval in seconds (default: 30)
#   PROJECT_DIR     - Optional. Project directory path (default: current directory)
#
# Behavior:
#   - Checks token usage every CHECK_INTERVAL seconds
#   - At 50%: Sends guidance warning, then sleeps 8 minutes
#   - At 60%: Sends directive to wind down
#   - At 100%+: Sends stop directive and exits

set -euo pipefail

# Validate arguments
if [ $# -lt 1 ]; then
	echo "❌ Error: Task ID required"
	echo "Usage: $0 <TASK_ID> [CHECK_INTERVAL] [PROJECT_DIR]"
	echo "Example: $0 ALP-139 30"
	echo "Example: $0 ALP-139 30 /path/to/project"
	exit 1
fi

TASK_ID="$1"
CHECK_INTERVAL="${2:-30}"
PROJECT_DIR="${3:-.}"

# Change to project directory
cd "$PROJECT_DIR" || {
	echo "❌ Error: Cannot access project directory: $PROJECT_DIR"
	exit 1
}

# Validate we're in a nancy project
if [ ! -d ".nancy" ]; then
	echo "❌ Error: Not a nancy project directory (no .nancy/ folder found)"
	echo "Current directory: $(pwd)"
	exit 1
fi

echo "📁 Project directory: $(pwd)"

NOTIFIED_50=false
NOTIFIED_60=false

echo "🔍 Starting token monitor for task $TASK_ID"
echo "Checking every ${CHECK_INTERVAL}s..."

while true; do
	# Get token usage
	TOKEN_FILE=".nancy/tasks/$TASK_ID/token-usage.json"

	if [ -f "$TOKEN_FILE" ]; then
		PERCENT=$(jq -r '.percent' "$TOKEN_FILE")

		echo "[$(date '+%H:%M:%S')] Token usage: ${PERCENT}%"

		# Check 60% threshold (must wind down)
		if (($(echo "$PERCENT >= 60" | bc -l))) && [ "$NOTIFIED_60" = false ]; then
			echo "⚠️  60% threshold reached - sending wind down directive"
			nancy direct "$TASK_ID" "CRITICAL: Token budget at ${PERCENT}%. You MUST start winding down your work now. Complete current task and prepare to stop." --type directive
			NOTIFIED_60=true
		# Check 50% threshold (warning)
		elif (($(echo "$PERCENT >= 50" | bc -l))) && [ "$NOTIFIED_50" = false ]; then
			echo "⚠️  50% threshold reached - sending warning"
			nancy direct "$TASK_ID" "WARNING: Token budget at ${PERCENT}%. You're at 50% or more - be mindful of remaining budget. At 60% you must wind down." --type guidance
			NOTIFIED_50=true
			echo "Sleeping for 2 minutes after 50% notification..."
			sleep 120
		fi

		# If over 100%, send stop directive
		if (($(echo "$PERCENT >= 100" | bc -l))); then
			echo "🛑 Over budget! Sending stop directive"
			nancy direct "$TASK_ID" "STOP: Token budget exceeded (${PERCENT}%). Stop work immediately and report progress." --type stop
			echo "Monitor stopping - budget exceeded"
			exit 1
		fi
	else
		echo "[$(date '+%H:%M:%S')] Waiting for token usage file..."
	fi

	sleep "$CHECK_INTERVAL"
done
