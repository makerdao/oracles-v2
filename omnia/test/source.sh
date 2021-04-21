#!/bin/bash
test_path=$(cd "${BASH_SOURCE[0]%/*}"; pwd)
root_path=$(cd "$test_path/.."; pwd)
lib_path="$root_path/lib"

. "$lib_path/log.sh"
. "$lib_path/util.sh"
. "$lib_path/status.sh"
. "$lib_path/source.sh"

# Mock setzer
setzer() {
	case "$1-$2-$3" in
		sources-batusd-) printf "a\nb\nc\n";;
		price-batusd-a) echo 0.1;;
		price-batusd-b) echo 0.2;;
		price-batusd-c) echo 0.3;;
		*) return 1;;
	esac
}
export -f setzer

# Mock gofer
gofer() {
	case "$*" in
		*BAT/USD*) cat "$test_path/messages/gofer-batusd-resp.json";;
		*) return 1;;
	esac
}
export -f gofer

OMNIA_SRC_TIMEOUT=60

. "$root_path/tap.sh" 2>/dev/null || . "$root_path/../tests/lib/tap.sh"

assert "read sources from setzer" run_json readSourcesWithSetzer BAT/USD
assert "length of sources" json -s '.[].sources|length' <<<"3"
assert "median" json -s '.[].median' <<<"0.2"

assert "read sources from gofer" run_json readSourcesWithGofer BAT/USD
assert "length of sources" json -s '.[].sources|length' <<<"5"
assert "median" json -s '.[].median' <<<"0.2"
