#!/usr/bin/env bash
# b_path:: src/core/ui.sh
# UI components - gum wrappers
# ------------------------------------------------------------------------------

# Theme colors
export GUM_CONFIRM_SELECTED_FOREGROUND="212"
export GUM_CHOOSE_CURSOR_FOREGROUND="212"
export GUM_CHOOSE_SELECTED_FOREGROUND="212"
export GUM_INPUT_CURSOR_FOREGROUND="212"
export GUM_INPUT_PROMPT_FOREGROUND="99"
export GUM_FILTER_INDICATOR_FOREGROUND="212"
export GUM_FILTER_MATCH_FOREGROUND="212"

# ------------------------------------------------------------------------------
# UI Components
# ------------------------------------------------------------------------------

# Confirm yes/no
# Usage: ui::confirm "Question?" && do_something
ui::confirm() {
	local prompt="$1"
	gum confirm "$prompt"
}

# Single choice from list
# Usage: choice=$(ui::choose "Option1" "Option2" "Option3")
ui::choose() {
	gum choose --cursor "▸ " "$@"
}

# Single choice with header
# Usage: choice=$(ui::choose_with_header "Pick one:" "A" "B" "C")
ui::choose_with_header() {
	local header="$1"
	shift
	gum choose --cursor "▸ " --header "$header" "$@"
}

# Fuzzy filter from list (stdin or args)
# Usage: selected=$(echo -e "a\nb\nc" | ui::filter)
ui::filter() {
	local placeholder="${1:-Search...}"
	gum filter --placeholder "$placeholder" --indicator "▸ "
}

# Text input
# Usage: name=$(ui::input "Enter name")
ui::input() {
	local placeholder="$1"
	local default="${2:-}"
	if [[ -n "$default" ]]; then
		gum input --placeholder "$placeholder" --value "$default"
	else
		gum input --placeholder "$placeholder"
	fi
}

# Multi-line text input
# Usage: text=$(ui::write "Enter description")
ui::write() {
	local placeholder="${1:-}"
	gum write --placeholder "$placeholder"
}

# Spinner while running command
# Usage: ui::spin "Loading..." sleep 2
ui::spin() {
	local title="$1"
	shift
	gum spin --spinner dot --title "$title" -- "$@"
}

# Styled header
# Usage: ui::header "Welcome"
ui::header() {
	echo ""
	gum style --bold --foreground 212 "$*"
	echo ""
}

# Styled box
# Usage: ui::box "Content here"
ui::box() {
	gum style \
		--border rounded \
		--border-foreground 99 \
		--padding "0 1" \
		"$@"
}

# Styled banner
# Usage: ui::banner "Nancy" "Autonomous task execution"
ui::banner() {
	gum style \
		--border double \
		--border-foreground 212 \
		--align center \
		--padding "1 4" \
		--margin "1 0" \
		"$@"
}

# Dim/muted text
# Usage: ui::muted "Some note"
ui::muted() {
	gum style --foreground 240 "$*"
}

# Success message
# Usage: ui::success "Done!"
ui::success() {
	gum style --foreground 212 "✓ $*"
}

# Error message
# Usage: ui::error "Failed!"
ui::error() {
	gum style --foreground 196 "✗ $*"
}
