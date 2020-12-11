#!/usr/bin/env bash
TEST_PATH=$(cd "${BASH_SOURCE[0]%/*}" && pwd)
bin_path="$TEST_PATH/../bin"

export TEST_PATH
export TEST_SET_NON_STALE_MESSAGES

timestamp() {
	echo $(($(date +%s)+$1))
}
export -f timestamp

# Mock ssb-server
export wdir
ssb-server() {
	case "$1" in
		whoami)
			echo '{"id":"f33d1d"}'
			;;
		publish)
			cat > $wdir/output
			;;
		createUserStream)
			if [[ $TEST_SET_NON_STALE_MESSAGES ]]; then
				jq ".[].value.content *= {time:$(timestamp -1000),price:0.223} | .[]" "$TEST_PATH/ssb-messages.json"
			else
				jq ".[].value.content.time=$(timestamp -2000) | .[]" "$TEST_PATH/ssb-messages.json"
			fi
			;;
	esac
}
export -f ssb-server

#export OMNIA_VERBOSE="true"
export OMNIA_VERSION="dev-test"
export OMNIA_CONFIG="$TEST_PATH/oracle-transporter-ssb-omnia.conf"
export ETH_FROM="0x1f8fbe73820765677e68eb6e933dcb3c94c9b708"
export ETH_KEYSTORE="$TEST_PATH/../../tests/resources/keys"
export ETH_PASSWORD="$TEST_PATH/../../tests/resources/password"

. "$TEST_PATH/../tap.sh" 2>/dev/null || . "$TEST_PATH/../../tests/lib/tap.sh"

currentTime=$(timestamp 0)

"$bin_path"/oracle-transporter-ssb pull f33d1d BTC/USD > $wdir/output
assert "pulled price message" json '.type' <<<'"BTCUSD"'

echo '{}' > $wdir/output
assert "broadcast price message" run "$bin_path"/oracle-transporter-ssb publish '{"hash":"AB","price":0.222,"priceHex":"ABC","signature":"CD","sources":{"s1":"0.1","s2":"0.2","s3":"0.3"},"time":'$currentTime',"timeHex":"DEF","type":"BTCUSD","version":"dev-test"}'
assert "verify the broadcast message" json . <<<'{"price":0.222,"hash":"AB","priceHex":"ABC","signature":"CD","sources":{"s1":"0.1","s2":"0.2","s3":"0.3"},"time":'$currentTime',"timeHex":"DEF","type":"BTCUSD","version":"dev-test"}'

TEST_SET_NON_STALE_MESSAGES=1
echo '{}' > $wdir/output
#assert "broadcast message with non-stale latest message" run "$bin_path"/oracle-transporter-ssb publish '{"hash":"AB","price":0.222,"priceHex":"ABC","signature":"CD","sources":{"s1":"0.1","s2":"0.2","s3":"0.3"},"time":'$currentTime',"timeHex":"DEF","type":"BTCUSD","version":"dev-test"}'
assert "no broadcast should have been done" json '.' <<<'{}'
