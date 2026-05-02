#!/usr/bin/env bash
# b_path:: src/linear/selector.sh
# Gate aware Linear selection and ledger evidence
# ------------------------------------------------------------------------------

linear::selector:evaluate() {
	local issue_tree="$1"

	jq '
		def issue_ids: [scan("[A-Z]+-[0-9]+")];
		def state_name: .state.name;
		def is_selectable: state_name as $s | ["Todo", "In Progress"] | index($s);
		def role:
			([.labels.nodes[]? | select(.parent.name == "Agent Role") | .name] | .[0] // "");
		def has_label($name):
			any(.labels.nodes[]?; (.name | ascii_downcase) == ($name | ascii_downcase));
		def is_corrective:
			has_label("Corrective") or (.title | test("corrective"; "i"));
		def is_review:
			has_label("Post Execution Review") or (.title | test("^post[ -]execution review"; "i"));
		def released($mode):
			if (. == "Canceled" or . == "Duplicate") then true
			elif ($mode == "post_execution_review" or $mode == "final_completion")
			then . == "Done"
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
		([ $parents[] | enriched({}; 1) ]) as $direct |
		([ $parents[] as $p | $p.children.nodes[]? | enriched($p; 2) ]) as $children |
		($direct + $children) as $all |
		([ $children[] | select((.children.nodes // []) | length > 0) ]) as $too_deep |
		([ $direct[] |
			select((.description // "") | test("Outcome: Ready for execution|Outcome: Pre execution blockers required"))
		] | .[0] // null) as $accepted_gate |
		([ $direct[] | select(.title | test("Gate review|execution readiness"; "i")) ] | .[0] // null) as $gate_review |
		($accepted_gate.description // "") as $gate_text |
		([try ($gate_text | capture("Authorized (?:execution|blocker) parent: `(?<id>[A-Z]+-[0-9]+)`").id) catch empty] | .[0] // "") as $authorized_parent |
		([try ($gate_text | capture("Execute(?: blockers only)?: (?<line>[^\n]+)").line | issue_ids[]) catch empty]) as $authorized_ids |
		([ $children[] |
			select(.parent_title == "Backlog") |
			select(($authorized_parent == "") or ((.identifier as $id | $authorized_ids | index($id)) | not))
		]) as $unauthorized |
		([ $all[] |
			select((.parent_identifier == $authorized_parent) and (.identifier as $id | $authorized_ids | index($id)))
		]) as $authorized |
		([ $authorized[] | select(is_selectable and .corrective) ]) as $corrective_open |
		([ $authorized[] | select(is_selectable and .review) ]) as $review_open |
		([ $authorized[] | select(is_selectable and (.corrective | not) and (.review | not)) ]) as $execution_open |
		(if ($too_deep | length) > 0 then "needs_human_direction"
		elif ($corrective_open | length) > 0 then "corrective_resolution"
		elif (($execution_open | length) == 0 and ($review_open | length) > 0) then "post_execution_review"
		elif ($authorized_ids | length) > 0 then "execution"
		else "planning"
		end) as $mode |
		(if $mode == "planning" then
			[ $direct[] | select(is_selectable and (.title != "Backlog")) ]
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
					"Hierarchy deeper than children and grandchildren requires human direction"
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
					(if ($mode == "post_execution_review" or $mode == "final_completion")
					then ["Done"]
					else ["Worker Done", "Done"]
					end),
				final_acceptance_states: ["Done"]
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
			hierarchy_depth_supported: 2,
			requires_human_direction: (($too_deep | length) > 0)
		}
	' <<<"$issue_tree"
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

linear::selector:render_prompt_context() {
	local selection="$1"

	jq -r '
		if .selected_issue then
			"## Selected Work\n\n" +
			"- Mode: `" + .selected_mode + "`\n" +
			"- Issue: `" + .selected_issue.identifier + "` " + .selected_issue.title + "\n" +
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
