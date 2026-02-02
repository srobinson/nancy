#!/usr/bin/env bash
# ----------------------------------------------
# Project/Issue/Workspace/Session Management
# ----------------------------------------------

# What do we have to play with

# We know the current PWD
PWD=/Users/alphab/Dev/LLM/DEV/md-tldr

# We have tmux session name
tmux new -s nancy_workspace_name
tmux rename-window new-name

# tmux new window
tmux new-window -n nancy_workspace_name

# ------------------------------------------------------------------------------

npx nancy

# how to detect if this is the first time this script is run
# look for .nancy directory

find_nancy_home() {
	if [ -n "$NANCY_HOME_DIR" ]; then
		echo "$NANCY_HOME_DIR"
		return
	fi
	local nancy_home=(
		"$PWD/.nancy"
		"$HOME/.nancy"
		"$XDG_CONFIG_HOME/nancy"
		"$XDG_DATA_HOME/nancy"
		"/var/lib/nancy"
	)
	for dir in "${nancy_home[@]}"; do
		if [ -d "$dir" ]; then
			echo "$dir"
			return
		fi
	done
}

NANCY_HOME_DIR=$(find_nancy_home)

if [ ! -d "$NANCY_HOME_DIR" ]; then
	echo "NANCY_HOME_DIR is set to a non-existent directory: $NANCY_HOME_DIR"
	read -p "Create it? (y/N): " choice
	if [[ "$choice" != "y" ]]; then
		# Go through onboarding
		npx nancy init
	else
		read -p "Do you want to use $PWD as your project root? (Y/n): " choice
		if [ -z "$choice" ] || [[ "$choice" =~ ^[Yy]$ ]]; then
			# Use current directory as project root
			echo "Using $PWD as project root."
			echo "If you prefer to use a global location for all your Nancy projects, set the NANCY_HOME_DIR environment variable in your shell configuration file."
			read -p "Press Enter to continue..."
			npx nancy init --yes
		else
			# Go through onboarding
			npx nancy init
		fi
	fi
fi
