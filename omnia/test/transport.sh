#!/bin/bash
test_path=$(cd "${BASH_SOURCE[0]%/*}"; pwd)
root_path=$(cd "$test_path/.."; pwd)
lib_path="$root_path/lib"

. "$lib_path/log.sh"
. "$lib_path/transport.sh"

# Mock setzer
transport-mock() {
	echo >&2 "$@"
	case "$1" in
		publish)
			echo >&2 "$3"
			echo "$3" > $wdir/output
			;;
		pull)
			cat "$test_path/transport-message.json"
			;;
		*) return 1;;
	esac
}
export -f transport-mock

transport-mock-fail() {
	return 1
}

OMNIA_SRC_TIMEOUT=60
OMNIA_FEED_PUBLISHERS=(transport-mock)
OMNIA_MESSAGE_PULLERS=(transport-mock)

. "$root_path/tap.sh" 2>/dev/null || . "$root_path/../tests/lib/tap.sh"

assert "read sources from setzer" run transportPublish "$(cat "$test_path/transport-message.json")"
assert "length of sources" json '.type' <<<'"BTCUSD"'
assert "median" json '.median' <<<"0.2"

assert "read sources from setzer" run transportPublish "$(cat "$test_path/transport-message.json")"
assert "length of sources" json '.type' <<<'"BTCUSD"'
assert "median" json '.median' <<<"0.2"
