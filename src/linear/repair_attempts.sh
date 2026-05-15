#!/usr/bin/env bash
# b_path:: src/linear/repair_attempts.sh
# Durable workflow repair attempt state
# ------------------------------------------------------------------------------

# shellcheck disable=SC2016
readonly _LINEAR_SELECTOR_REPAIR_ATTEMPTS_JQ='
	def repair_comment_json($comment):
		([try (($comment.body // "") | fromjson) catch empty] | .[0] // null);
	def repair_comment_event($issue; $comment):
		repair_comment_json($comment) as $json |
		($comment.updatedAt // $comment.createdAt // "") as $at |
		if (($json.repair_attempts? // null) | type) == "object" then
			$json.repair_attempts as $attempt |
			{
				kind: "attempt",
				comment_issue: ($issue.identifier // ""),
				target_issue: (($attempt.target_issue // "") | tostring),
				repair_instruction: (($attempt.repair_instruction // "") | tostring),
				iteration_timestamp: (($attempt.iteration_timestamp // "") | tostring),
				at: (($at // $attempt.iteration_timestamp // "") | tostring)
			}
		elif (($json.repair_attempts_resolved? // null) | type) == "object" then
			$json.repair_attempts_resolved as $resolution |
			{
				kind: "resolved",
				comment_issue: ($issue.identifier // ""),
				target_issue: (($resolution.target_issue // "") | tostring),
				repair_instruction: (($resolution.repair_instruction // "") | tostring),
				iteration_timestamp: (($resolution.iteration_timestamp // "") | tostring),
				at: (($at // $resolution.iteration_timestamp // "") | tostring)
			}
		else empty end |
		select(.target_issue != "" and .repair_instruction != "" and .iteration_timestamp != "");
	def repair_comment_events($issues):
		[ $issues[] as $issue |
			$issue.comments.nodes[]? as $comment |
			repair_comment_event($issue; $comment)
		];
	def unresolved_repair_attempts($events; $routing):
		reduce ([
			$events[] |
			select(.target_issue == $routing.target_issue) |
			select(.repair_instruction == $routing.repair_instruction)
		] | sort_by(.at, .iteration_timestamp, .kind)[]) as $event ([];
			if $event.kind == "resolved" then [] else . + [$event] end
		);
	def selector_repair_attempt_escalation($predicates):
		selector_repair_routing($predicates) as $routing |
		selector_repair_target($predicates) as $target |
		if $routing == null then null
		else
			(unresolved_repair_attempts($predicates.repair_comment_events; $routing)) as $attempts |
			if ($attempts | length) >= 2 then
				($attempts[-2:]) as $prior_attempts |
				([ $prior_attempts[] |
					.target_issue + " at " + .iteration_timestamp + " (comment on " + .comment_issue + ")"
				] | join("; ")) as $evidence |
				{
					identifier: $routing.target_issue,
					title: (($target.title // "") | tostring),
					state: (($target.state.name // "") | tostring),
					blocker: ("Workflow repair routed twice for " + $routing.target_issue + " without a matching repair_attempts_resolved comment."),
					classification: "loop",
					classifier_body: (
						"Outcome: Needs human direction\n" +
						"Classification: loop\n" +
						"What was tried: Routed workflow repair for " + $routing.target_issue + " twice without a matching repair_attempts_resolved comment.\n" +
						"Loop evidence: " + $evidence + "\n" +
						"Smallest unblock imagined: Complete the repair or record the matching repair_attempts_resolved JSON line after repair."
					),
					attempts: $prior_attempts
				}
			else null end
		end;
	def selector_repair_mode($predicates):
		if selector_repair_attempt_escalation($predicates) != null then "agent_stuck" else "workflow_repair" end;
'

linear::selector:write_repair_attempt() {
	local selection="$1"
	local master_issue="$2"
	local iteration_timestamp="${3:-$(date -u +"%Y-%m-%dT%H:%M:%SZ")}"

	if ! selection=$(linear::selector:_canonicalize_render_input "$selection"); then
		return 1
	fi
	if ! jq -e '.workflow_repair_route == true and (.repair_routing | type == "object")' >/dev/null <<<"$selection"; then
		return 0
	fi

	local target_issue repair_instruction selected_issue selected_issue_is_review
	{
		read -r -d '' target_issue
		read -r -d '' repair_instruction
		read -r -d '' selected_issue
		read -r -d '' selected_issue_is_review
	} < <(jq -j '
		.repair_routing.target_issue // "", "\u0000",
		.repair_routing.repair_instruction // "", "\u0000",
		.selected_issue.identifier // "", "\u0000",
		(if .selected_issue.review == true then "true" else "false" end), "\u0000"
	' <<<"$selection")

	if [[ -z "$target_issue" || -z "$repair_instruction" ]]; then
		return 1
	fi

	local comment_issue="$master_issue"
	if [[ "$selected_issue_is_review" == "true" && -n "$selected_issue" ]]; then
		comment_issue="$selected_issue"
	fi
	if [[ -z "$comment_issue" ]]; then
		return 1
	fi

	local marker_root="${NANCY_CURRENT_TASK_DIR:-}"
	if [[ -z "$marker_root" && -n "${NANCY_TASK_DIR:-}" ]]; then
		marker_root="${NANCY_TASK_DIR}/${master_issue}"
	fi
	if [[ -z "$marker_root" ]]; then
		marker_root="${TMPDIR:-/tmp}/nancy-repair-attempts"
	fi
	local marker_dir="${marker_root}/.repair_attempts"
	local marker_key
	marker_key=$(printf '%s\n%s\n%s\n%s\n' \
		"${NANCY_SESSION_ID:-manual}" "$comment_issue" "$target_issue" "$repair_instruction" |
		shasum -a 256 | awk '{print $1}')
	local marker="${marker_dir}/${marker_key}"
	if [[ -f "$marker" ]]; then
		return 0
	fi

	local body
	if ! body=$(jq -cn \
		--arg target_issue "$target_issue" \
		--arg repair_instruction "$repair_instruction" \
		--arg iteration_timestamp "$iteration_timestamp" \
		'{repair_attempts:{target_issue:$target_issue,repair_instruction:$repair_instruction,iteration_timestamp:$iteration_timestamp}}'); then
		return 1
	fi

	mkdir -p "$marker_dir" || return 1
	linear::issue:comment:add "$comment_issue" "$body" >/dev/null || return 1
	printf '%s\n' "$body" >"$marker"
}
