#!/usr/bin/env bash
# b_path:: src/cmd/setup.sh
# First-time setup wizard
# ------------------------------------------------------------------------------

# Nancy's built-in defaults per CLI
# Claude CLI: sonnet, haiku, opus
declare -A NANCY_DEFAULTS_MODEL=(
	[claude]="opus"
	[codex]="gpt-5.4"
)

declare -A NANCY_DEFAULTS_THRESHOLD=(
	[claude]="0.30"
	[codex]="0.30"
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
		echo "  - Claude Code: https://claude.ai/code"
		echo "  - Codex CLI: ensure 'codex' is installed and on PATH"
		return 1
	fi

	# Select worker CLI
	local selected_cli
	if [[ ${#available_clis[@]} -eq 1 ]]; then
		selected_cli="${available_clis[0]}"
		ui::success "Using $selected_cli for worker and reviewer"
	else
		selected_cli=$(ui::choose_with_header "Select worker AI CLI:" "${available_clis[@]}")
	fi

	local reviewer_cli="$selected_cli"
	if [[ ${#available_clis[@]} -gt 1 ]]; then
		reviewer_cli=$(ui::choose_with_header "Select reviewer AI CLI:" "${available_clis[@]}")
	fi

	# Get defaults for selected CLI
	local default_model="${NANCY_DEFAULTS_MODEL[$selected_cli]:-opus}"
	local reviewer_default_model="${NANCY_DEFAULTS_MODEL[$reviewer_cli]:-opus}"
	local default_threshold="${NANCY_DEFAULTS_THRESHOLD[$selected_cli]:-0.20}"

	local worker_model
	local reviewer_model
	worker_model=$(ui::input "Worker model" "$default_model")
	reviewer_model=$(ui::input "Reviewer model" "$reviewer_default_model")
	worker_model="${worker_model:-$default_model}"
	reviewer_model="${reviewer_model:-$reviewer_default_model}"

	# Create .nancy directory
	mkdir -p "$NANCY_TASK_DIR"

	# Create config with defaults
	cat >"$NANCY_CONFIG_FILE" <<EOF
{
  "version": "2.1",
  "cli": "${selected_cli}",
  "model": "${worker_model}",
  "token_threshold": ${default_threshold},
  "agents": {
    "worker": {
      "cli": "${selected_cli}",
      "model": "${worker_model}"
    },
    "reviewer": {
      "cli": "${reviewer_cli}",
      "model": "${reviewer_model}"
    }
  },
  "git": {
    "auto_commit": true
  }
}
EOF

	echo ""
	ui::success "Initialized: ${NANCY_DIR}"
	echo ""
	ui::muted "Defaults (edit ${NANCY_CONFIG_FILE} to change):"
	ui::muted "  Worker CLI: ${selected_cli}"
	ui::muted "  Worker model: ${worker_model}"
	ui::muted "  Reviewer CLI: ${reviewer_cli}"
	ui::muted "  Reviewer model: ${reviewer_model}"
	ui::muted "  Token threshold: ${default_threshold}"
}
