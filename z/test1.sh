#!/usr/bin/env bash
# ------------------------------------------------------------------------------

set -euo pipefail

export NANCY_FRAMEWORK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NANCY_PROJECT_ROOT="$NANCY_FRAMEWORK_ROOT"
export NANCY_DIR="$NANCY_PROJECT_ROOT/.nancy"
export NANCY_TASK_DIR="$NANCY_DIR/tasks"
export NANCY_CONFIG_FILE="$NANCY_DIR/config.json"
export NANCY_CURRENT_TASK_DIR="$NANCY_PROJECT_ROOT"

# ------------------------------------------------------------------------------

. "$NANCY_FRAMEWORK_ROOT/src/gql/index.sh"
. "$NANCY_FRAMEWORK_ROOT/src/linear/index.sh"
. "$NANCY_FRAMEWORK_ROOT/src/cmd/start.sh"

# ------------------------------------------------------------------------------

task="${1:-ALP-2154}"

parent_issue=$(
	linear::issue "$task"
)

{
	read -r -d '' project_id
	read -r -d '' project_identifier
	read -r -d '' project_title
} < <(jq -j '.data.issue |
	.id, "\u0000",
	.identifier, "\u0000",
	.title, "\u0000"
' <<<"$parent_issue")

_start_create_issues_file "$task" "$project_id" "$project_identifier" "$project_title"

cat "$NANCY_CURRENT_TASK_DIR/ISSUES.md"
