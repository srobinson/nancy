#!/usr/bin/env bash
# shellcheck disable=SC1091
# ------------------------------------------------------------------------------

gql::client::query() {
	local query=$1
	curl -s -X POST \
		-H "Content-Type: application/json" \
		-H "Authorization: $LINEAR_API_KEY" \
		--data "$query" \
		https://api.linear.app/graphql
}

# ------------------------------------------------------------------------------

gql::query::generate() {
	local query=$1
	local variables=${2:-}
	[ -f "$query" ] || {
		echo "gql::error File not found: $query"
	}
	[ -n "$variables" ] || {
		variables="{}"
	}
	query=$(
		jq -n \
			--arg query "$(tr -d '\n' <"$query")" \
			--argjson variables "$variables" \
			'
      {
          query: $query,
          $variables
      }
    '
	)
	echo "$query"
}

gql::query::variables() {
	local i=0
	local key
	local value
	local var
	local variables
	variables="{"
	for var in "$@"; do
		((i++))
		key=${var%%::*}
		value=${var#*::}
		# if key starts-with [!] - do not quote value
		if [ "${key::1}" == "!" ]; then
			variables+="\"${key:1}\":$value"
		else
			# Use jq to properly escape the value for JSON
			local escaped_value
			escaped_value=$(jq -n --arg val "$value" '$val')
			variables+="\"$key\":$escaped_value"
		fi
		if [[ $i -lt $# ]]; then
			variables+=","
		fi
	done
	variables+="}"
	echo "$variables"
}

# ------------------------------------------------------------------------------

gql:rate-limit() {
	local query
	query=$(
		gql::query::generate gql/rate-limit.gql
	)
	gql::client::query "$query" | jq '.data.rateLimit'
}
