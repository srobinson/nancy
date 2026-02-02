#!/usr/bin/env bash
# b_path:: src/lib/fmt.sh
# ------------------------------------------------------------------------------

fmt::strip_ansi() {
	perl -pe 'BEGIN{$|=1}
  s/\x1b\[[\x20-\x3f]*[\x40-\x7e]//g'
}
