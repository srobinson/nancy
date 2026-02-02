#!/usr/bin/env bash

token::reset() {
	local usage_file="token-usage.json"

	# If the file exists, back it up with incrementing number
	if [[ -f "$usage_file" ]]; then
		local backup_num=0
		local backup_file

		# Find next available backup number
		while true; do
			backup_file="${usage_file%.json}.$(printf '%02d' $backup_num).json"
			if [[ ! -f "$backup_file" ]]; then
				break
			fi
			((backup_num++))
		done

		# Move existing file to backup
		mv "$usage_file" "$backup_file"
	fi
}

token::reset
