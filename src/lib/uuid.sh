#!/usr/bin/env bash
# b_path:: src/lib/uuid.sh
# ------------------------------------------------------------------------------

# Generate a UUID
uuid::generate() {
	# Try uuidgen first (available on macOS and most Linux)
	if command -v uuidgen &>/dev/null; then
		uuidgen | tr '[:upper:]' '[:lower:]'
	# Fallback to /proc on Linux
	elif [[ -f /proc/sys/kernel/random/uuid ]]; then
		cat /proc/sys/kernel/random/uuid
	# Last resort: generate pseudo-UUID with bash
	else
		printf '%04x%04x-%04x-%04x-%04x-%04x%04x%04x' \
			$RANDOM $RANDOM $RANDOM \
			$((RANDOM & 0x0fff | 0x4000)) \
			$((RANDOM & 0x3fff | 0x8000)) \
			$RANDOM $RANDOM $RANDOM
	fi
}
