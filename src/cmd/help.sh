#!/usr/bin/env bash
# b_path:: src/cmd/help.sh
# Help and version commands
# ------------------------------------------------------------------------------

cmd::help() {
	cat <<EOF
Nancy - Autonomous task execution framework

Usage: nancy [command] [options]

Commands:
  (default)       Interactive task menu
  setup           First-time setup wizard
  init <name>     Create a new task
  start <name>    Start task execution loop
  pause <name>    Pause a running task
  unpause <name>  Resume a paused task
  status          Show project status
  doctor          Check environment
  help            Show this help

Examples:
  nancy                    # Interactive menu
  nancy setup              # Initialize nancy
  nancy init my-feature    # Create task
  nancy start my-feature   # Run task loop

Version: ${NANCY_VERSION}
EOF
}

cmd::version() {
	echo "nancy ${NANCY_VERSION}"
}
