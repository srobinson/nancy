#!/usr/bin/env bash
# b_path:: src/cmd/experiment.sh
# Run a reproducible A/B experiment from a GitHub issue URL
# ------------------------------------------------------------------------------
#
# Usage: nancy experiment <github-issue-url>
#
# Process:
#   1. Parse GitHub URL → owner/repo + issue number
#   2. Fetch issue title + description via gh CLI
#   3. Clone repo (if not already local)
#   4. Create two experiment conditions:
#      A (baseline): no fmm, no sidecar instructions in prompt
#      B (treatment): fmm sidecars generated, sidecar instructions in prompt
#   5. Run single-iteration worker on each condition
#   6. Analyze logs and output comparison table
# ------------------------------------------------------------------------------

_experiment_parse_url() {
	local url="$1"
	local -n _parsed=$2

	# Extract owner/repo/issue from GitHub URL
	# Supports: https://github.com/owner/repo/issues/123
	if [[ "$url" =~ github\.com/([^/]+)/([^/]+)/issues/([0-9]+) ]]; then
		_parsed[owner]="${BASH_REMATCH[1]}"
		_parsed[repo]="${BASH_REMATCH[2]}"
		_parsed[issue]="${BASH_REMATCH[3]}"
		_parsed[slug]="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
		return 0
	fi

	log::error "Invalid GitHub issue URL: $url"
	log::error "Expected: https://github.com/owner/repo/issues/123"
	return 1
}

_experiment_fetch_issue() {
	local slug="$1"
	local issue_num="$2"
	local -n _issue=$3

	log::info "Fetching issue ${slug}#${issue_num}..."

	local json
	json=$(gh issue view "$issue_num" --repo "$slug" --json title,body 2>&1) || {
		log::error "Failed to fetch issue: $json"
		return 1
	}

	_issue[title]=$(echo "$json" | jq -r '.title')
	_issue[body]=$(echo "$json" | jq -r '.body')
}

_experiment_setup_repo() {
	local slug="$1"
	local exp_dir="$2"
	local condition="$3" # A or B

	local repo_dir="${exp_dir}/${condition}"

	if [[ -d "$repo_dir" ]]; then
		log::info "Repo already exists at $repo_dir — reusing"
		return 0
	fi

	log::info "Cloning $slug → $repo_dir"
	gh repo clone "$slug" "$repo_dir" -- --depth 1 2>&1 || {
		log::error "Failed to clone $slug"
		return 1
	}
}

_experiment_generate_fmm() {
	local repo_dir="$1"

	if ! command -v fmm &>/dev/null; then
		log::warn "fmm not found in PATH — skipping sidecar generation"
		return 1
	fi

	log::info "Generating fmm sidecars in $repo_dir..."
	(cd "$repo_dir" && fmm generate 2>&1) || {
		log::warn "fmm generate failed"
		return 1
	}

	local count
	count=$(find "$repo_dir" -name "*.fmm" | wc -l | tr -d ' ')
	log::info "Generated $count sidecar files"
}

_experiment_render_prompt() {
	local template_file="$1"
	local task_dir="$2"
	local task_name="$3"
	local issue_title="$4"
	local issue_body="$5"
	local repo_dir="$6"

	local prompt
	prompt=$(cat "$template_file")

	# Substitute standard Nancy variables
	prompt="${prompt//\{\{NANCY_PROJECT_ROOT\}\}/$repo_dir}"
	prompt="${prompt//\{\{NANCY_CURRENT_TASK_DIR\}\}/$task_dir}"
	prompt="${prompt//\{\{SESSION_ID\}\}/experiment-${task_name}}"
	prompt="${prompt//\{\{TASK_NAME\}\}/$task_name}"
	prompt="${prompt//\{\{PROJECT_IDENTIFIER\}\}/$task_name}"
	prompt="${prompt//\{\{PROJECT_TITLE\}\}/$issue_title}"
	prompt="${prompt//\{\{WORKTREE_DIR\}\}/$repo_dir}"

	# Inject issue description as PROJECT_DESCRIPTION
	prompt="${prompt//\{\{PROJECT_DESCRIPTION\}\}/$issue_body}"

	echo "$prompt"
}

_experiment_run_condition() {
	local condition="$1"    # A or B
	local exp_dir="$2"
	local task_name="$3"
	local issue_title="$4"
	local issue_body="$5"
	local template_file="$6"

	local repo_dir="${exp_dir}/${condition}"
	local task_dir="${exp_dir}/results/${condition}"

	mkdir -p "${task_dir}/logs"
	mkdir -p "${task_dir}/sessions"

	ui::header "Running condition ${condition}"
	log::info "Repo: $repo_dir"
	log::info "Template: $(basename "$template_file")"
	log::info "Logs: ${task_dir}/logs/"

	# Render prompt
	local prompt
	prompt=$(_experiment_render_prompt \
		"$template_file" \
		"$task_dir" \
		"$task_name" \
		"$issue_title" \
		"$issue_body" \
		"$repo_dir")

	# Save rendered prompt
	echo "$prompt" > "${task_dir}/PROMPT.md"

	# Create ISSUES.md (single issue)
	cat > "${task_dir}/ISSUES.md" <<-ISSUESEOF
	# Experiment: ${task_name} — Condition ${condition}

	     ISSUE_ID  Title                  Priority  State
	[ ]  EXP-${condition}    ${issue_title}   High      Todo
	ISSUESEOF

	local session_id="experiment-${task_name}-${condition}-iter1"
	local session_file="${task_dir}/sessions/${session_id}.md"

	# Run worker (single iteration)
	log::info "Starting worker..."
	local exit_code=0

	(
		cd "$repo_dir" || exit 1
		export NANCY_CURRENT_TASK_DIR="$task_dir"
		export NANCY_PROJECT_ROOT="$repo_dir"
		export NANCY_EXECUTION_MODE="single-run"

		cli::run_prompt "$prompt" "$session_id" "$session_file" "$task_dir"
	) || exit_code=$?

	if [[ $exit_code -eq 0 ]]; then
		ui::success "Condition ${condition} completed"
	else
		log::warn "Condition ${condition} exited with code $exit_code"
	fi

	return 0
}

cmd::experiment() {
	local url="${1:-}"

	if [[ -z "$url" ]]; then
		log::error "Usage: nancy experiment <github-issue-url>"
		return 1
	fi

	config::load

	# 1. Parse URL
	declare -A parsed
	_experiment_parse_url "$url" parsed || return 1

	local slug="${parsed[slug]}"
	local issue_num="${parsed[issue]}"
	local repo_name="${parsed[repo]}"

	# 2. Fetch issue
	declare -A issue
	_experiment_fetch_issue "$slug" "$issue_num" issue || return 1

	ui::header "Experiment: ${slug}#${issue_num}"
	log::info "Issue: ${issue[title]}"

	# 3. Setup experiment directory
	local task_name="EXP-${repo_name}-${issue_num}"
	local exp_dir="${NANCY_TASK_DIR}/${task_name}"

	mkdir -p "$exp_dir/results"

	# Save experiment metadata
	cat > "${exp_dir}/experiment.json" <<-METAEOF
	{
	  "url": "$url",
	  "slug": "$slug",
	  "issue": $issue_num,
	  "title": $(echo "${issue[title]}" | jq -Rs .),
	  "created": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
	  "conditions": {
	    "A": {"label": "baseline", "template": "PROMPT.baseline.md.template", "fmm": false},
	    "B": {"label": "treatment", "template": "PROMPT.md.template", "fmm": true}
	  }
	}
	METAEOF

	# 4. Clone repo for both conditions
	_experiment_setup_repo "$slug" "$exp_dir" "A" || return 1
	_experiment_setup_repo "$slug" "$exp_dir" "B" || return 1

	# 5. Generate fmm sidecars for condition B only
	_experiment_generate_fmm "${exp_dir}/B"

	# 6. Templates
	local baseline_template="${NANCY_FRAMEWORK_ROOT}/templates/PROMPT.baseline.md.template"
	local treatment_template="${NANCY_FRAMEWORK_ROOT}/templates/PROMPT.md.template"

	if [[ ! -f "$baseline_template" ]]; then
		log::error "Baseline template not found: $baseline_template"
		log::error "Run: git show <commit-before-sidecar-section>:templates/PROMPT.md.template > templates/PROMPT.baseline.md.template"
		return 1
	fi

	# 7. Run conditions sequentially
	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "  CONDITION A: Baseline (no fmm, no sidecar instructions)"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""

	_experiment_run_condition "A" "$exp_dir" "$task_name" \
		"${issue[title]}" "${issue[body]}" "$baseline_template"

	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "  CONDITION B: Treatment (fmm + sidecar instructions)"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""

	_experiment_run_condition "B" "$exp_dir" "$task_name" \
		"${issue[title]}" "${issue[body]}" "$treatment_template"

	# 8. Analyze
	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "  ANALYSIS"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""

	local control_logs="${exp_dir}/results/A/logs"
	local treatment_logs="${exp_dir}/results/B/logs"

	if [[ -d "$control_logs" ]] && [[ -d "$treatment_logs" ]]; then
		python3 -m src.analyze "$control_logs" "$treatment_logs" 2>&1 | tee "${exp_dir}/results/comparison.txt"
		python3 -m src.analyze "$control_logs" "$treatment_logs" --json > "${exp_dir}/results/comparison.json" 2>/dev/null

		echo ""
		ui::success "Results saved to: ${exp_dir}/results/"
		ui::muted "  comparison.txt  — human-readable table"
		ui::muted "  comparison.json — machine-readable data"
		ui::muted "  A/logs/         — baseline logs"
		ui::muted "  B/logs/         — treatment logs"
	else
		log::warn "Log directories not found — skipping analysis"
		log::warn "  Expected: $control_logs"
		log::warn "  Expected: $treatment_logs"
	fi

	echo ""
	ui::success "Experiment complete: $task_name"
}
