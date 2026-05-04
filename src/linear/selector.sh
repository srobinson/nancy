#!/usr/bin/env bash
# b_path:: src/linear/selector.sh
# Gate aware Linear selection and ledger evidence
# ------------------------------------------------------------------------------

linear::selector:evaluate() {
	local issue_tree="$1"
	local status_tree="${2:-$issue_tree}"

	jq '
		def issue_ids: [scan("[A-Z]+-[0-9]+")];
		def state_name: .state.name;
		def is_selectable: state_name as $s | ["Todo", "In Progress"] | index($s);
		def is_open_state: state_name as $s | ["Todo", "In Progress"] | index($s);
		def is_accepted_state: state_name as $s | ["Worker Done", "Done"] | index($s);
		def role:
			([.labels.nodes[]? | select(.parent.name == "Agent Role") | .name] | .[0] // "");
		def is_backlog:
			.title == "Backlog";
		def is_gate_review:
			.title | test("Gate review|execution readiness"; "i");
		def has_label($name):
			any(.labels.nodes[]?; (.name | ascii_downcase) == ($name | ascii_downcase));
		def is_corrective:
			has_label("Corrective") or (.title | test("corrective"; "i"));
		def is_review:
			has_label("Post Execution Review")
			or (.title | test("^post[ -]execution review"; "i"))
			or ((.description // "") | test("(^|\n)[ \t]*Post execution review"; "i"));
		def direction_events:
			[.comments.nodes[]? |
				{
					at: (.updatedAt // .createdAt // ""),
					body: (.body // "")
				} |
				select(.body | test("Needs human direction|Human direction:"; "i"))
			];
		def latest_direction_event:
			(direction_events | sort_by(.at) | reverse | .[0] // null);
		def has_unresolved_human_direction:
			(latest_direction_event) as $event |
			($event != null)
			and (($event.body // "") | test("Needs human direction"; "i"))
			and ((($event.body // "") | test("^Human direction:"; "im")) | not);
		def human_direction_blocker:
			(latest_direction_event.body // "") as $body |
			(
				[
					($body | split("\n")[] | select(test("^Exact unresolved question:"; "i"))),
					($body | split("\n")[] | select(test("Needs human direction"; "i"))),
					($body | split("\n")[] | select(length > 0))
				] | .[0] // "Needs human direction"
			);
		def review_outcome_ids:
			[.comments.nodes[]?.body as $body |
				(
					[try ($body | capture("(?m)^Reviewed worker issue: (?<id>[A-Z]+-[0-9]+)").id) catch empty]
				)[]
			];
		def is_final_accepted:
			if is_review then state_name == "Done"
			elif is_corrective then is_accepted_state
			else is_accepted_state
			end;
		def released($mode):
			if (. == "Canceled" or . == "Duplicate") then true
			else (. == "Worker Done" or . == "Done")
			end;
		def blockers($mode):
			[.inverseRelations.nodes[]? | select(.type == "blocks") |
				{
					identifier: .issue.identifier,
					title: .issue.title,
					state: .issue.state.name,
					released: (.issue.state.name | released($mode))
				}
			];
		def enriched($parent; $depth):
			. + {
				depth: $depth,
				parent_identifier: ($parent.identifier // ""),
				parent_title: ($parent.title // ""),
				agent_role: role,
				corrective: is_corrective,
				review: is_review
			};
		def selected_shape:
			if . == null then null else {
				identifier,
				title,
				state: state_name,
				parent_identifier,
				parent_title,
				agent_role,
				corrective,
				review
			} end;

		(.data.issues.nodes // []) as $parents |
		($status.data.issues.nodes // []) as $status_parents |
		([ $status_parents[] | enriched({}; 1) ]) as $status_direct |
		([ $status_parents[] as $p | $p.children.nodes[]? | enriched($p; 2) ]) as $status_children |
		($status_direct + $status_children) as $status_all |
		([ $status_direct[] | select((is_backlog | not) and (is_gate_review | not) and is_open_state) ]) as $open_planning |
		([ $status_direct[] | select(is_gate_review) ]) as $gate_reviews |
		([ $gate_reviews[] | select(is_open_state) ] | sort_by(.subIssueSortOrder // 0) | .[0] // null) as $open_gate_review |
		([ $gate_reviews[] | select(is_accepted_state) ] | sort_by(.subIssueSortOrder // 0) | reverse | .[0] // null) as $raw_accepted_gate_status |
		(if (($open_planning | length) > 0 or $open_gate_review != null) then null else $raw_accepted_gate_status end) as $accepted_gate_status |
		([ $parents[] | enriched({}; 1) ]) as $direct |
		([ $parents[] as $p | $p.children.nodes[]? | enriched($p; 2) ]) as $children |
		($direct + $children) as $all |
		([ $children[] | select((.children.nodes // []) | length > 0) ]) as $too_deep |
		([ $direct[] |
			select(.identifier == ($accepted_gate_status.identifier // "")) |
			select((.description // "") | test("Outcome: Ready for execution|Outcome: Pre execution blockers required"))
		] | .[0] // ([ $status_direct[] |
			select(.identifier == ($accepted_gate_status.identifier // "")) |
			select((.description // "") | test("Outcome: Ready for execution|Outcome: Pre execution blockers required"))
		] | .[0] // null)) as $accepted_gate |
		([ $direct[] | select(.title | test("Gate review|execution readiness"; "i")) ] | .[0] // null) as $gate_review |
		($accepted_gate.description // "") as $gate_text |
		([try ($gate_text | capture("Authorized (?:execution|blocker) parent: `(?<id>[A-Z]+-[0-9]+)`").id) catch empty] | .[0] // "") as $authorized_parent |
		([try ($gate_text | capture("Execute(?: blockers only)?: (?<line>[^\n]+)").line | issue_ids[]) catch empty]) as $authorized_ids |
		([ $children[] |
			select(.parent_title == "Backlog") |
			select(is_open_state) |
			select(($authorized_parent == "") or ((.identifier as $id | $authorized_ids | index($id)) | not))
		]) as $unauthorized |
		(if ($accepted_gate != null and $authorized_parent != "") then $unauthorized else [] end) as $unauthorized_gate_defects |
		([ $all[] |
			select((.parent_identifier == $authorized_parent) and (.identifier as $id | $authorized_ids | index($id)))
		]) as $authorized |
		([ $status_all[] |
			select((.parent_identifier == $authorized_parent) and (.identifier as $id | $authorized_ids | index($id)))
		]) as $authorized_status |
		([ $authorized_ids[] as $id |
			select(([ $authorized_status[].identifier ] | index($id)) | not)
		]) as $missing_authorized_status |
		([ $authorized_status[] | select(.review) | review_outcome_ids[] ]) as $reviewed_worker_ids |
		([ $authorized_status[] |
			select((.corrective | not) and (.review | not) and is_accepted_state) |
			select((.identifier as $id | $reviewed_worker_ids | index($id)) | not)
		] | sort_by(.subIssueSortOrder // 0) | .[0] // null) as $review_target |
		($review_target != null and ([ $authorized_status[] | select(.review and is_final_accepted) ] | length) > 0) as $review_closed_with_unreviewed_target |
		([ $authorized_status[] | select(is_final_accepted | not) ]) as $not_final_authorized |
		(
			($authorized_ids | length) > 0
			and $accepted_gate != null
			and ($missing_authorized_status | length) == 0
			and ($not_final_authorized | length) == 0
			and ($review_target == null)
		) as $final_ready |
		([ $authorized[] | select(is_selectable and .corrective) ]) as $corrective_open |
		([ $authorized[] | select(.review and (is_selectable or state_name == "Worker Done")) ]) as $review_open |
		([ $authorized[] | select(is_selectable and (.corrective | not) and (.review | not)) ]) as $execution_open |
		([ $authorized_status[] | select(.review and has_unresolved_human_direction) ]) as $human_direction_reviews |
		(if ($too_deep | length) > 0 then "needs_human_direction"
		elif ($open_planning | length) > 0 then "planning"
		elif $open_gate_review != null then "planning"
		elif ($unauthorized_gate_defects | length) > 0 then "needs_human_direction"
		elif ($corrective_open | length) > 0 then "corrective_resolution"
		elif (($execution_open | length) == 0 and ($human_direction_reviews | length) > 0) then "needs_human_direction"
		elif (($execution_open | length) == 0 and $review_closed_with_unreviewed_target) then "needs_human_direction"
		elif (($execution_open | length) == 0 and ($review_open | length) > 0) then "post_execution_review"
		elif $final_ready then "final_completion"
		elif ($authorized_ids | length) > 0 then "execution"
		else "planning"
		end) as $mode |
		(if $mode == "planning" then
			if ($open_planning | length) > 0 then
				[ $direct[] | .identifier as $id | select(any($open_planning[]; .identifier == $id)) ]
			elif $open_gate_review != null then
				[ $direct[] | select(.identifier == $open_gate_review.identifier) ]
			else
				[ $direct[] | select(is_selectable and (.title != "Backlog")) ]
			end
		elif $mode == "corrective_resolution" then
			$corrective_open
		elif $mode == "post_execution_review" then
			$review_open
		elif $mode == "needs_human_direction" then
			[]
		else
			$execution_open
		end) as $pool |
		([ $pool[] | . + {blockers: blockers($mode)} ]) as $classified |
		([ $classified[] | select(any(.blockers[]?; .released | not)) ]) as $blocked |
		([ $classified[] | select((any(.blockers[]?; .released | not) | not)) ] | sort_by(.subIssueSortOrder // 0) | .[0] // null) as $selected |
		{
			selected_mode: $mode,
			selected_issue: ($selected | selected_shape),
			eligibility_reason:
				(if $mode == "needs_human_direction" then
					(if ($too_deep | length) > 0 then
						"Hierarchy deeper than children and grandchildren requires human direction"
					elif ($unauthorized_gate_defects | length) > 0 then
						"Open Backlog issue exists outside accepted gate Execute list"
					elif $review_closed_with_unreviewed_target then
						"Post execution review issue closed before every worker issue was reviewed"
					else
						"Post execution review recorded Needs human direction"
					end)
				elif $mode == "final_completion" then
					"All authorized gate work is terminal"
				elif $selected == null then
					"No eligible issue after gate, status, and blocker checks"
				elif $mode == "corrective_resolution" then
					"Corrective issue outranks review until accepted or recorded independent"
				elif $mode == "post_execution_review" then
					"Post execution review is eligible after execution and corrective queues are clear"
				elif $mode == "execution" then
					"Authorized by accepted gate outcome and unblocked for execution"
				else
					"Planning issue is selectable before gate authorization"
				end),
			completion_threshold: {
				mode: $mode,
				blocker_release_states:
					["Worker Done", "Done", "Canceled", "Duplicate"],
				final_acceptance_states:
					(if $mode == "post_execution_review" then ["Done"] else ["Worker Done", "Done"] end)
			},
			blocked_candidates: [ $blocked[] | {
				identifier,
				title,
				state: state_name,
				parent_identifier,
				blockers: [.blockers[] | select(.released | not) | .identifier]
			}],
			unauthorized_backlog_candidates: [ $unauthorized[] | {
				identifier,
				title,
				state: state_name,
				parent_identifier,
				gate_review_issue: (($gate_review.identifier // $accepted_gate.identifier) // "")
			}],
			corrective_priority_evidence: {
				open_corrective: [ $corrective_open[] | {identifier, title, state: state_name} ],
				open_review: [ $review_open[] | {identifier, title, state: state_name} ],
				corrective_outranks_review: (($corrective_open | length) > 0 and ($review_open | length) > 0)
			},
			authorized_parent: $authorized_parent,
			authorized_issue_ids: $authorized_ids,
			human_direction: (
				[ $human_direction_reviews[] |
					{
						identifier,
						title,
						state: state_name,
						blocker: human_direction_blocker
					}
				] | .[0] // null
			),
			review_target: (
				if $mode != "post_execution_review" or $review_target == null then null else {
					identifier: $review_target.identifier,
					title: $review_target.title,
					state: ($review_target.state.name // "")
				} end
			),
			hierarchy_depth_supported: 2,
			requires_human_direction: ((($too_deep | length) > 0) or (($unauthorized_gate_defects | length) > 0) or (($human_direction_reviews | length) > 0) or $review_closed_with_unreviewed_target)
		}
	' --argjson status "$status_tree" <<<"$issue_tree"
}

linear::selector:render_summary() {
	local selection="$1"

	jq -r '
		"## Selector Decision",
		"",
		"* Mode: `" + .selected_mode + "`",
		"* Selected issue: " + (if .selected_issue then "`" + .selected_issue.identifier + "` " + .selected_issue.title else "none" end),
		"* Reason: " + .eligibility_reason,
		"* Blocker threshold: " + (.completion_threshold.blocker_release_states | map("`" + . + "`") | join(", ")),
		"",
		"ISSUES.md is selector evidence only. Linear selection above is authoritative.",
		""
	' <<<"$selection"
}

linear::selector:render_blocker() {
	local selection="$1"

	jq -r '
		"BLOCKER: Needs human direction",
		"",
		(if .human_direction then
			"Issue: `" + .human_direction.identifier + "` " + .human_direction.title,
			"State: `" + .human_direction.state + "`",
			"",
			(.human_direction.blocker // "Needs human direction")
		else
			(.eligibility_reason // "Needs human direction")
		end)
	' <<<"$selection"
}

linear::selector:render_prompt_context() {
	local selection="$1"

	jq -r '
		if .selected_issue then
			"## Selected Work\n\n" +
			"- Mode: `" + .selected_mode + "`\n" +
			"- Issue: `" + .selected_issue.identifier + "` " + .selected_issue.title + "\n" +
			(if .review_target then
				"- Review target: `" + .review_target.identifier + "` " + .review_target.title + "\n"
			else "" end) +
			"- Eligibility: " + .eligibility_reason + "\n\n" +
			"Use this selected issue. Do not choose work from the first unchecked ISSUES.md row."
		else
			"## Selected Work\n\n" +
			"- Mode: `" + .selected_mode + "`\n" +
			"- Issue: none\n" +
			"- Eligibility: " + .eligibility_reason + "\n\n" +
			"Do not infer authority from ISSUES.md checkbox order."
		end
	' <<<"$selection"
}

linear::selector:row_marker_jq() {
	cat <<'JQ'
def marker($selector):
	.identifier as $id |
	if $selector.selected_issue and $selector.selected_issue.identifier == $id then
		"SELECTED"
	elif any($selector.blocked_candidates[]?; .identifier == $id) then
		("BLOCKED: " + ([ $selector.blocked_candidates[] | select(.identifier == $id) | .blockers[] ] | join(",")))
	elif any($selector.unauthorized_backlog_candidates[]?; .identifier == $id) then
		("UNAUTHORIZED: " + ([ $selector.unauthorized_backlog_candidates[] | select(.identifier == $id) | .gate_review_issue ] | .[0] // "gate-review"))
	else
		"-"
	end;
JQ
}
