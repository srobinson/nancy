#!/usr/bin/env bash
# b_path:: src/linear/issue.sh
# ------------------------------------------------------------------------------

linear::issue() {
	local issue_id=${1}

	local variables=$(
		gql::query::variables "id::$issue_id"
	)
	local query=$(
		gql::query::generate "$NANCY_FRAMEWORK_ROOT/src/gql/q/get_issue.gql" "$variables"
	)
	gql::client::query "$query"
}

linear::issue:sub() {
	local parent_id=${1}

	local variables=$(
		gql::query::variables "id::$parent_id"
	)
	local query=$(
		gql::query::generate "$NANCY_FRAMEWORK_ROOT/src/gql/q/get_sub_issues.gql" "$variables"
	)
	gql::client::query "$query"
}

linear::issue:next() {
	local project_name=${1}
	local state_name=${2:-Todo}

	local variables=$(
		gql::query::variables "projectName::$project_name" "stateName::$state_name"
	)
	local query=$(
		gql::query::generate "$NANCY_FRAMEWORK_ROOT/src/gql/q/get_next_todo_issue.gql" "$variables"
	)
	gql::client::query "$query"
}

linear::issue:comment:add() {
	local issue_id="$1"
	local comment_text="$2"

	local variables=$(
		gql::query::variables "issueId::$issue_id" "body::$comment_text"
	)
	local query=$(
		gql::query::generate "$NANCY_FRAMEWORK_ROOT/src/gql/q/create_comment.gql" "$variables"
	)
	gql::client::query "$query"
}

linear::issue:update:status() {
	local issue_id="$1"
	local state="$2"

	local state_id=$(
		linear::workflow:states | jq -r ".data.workflowStates.nodes[] | select(.name == \"$state\") | .id"
	)
	local variables=$(
		gql::query::variables "id::$issue_id" "stateId::$state_id"
	)
	local query=$(
		gql::query::generate "$NANCY_FRAMEWORK_ROOT/src/gql/q/update_status.gql" "$variables"
	)
	gql::client::query "$query"
}

linear::workflow:states() {
	local query=$(
		gql::query::generate "$NANCY_FRAMEWORK_ROOT/src/gql/q/get_workflow_states.gql"
	)
	gql::client::query "$query"
}
