#!/usr/bin/env bash
# b_path:: src/cmd/setup.sh
# First-time setup wizard
# ------------------------------------------------------------------------------

# Nancy's built-in defaults per CLI
# Claude CLI: sonnet, haiku, opus
# Copilot: claude-sonnet-4, gpt-4o, etc.
declare -A NANCY_DEFAULTS_MODEL=(
	[copilot]="claude-opus-4"
	[claude]="opus"
	[opencode]="opus"
	[gemini]="gemini-3.0-flash"
)

declare -A NANCY_DEFAULTS_THRESHOLD=(
	[copilot]="0.30"
	[claude]="0.30"
	[opencode]="0.30"
	[gemini]="0.30"
)

cmd::setup() {
	ui::banner "🤖 Nancy Setup"

	# Check deps first
	if ! deps::check_required; then
		return 1
	fi

	# Check for existing setup
	if [[ -d "$NANCY_DIR" ]]; then
		ui::muted "Nancy is already initialized in this directory."
		if ! ui::confirm "Reconfigure?"; then
			return 0
		fi
	fi

	# Detect available CLIs
	local available_clis=()
	for cli in "${DEPS_CLI[@]}"; do
		if deps::exists "$cli"; then
			available_clis+=("$cli")
		fi
	done

	if [[ ${#available_clis[@]} -eq 0 ]]; then
		log::error "No AI CLI found."
		echo ""
		echo "Install one of:"
		echo "  - GitHub Copilot CLI: npm install -g @githubnext/github-copilot-cli"
		echo "  - Claude Code: https://claude.ai/code"
		return 1
	fi

	# Select CLI
	local selected_cli
	if [[ ${#available_clis[@]} -eq 1 ]]; then
		selected_cli="${available_clis[0]}"
		ui::success "Using $selected_cli"
	else
		selected_cli=$(ui::choose_with_header "Select AI CLI:" "${available_clis[@]}")
	fi

	# Get defaults for selected CLI
	local default_model="${NANCY_DEFAULTS_MODEL[$selected_cli]:-claude-sonnet-4}"
	local default_threshold="${NANCY_DEFAULTS_THRESHOLD[$selected_cli]:-0.20}"

	# Create .nancy directory
	mkdir -p "$NANCY_TASK_DIR"

	# Create config with defaults
	cat >"$NANCY_CONFIG_FILE" <<EOF
{
  "version": "2.0",
  "cli": "${selected_cli}",
  "model": "${default_model}",
  "token_threshold": ${default_threshold},
  "git": {
    "auto_commit": true
  }
}
EOF

	echo ""
	ui::success "Initialized: ${NANCY_DIR}"
	echo ""
	ui::muted "Defaults (edit ${NANCY_CONFIG_FILE} to change):"
	ui::muted "  CLI: ${selected_cli}"
	ui::muted "  Model: ${default_model}"
	ui::muted "  Token threshold: ${default_threshold}"
}
