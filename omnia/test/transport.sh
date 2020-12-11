#!/bin/bash
test_path=$(cd "${BASH_SOURCE[0]%/*}"; pwd)
root_path=$(cd "$test_path/.."; pwd)
lib_path="$root_path/lib"

. "$lib_path/log.sh"
. "$lib_path/transport.sh"

# Mock setzer
transport-mock() {
	case "$1" in
		publish)
			echo "$2" >> $wdir/output
			;;
		pull)
			cat "$test_path/transport-message.json"
			;;
		*) return 1;;
	esac
}
export -f transport-mock

transport-mock-other() {
	case "$1" in
		publish)
			jq '.time += 10' <<<"$2" >> $wdir/output
			;;
		*) return 1;;
	esac
}
export -f transport-mock-other

transport-mock-latest() {
	case "$1" in
		pull)
			jq '.time += 10' "$test_path/transport-message.json"
			;;
		*) return 1;;
	esac
}
export -f transport-mock-latest

transport-mock-fail() {
	return 1
}
export -f transport-mock-fail

OMNIA_SRC_TIMEOUT=60
transportMessage="$(jq -c . "$test_path/transport-message.json")"

. "$root_path/tap.sh" 2>/dev/null || . "$root_path/../tests/lib/tap.sh"

rm -f $wdir/output
OMNIA_TRANSPORTS=(transport-mock)
assert "publish to transport" run transportPublish "BTC/USD" "$transportMessage"
assert "type should be BTCUSD" json '.type' <<<'"BTCUSD"'
assert "time should be set" json '.time' <<<"1607032851"

rm -f $wdir/output
OMNIA_TRANSPORTS=(transport-mock transport-mock-other)
assert "publish to two transports" run transportPublish "BTC/USD" "$transportMessage"
assert "type should be two BTCUSD" json -s '[.[].type]' <<<'["BTCUSD","BTCUSD"]'
assert "time should be separate times " json -s '[.[].time]' <<<"[1607032851,1607032861]"

OMNIA_TRANSPORTS=(transport-mock-fail)
assert "should fail if transport exits non-zero" fail transportPublish "BTC/USD" "$transportMessage"

OMNIA_TRANSPORTS=(transport-mock transport-mock-latest)
assert "pull message from two transports" run_json transportPull f33d1d "BTC/USD"
assert "type should be BTCUSD" json '.type' <<<'"BTCUSD"'
assert "time should be from latest message" json '.time' <<<"1607032861"
