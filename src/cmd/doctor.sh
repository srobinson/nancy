#!/usr/bin/env bash
# b_path:: src/cmd/doctor.sh
# ------------------------------------------------------------------------------
# Environment diagnostics

cmd::doctor() {
	ui::header "🩺 Nancy Doctor"

	local issues=0
	local cli_found=0
	local version

	# Required deps
	echo "Required dependencies:"
	for dep in "${DEPS_REQUIRED[@]}"; do
		if deps::exists "$dep"; then
			ui::success "$dep"
		else
			ui::error "$dep - NOT FOUND"
			issues=$((issues + 1))
		fi
	done
	echo ""

	# CLI tools
	echo "AI CLI tools:"
	for cli in "${DEPS_CLI[@]}"; do
		if deps::exists "$cli"; then
			version="?"
			if declare -f "cli::${cli}::version" >/dev/null 2>&1; then
				version=$("cli::${cli}::version" 2>/dev/null || echo "?")
			fi
			ui::success "$cli ($version)"
			cli_found=$((cli_found + 1))
		else
			ui::muted "$cli - not installed"
		fi
	done

	if [[ $cli_found -eq 0 ]]; then
		ui::error "No AI CLI found!"
		issues=$((issues + 1))
	fi
	echo ""

	# Project status
	echo "Project:"
	if [[ -d "$NANCY_DIR" ]]; then
		ui::success "Initialized: $NANCY_DIR"
		local task_count
		task_count=$(task::count)
		echo "  Tasks: $task_count"
	else
		ui::muted "Not initialized"
	fi
	echo ""

	# Summary
	if [[ $issues -eq 0 ]]; then
		ui::success "All checks passed!"
	else
		ui::error "$issues issue(s) found"
		return 1
	fi
}
