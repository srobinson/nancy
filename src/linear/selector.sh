#!/usr/bin/env bash
# b_path:: src/linear/selector.sh
# Gate aware Linear selection and ledger evidence
# ------------------------------------------------------------------------------

_LINEAR_SELECTOR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$_LINEAR_SELECTOR_DIR/repair_attempts.sh"
unset _LINEAR_SELECTOR_DIR

# shellcheck disable=SC2016
readonly _LINEAR_SELECTOR_EVALUATE_JQ='
	def issue_ids: [scan("[A-Z]+-[0-9]+")];
	def state_name: .state.name;
	def is_selectable: state_name as $s | ["Backlog", "Todo", "In Progress"] | index($s);
	def is_open_state: state_name as $s | ["Backlog", "Todo", "In Progress"] | index($s);
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
	def latest_unresolved_direction_event:
		(latest_direction_event) as $event |
		if (($event != null)
			and (($event.body // "") | test("^Outcome:[ \t]*Needs human direction"; "im"))
			and ((($event.body // "") | test("^Human direction:"; "im")) | not))
		then $event else null end;
	def has_unresolved_human_direction:
		latest_unresolved_direction_event != null;
	def human_direction_classification:
		(latest_unresolved_direction_event.body // "") as $body |
		([try ($body |
			capture("(?im)^Classification:[ \t]*(?<class>loop|decision)[ \t]*$").class |
			ascii_downcase
		) catch empty] | .[0] // "");
	def has_direction_class($class):
		has_unresolved_human_direction and human_direction_classification == $class;
		def human_direction_blocker:
			(latest_direction_event.body // "") as $body |
			(
				[
					($body | split("\n")[] | select(test("^Exact unresolved question:"; "i"))),
					($body | split("\n")[] | select(test("Needs human direction"; "i"))),
					($body | split("\n")[] | select(length > 0))
				] | .[0] // "Needs human direction"
			);
		def human_direction_classifier_body:
			latest_unresolved_direction_event.body // "";
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
	def selector_repair_target($predicates):
		if ($predicates.too_deep | length) > 0 then
			$predicates.too_deep[0]
		elif ($predicates.unauthorized_gate_defects | length) > 0 then
			($predicates.review_open[0]
				// $predicates.accepted_gate
				// $predicates.gate_review
				// $predicates.unauthorized_gate_defects[0])
		elif $predicates.review_closed_with_unreviewed_target then
			($predicates.final_review // $predicates.review_target)
		else null end;
	def selector_repair_routing($predicates):
		selector_repair_target($predicates) as $target |
		if $target == null then null
		elif ($predicates.too_deep | length) > 0 then
			{
				target_issue: $target.identifier,
				target_mode: "planning",
				repair_instruction: ("Flatten unsupported hierarchy under " + $target.identifier + "; Nancy supports only parent and child issues.")
			}
		elif ($predicates.unauthorized_gate_defects | length) > 0 then
			($predicates.unauthorized_gate_defects | map(.identifier) | join(", ")) as $ids |
			{
				target_issue: $target.identifier,
				target_mode: (if ($target.review // false) then "post_execution_review" else "planning" end),
				repair_instruction: ("Authorize " + $ids + " in the accepted gate Execute list before continuing post execution review.")
			}
		elif $predicates.review_closed_with_unreviewed_target then
			{
				target_issue: $target.identifier,
				target_mode: "post_execution_review",
				repair_instruction: ("Resume post execution review for " + $predicates.review_target.identifier + " before final completion.")
			}
		else null end;
'"$_LINEAR_SELECTOR_REPAIR_ATTEMPTS_JQ"'
	def selector_predicates:
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
		([ $authorized_status[] | select(.review and is_final_accepted) ] | sort_by(.subIssueSortOrder // 0) | .[0] // null) as $final_review |
		($review_target != null and $final_review != null) as $review_closed_with_unreviewed_target |
		([ $authorized_status[] | select(is_final_accepted | not) ]) as $not_final_authorized |
		([ $authorized_status[] | select(.review and is_open_state and has_direction_class("loop")) ]) as $agent_stuck_reviews |
		([ $authorized_status[] | select(.review and is_open_state and has_direction_class("decision")) ]) as $product_decision_reviews |
		($agent_stuck_reviews + $product_decision_reviews) as $human_direction_reviews |
		(
			($authorized_ids | length) > 0
			and $accepted_gate != null
			and ($missing_authorized_status | length) == 0
			and ($not_final_authorized | length) == 0
			and ($review_target == null)
			and ($human_direction_reviews | length) == 0
		) as $final_ready |
		([ $authorized[] | select(is_selectable and .corrective) ]) as $corrective_open |
		([ $authorized[] | select(.review and (is_selectable or state_name == "Worker Done")) ]) as $review_open |
		([ $authorized[] | select(is_selectable and (.corrective | not) and (.review | not)) ]) as $execution_open |
		{
			direct: $direct,
			too_deep: $too_deep,
			open_planning: $open_planning,
			open_gate_review: $open_gate_review,
			unauthorized_gate_defects: $unauthorized_gate_defects,
			corrective_open: $corrective_open,
			human_direction_reviews: $human_direction_reviews,
			review_closed_with_unreviewed_target: $review_closed_with_unreviewed_target,
			review_open: $review_open,
			review_target: $review_target,
			final_review: $final_review,
			execution_open: $execution_open,
			final_ready: $final_ready,
			authorized_ids: $authorized_ids,
			unauthorized: $unauthorized,
			agent_stuck_reviews: $agent_stuck_reviews,
			product_decision_reviews: $product_decision_reviews,
			gate_review: $gate_review,
			accepted_gate: $accepted_gate,
			authorized_parent: $authorized_parent,
			repair_comment_events: repair_comment_events(([ $status.data.issue? // empty ] + $status_all))
		};

		def selector_mode($predicates):
			if ($predicates.too_deep | length) > 0 then selector_repair_mode($predicates)
			elif ($predicates.open_planning | length) > 0 then "planning"
			elif $predicates.open_gate_review != null then "planning"
			elif ($predicates.unauthorized_gate_defects | length) > 0 then selector_repair_mode($predicates)
			elif ($predicates.corrective_open | length) > 0 then "corrective_resolution"
			elif ($predicates.agent_stuck_reviews | length) > 0 then "agent_stuck"
			elif ($predicates.product_decision_reviews | length) > 0 then "product_decision"
			elif $predicates.review_closed_with_unreviewed_target then selector_repair_mode($predicates)
			elif (($predicates.review_open | length) > 0
				and ($predicates.review_target != null or ($predicates.execution_open | length) == 0))
			then "post_execution_review"
			elif $predicates.final_ready then "final_completion"
			elif ($predicates.authorized_ids | length) > 0 then "execution"
			else "planning"
			end;

	def selector_pool($predicates; $mode):
		if $mode == "planning" then
			if ($predicates.open_planning | length) > 0 then
				[ $predicates.direct[] | .identifier as $id | select(any($predicates.open_planning[]; .identifier == $id)) ]
			elif $predicates.open_gate_review != null then
				[ $predicates.direct[] | select(.identifier == $predicates.open_gate_review.identifier) ]
			else
				[ $predicates.direct[] | select(is_selectable and (.title != "Backlog")) ]
			end
			elif $mode == "corrective_resolution" then
				$predicates.corrective_open
			elif $mode == "post_execution_review" then
				$predicates.review_open
			elif $mode == "workflow_repair" then
				[selector_repair_target($predicates)] | map(select(. != null))
			elif $mode == "agent_stuck" or $mode == "product_decision" then
				[]
			else
				$predicates.execution_open
			end;

	def selector_candidates($predicates; $mode):
		(selector_pool($predicates; $mode)) as $pool |
		([ $pool[] | . + {blockers: blockers($mode)} ]) as $classified |
		([ $classified[] | select((.review | not) and any(.blockers[]?; .released | not)) ]) as $blocked |
		([ $classified[] |
			select(.review or (any(.blockers[]?; .released | not) | not))
		] | sort_by(.subIssueSortOrder // 0) | .[0] // null) as $selected |
		{
			blocked: $blocked,
			selected: $selected
		};

	def selector_output($predicates; $mode; $candidates):
		(selector_repair_attempt_escalation($predicates)) as $repair_escalation |
		{
			selected_mode: $mode,
			selected_issue: ($candidates.selected | selected_shape),
			eligibility_reason:
				(if $mode == "workflow_repair" then
					(if ($predicates.too_deep | length) > 0 then
						"Workflow repair required: hierarchy exceeds supported depth"
						elif ($predicates.unauthorized_gate_defects | length) > 0 then
							"Workflow repair required: open Backlog issue outside accepted gate Execute list"
						else
							"Workflow repair required: post execution review closed before every worker issue was reviewed"
						end)
					elif $mode == "agent_stuck" then
						(if $repair_escalation != null then
							"Workflow repair loop: repeated repair attempts did not resolve durable state"
						else
							"Agent is stuck in a self diagnosed loop"
						end)
					elif $mode == "product_decision" then
						"Product or scope decision needed from human"
					elif $mode == "final_completion" then
						"All authorized gate work is terminal"
					elif $candidates.selected == null then
						"No eligible issue after gate, status, and blocker checks"
				elif $mode == "corrective_resolution" then
					"Corrective issue outranks review until accepted or recorded independent"
				elif $mode == "post_execution_review" then
					(if $predicates.review_target != null then
						"Worker issue completed and awaiting review; corrective queue is clear"
					else
						"Execution and corrective queues are clear; reconcile open review issue state"
					end)
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
			blocked_candidates: [ $candidates.blocked[] | {
				identifier,
				title,
				state: state_name,
				parent_identifier,
				blockers: [.blockers[] | select(.released | not) | .identifier]
			}],
			unauthorized_backlog_candidates: [ $predicates.unauthorized_gate_defects[] | {
				identifier,
				title,
				state: state_name,
				parent_identifier,
				gate_review_issue: (($predicates.gate_review.identifier // $predicates.accepted_gate.identifier) // "")
			}],
			corrective_priority_evidence: {
				open_corrective: [ $predicates.corrective_open[] | {identifier, title, state: state_name} ],
				open_review: [ $predicates.review_open[] | {identifier, title, state: state_name} ],
				corrective_outranks_review: (($predicates.corrective_open | length) > 0 and ($predicates.review_open | length) > 0)
			},
			authorized_parent: $predicates.authorized_parent,
			authorized_issue_ids: $predicates.authorized_ids,
				human_direction: (
					if $repair_escalation != null and $mode == "agent_stuck" then
						{
							identifier: $repair_escalation.identifier,
							title: $repair_escalation.title,
							state: $repair_escalation.state,
							blocker: $repair_escalation.blocker,
							classification: $repair_escalation.classification,
							classifier_body: $repair_escalation.classifier_body
						}
					else [ $predicates.human_direction_reviews[] |
						{
							identifier,
							title,
							state: state_name,
							blocker: human_direction_blocker,
							classification: human_direction_classification,
							classifier_body: human_direction_classifier_body
						}
					] | .[0] // null end
				),
			workflow_repair_route: ($mode == "workflow_repair"),
			agent_stuck: ($mode == "agent_stuck"),
			product_decision_needed: (($predicates.product_decision_reviews | length) > 0),
			repair_routing: (if $mode == "workflow_repair" then selector_repair_routing($predicates) else null end),
			review_target: (
				if $mode != "post_execution_review" or $predicates.review_target == null then null else {
					identifier: $predicates.review_target.identifier,
					title: $predicates.review_target.title,
					state: ($predicates.review_target.state.name // "")
				} end
			),
			hierarchy_depth_supported: 2
		};

	selector_predicates as $predicates |
	selector_mode($predicates) as $mode |
	selector_candidates($predicates; $mode) as $candidates |
	selector_output($predicates; $mode; $candidates)
'

linear::selector:evaluate() {
	local issue_tree="$1"
	local status_tree="${2:-$issue_tree}"

	jq "$_LINEAR_SELECTOR_EVALUATE_JQ" --argjson status "$status_tree" <<<"$issue_tree"
}

linear::selector:_canonicalize_render_input() {
	jq -c -s 'if length == 1 then .[0] else error("invalid selector JSON") end' 2>/dev/null <<<"$1"
}

linear::selector:render_summary() {
	local selection="$1"

	if ! selection=$(linear::selector:_canonicalize_render_input "$selection"); then
		cat <<'EOF'
## Selector Decision

* Mode: `invalid_selector`
* Selected issue: none
* Reason: Selector JSON invalid

ISSUES.md is selector evidence only. Linear selection above is authoritative.

EOF
		return 0
	fi

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

linear::selector:render_repair_route() {
	local selection="$1"

	if ! selection=$(linear::selector:_canonicalize_render_input "$selection"); then
		cat <<'EOF'
INFO: Selector JSON invalid

Nancy could not render the selector repair route because the selector JSON was malformed.
EOF
		return 0
	fi

	jq -r '
		if (.workflow_repair_route and .repair_routing) then
			"INFO: Workflow repair route",
			"",
			"Target issue: `" + .repair_routing.target_issue + "`" + (
				if .selected_issue and .selected_issue.identifier == .repair_routing.target_issue then
					" " + .selected_issue.title
				else
					""
				end
			),
			"Target mode: `" + .repair_routing.target_mode + "`",
			"Repair instruction: " + .repair_routing.repair_instruction
		else empty end
	' <<<"$selection"
}

linear::selector:_render_human_direction_blocker() {
	local selection="$1"
	local blocker_kind="$2"

	if ! selection=$(linear::selector:_canonicalize_render_input "$selection"); then
		cat <<'EOF'
BLOCKER: Selector JSON invalid

Nancy could not render the selector blocker because the selector JSON was malformed.
EOF
		return 0
	fi

	jq -r --arg blocker_kind "$blocker_kind" '
		def body:
			.human_direction.classifier_body
			// .human_direction.blocker
			// .eligibility_reason
			// "";
		def first_line($patterns):
			[body | split("\n")[] as $line |
				$line |
				select(any($patterns[]; . as $pattern | ($line | test($pattern; "i"))))
			] | .[0] // "";
		def field_value($patterns; $fallback):
			(first_line($patterns)) as $line |
			if $line == "" then $fallback else ($line | sub("^[^:]+:[ \t]*"; "")) end;
		def issue_lines:
			if .human_direction then
				"Issue: `" + .human_direction.identifier + "` " + .human_direction.title,
				"State: `" + .human_direction.state + "`"
			else
				"Issue: unknown"
			end;

		if $blocker_kind == "loop" then
			"BLOCKER: Agent stuck",
			"",
			issue_lines,
			"",
			"What was tried: " + field_value(["^What was tried:", "^Tried:"]; "Not recorded"),
			"Loop evidence: " + field_value(["^Loop evidence:", "^Evidence:"]; (.human_direction.blocker // .eligibility_reason // "Not recorded")),
			"Smallest unblock imagined: " + field_value(["^Smallest unblock", "^Smallest agent unblock", "^Smallest Stuart unblock"]; "Not recorded")
		else
			"BLOCKER: Product decision needed",
			"",
			issue_lines,
			"",
			"Question: " + field_value(["^Exact unresolved question:", "^Unresolved question:", "^Question:"]; (.human_direction.blocker // .eligibility_reason // "Not recorded")),
			"Positions: " + field_value(["^Positions:", "^Position:"]; "Not recorded"),
			"Smallest decision: " + field_value(["^Smallest decision:", "^Smallest Stuart decision:"]; "Not recorded"),
			"Safe work while waiting: " + field_value(["^Safe work while waiting:", "^Safe work:"]; "Not recorded")
		end
	' <<<"$selection"
}

linear::selector:render_loop_blocker() {
	linear::selector:_render_human_direction_blocker "$1" "loop"
}

linear::selector:render_decision_blocker() {
	linear::selector:_render_human_direction_blocker "$1" "decision"
}

linear::selector:render_prompt_context() {
	local selection="$1"

	if ! selection=$(linear::selector:_canonicalize_render_input "$selection"); then
		cat <<'EOF'
## Selected Work

- Mode: `invalid_selector`
- Issue: none
- Eligibility: Selector JSON invalid

Do not infer authority from ISSUES.md checkbox order.
EOF
		return 0
	fi

	jq -r '
		if .selected_issue then
			"## Selected Work\n\n" +
			"- Mode: `" + .selected_mode + "`\n" +
			"- Issue: `" + .selected_issue.identifier + "` " + .selected_issue.title + "\n" +
				(if .review_target then
					"- Review target: `" + .review_target.identifier + "` " + .review_target.title + "\n"
				else "" end) +
				(if .selected_mode == "workflow_repair" and .repair_routing and .repair_routing.repair_instruction then
					"- Repair instruction: " + .repair_routing.repair_instruction + "\n"
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
