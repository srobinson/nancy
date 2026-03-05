#!/bin/bash
# ------------------------------------------------------------------------------

export NANCY_FRAMEWORK_ROOT="$(pwd)"

# ------------------------------------------------------------------------------

. "src/gql/index.sh"
. "src/linear/index.sh"

# ------------------------------------------------------------------------------

id="ALP-885"

# linear::issue:comment:add "$id" "This is a test comment from Nancy CLI." >/dev/null

parent_issue=$(
	linear::issue "$id"
)

{
	read -r -d '' project_id
	read -r -d '' project_identifier
	read -r -d '' project_title
	read -r -d '' project_description
} < <(jq -j '.data.issue |
			.id, "\u0000",
      .identifier, "\u0000",
      .title, "\u0000",
      .description, "\u0000"
  ' <<<"$parent_issue")

sub_issues=$(
	linear::issue:sub "$project_id"
)

# Write header
cat <<EOF >"ISSUES.md"
# [$project_identifier] $project_title

EOF

# Append formatted table
{
	echo -e " \tISSUE_ID\tTitle\tPriority\tState"
		echo "$sub_issues" | jq -r '.data.issues.nodes | sort_by(.sortOrder) | reverse | .[] |
			(. as $p |
				[
					(if $p.state.name == "Backlog" or $p.state.name == "Todo" or $p.state.name == "In Progress" then "[ ]" else "[X]" end),
					$p.identifier,
					$p.title,
					($p.priorityLabel // "-"),
					$p.state.name
				],
				(
					$p.children.nodes | sort_by(.identifier) | .[]? |
					[
						(if .state.name == "Backlog" or .state.name == "Todo" or .state.name == "In Progress" then "[ ]" else "[X]" end),
						("  ↳ " + .identifier),
						.title,
						(.priorityLabel // "-"),
						.state.name
					]
				)
			) | @tsv'
	} | column -t -s $'\t' >>"ISSUES.md"

# echo "Issue ID: $id"
# echo "Title: $title"
# echo "Description: $desc"

# sub_issues=$(
# 	linear::issue:sub "$id"
# )

# # ----------------------------------------------

# # echo "$sub_issues" | jq '.'
# echo "$sub_issues" | jq -r '.data.issues.nodes[] | ["[ ]", .identifier, .title, .priorityLabel // "-", .state.name] | @tsv' | column -t -s $'\t'

# ----------------------------------------------
