#!/bin/bash
tpath="$(cd ${0%/*}; pwd)"
. "$tpath/../log.sh"
. "$tpath/../util.sh"
. "$tpath/../status.sh"
. "$tpath/../source.sh"

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
		*BAT/USD*) cat "$tpath/gofer-batusd-resp.json";;
		*) return 1;;
	esac
}
export -f gofer

OMNIA_SRC_TIMEOUT=60

. "$tpath/../tap.sh" 2>/dev/null || . "$tpath/../../smoke-tests/tap.sh"

validSources=()
validPrices=()
median=0
assert "read sources from setzer" run readSourcesWithSetzer batusd
assert "length of validSources" test 3 = ${#validSources[@]}
assert "length of validPrices" test 3 = ${#validPrices[@]}
assert "median of validPrices" test 0.2 = "$median"

validSources=()
validPrices=()
median=0
assert "read sources from gofer" run readSourcesWithGofer BAT/USD
assert "length of validSources" test 9 = ${#validSources[@]}
assert "length of validPrices" test 9 = ${#validPrices[@]}
assert "median of validPrices" test 0.2 = "$median"
