#!/bin/bash
TEST_PATH=$(cd "${BASH_SOURCE[0]%/*}" && pwd)
bin_path="$TEST_PATH/../bin"

export TEST_PATH
export TEST_SET_NON_STALE_MESSAGES

timestamp() {
	echo $(($(date +%s)+$1))
}
export -f timestamp

# Mock spire
export wdir
spire() {
	case "$1" in
		broadcast-price)
			cat > $wdir/output
			;;
		get-prices)
				jq -c <<\JSON
{
	"wat": "BTCUSD",
	"val": "1.23",
	"age": 1234567890
}
JSON
			;;
	esac
}
export -f spire

. "$TEST_PATH/../tap.sh" 2>/dev/null || . "$TEST_PATH/../../tests/lib/tap.sh"

currentTime=$(timestamp 0)

"$bin_path"/oracle-transporter-spire pull F33D02 BTC/USD > $wdir/output
assert "pulled price message" json '.type' <<<'"BTCUSD"'

echo '{}' > $wdir/output
assert "broadcast price message" run "$bin_path"/oracle-transporter-spire publish '{"hash":"AB","price":0.222,"priceHex":"ABC","signature":"CD","sources":{"s1":"0.1","s2":"0.2","s3":"0.3"},"time":'$currentTime',"timeHex":"DEF","type":"BTCUSD","version":"dev-test"}'
assert "verify the broadcast message" json . <<<'{"price":0.222,"hash":"AB","priceHex":"ABC","signature":"CD","sources":{"s1":"0.1","s2":"0.2","s3":"0.3"},"time":'$currentTime',"timeHex":"DEF","type":"BTCUSD","version":"dev-test"}'
