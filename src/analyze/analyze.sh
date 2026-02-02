#!/usr/bin/env bash
# b_path:: src/analyze/analyze.sh
# Nancy log analyzer — compare experiment conditions
# Usage: source analyze.sh && analyze::run <control_log_dir> <treatment_log_dir> [--json]
# Not yet wired into the main nancy CLI dispatcher.
# ------------------------------------------------------------------------------

set -euo pipefail

analyze::run() {
	local control_dir="${1:-}"
	local treatment_dir="${2:-}"
	shift 2 || true

	if [[ -z "$control_dir" || -z "$treatment_dir" ]]; then
		echo "Usage: analyze::run <control_log_dir> <treatment_log_dir> [--json]" >&2
		exit 1
	fi

	python3 -m src.analyze "${control_dir}" "${treatment_dir}" "$@"
}
