#!/bin/bash
test_path=$(cd "${BASH_SOURCE[0]%/*}"; pwd)
root_path=$(cd "$test_path/.."; pwd)
lib_path="$root_path/lib"

. "$lib_path/log.sh"
. "$lib_path/util.sh"
. "$lib_path/status.sh"

. "$root_path/tap.sh" 2>/dev/null || . "$root_path/../tests/lib/tap.sh"

declare -gA assetInfo
assetInfo["BTCUSD"]="1800,0.5"

transportMessage="$(jq -c . "$test_path/messages/transport-message.json")"

# isAssetPair
assert "isAssetPair returns true for 'BTC/USD' pair" match "true" < <(capture isAssetPair "BTC/USD" $transportMessage)

_json=$(jq -c '.type = "BTCUSDX"' <<<"$transportMessage")
assert "isAssetPair returns false for invalid pair" match "false" < <(capture isAssetPair "BTC/USD" $_json)

# isMsgExpired
_json=$(jq -c '.time = -1607032851' <<<"$transportMessage")
assert "isMsgExpired returns true for invalid time less than 0" match "true" < <(capture isMsgExpired "BTC/USD" $_json)

_json=$(jq -c '.time = "123321"' <<<"$transportMessage")
assert "isMsgExpired returns true for invalid time type" match "true" < <(capture isMsgExpired "BTC/USD" $_json)

_json=$(jq -c '.time = 1607032851.2' <<<"$transportMessage")
assert "isMsgExpired returns true for float time" match "true" < <(capture isMsgExpired "BTC/USD" $_json)

_json=$(jq -c '.time = 0607032851' <<<"$transportMessage")
assert "isMsgExpired returns true for time starting from 0" match "true" < <(capture isMsgExpired "BTC/USD" $_json)

_json=$(jq -c '.time = 1607032851' <<<"$transportMessage")
assert "isMsgExpired returns true for old time" match "true" < <(capture isMsgExpired "BTC/USD" $_json)

_curTime=$(timestampS)
_json=$(jq -c '.time = '"$_curTime" <<<"$transportMessage")
assert "isMsgExpired returns false for current time" match "false" < <(capture isMsgExpired "BTC/USD" $_json)

#isPriceValid
assert "isPriceValid returns false for non numeric price" match "false" < <(capture isPriceValid a)
assert "isPriceValid returns false for invalid price" match "false" < <(capture isPriceValid .1)
assert "isPriceValid returns true for valid price" match "true" < <(capture isPriceValid 1.1)

OMNIA_MODE="RELAYER"
assetInfo["BTCUSD"]="0xxxxx,0.5,15500,1800"

# getOracleSpread
assert "getOracleSpread gets correctly oracle spread" match "1800" < <(capture getOracleSpread "BTCUSD")

# isOracleStale
pullOraclePrice() {
	printf "1"
}
export -f pullOraclePrice
assert "isOracleStale returns false for non staled contract" match "false" < <(capture isOracleStale "BTC/USD" 1)
assert "isOracleStale returns true for staled contract" match "true" < <(capture isOracleStale "BTC/USD" 1802)

pullOraclePrice() {
	printf "a"
}
export -f pullOraclePrice
assert "pullOraclePrice should fail if transport returns incorrect price" fail isOracleStale "BTC/USD" 1

assetInfo["BTCUSD"]="0xxxxx,0.5,15500,abs"
assert "pullOraclePrice should fail if transport returns incorrect spread" fail isOracleStale "BTC/USD" 1

# isOracleExpired
pullOracleTime() {
	printf "a"
}
export -f pullOracleTime
assert "isOracleExpired should fail if oracle time is incorrect" fail isOracleExpired "BTC/USD"

pullOracleTime() {
	return 1
}
export -f pullOracleTime
assert "isOracleExpired should fail if pullOracleTime fails" fail isOracleExpired "BTC/USD"

assetInfo["BTCUSD"]="0xxxxx,0.5,1,1800"

pullOracleTime() {
	printf "1615917609"
}
export -f pullOracleTime
assert "isOracleExpired should return true it actually expired" match "true" < <(capture isOracleExpired "BTC/USD")

assetInfo["BTCUSD"]="0xxxxx,0.5,aaa,1800"
assert "isOracleExpired should fail on incorrect expiration" fail isOracleExpired "BTC/USD"

assetInfo["BTCUSD"]="0xxxxx,0.5,10,1800"
pullOracleTime() {
	printf $(timestampS)
}
export -f pullOracleTime
assert "isOracleExpired should return false on non expired oracle" match "false" < <(capture isOracleExpired "BTC/USD")

# isMsgNew

pullOracleTime() {
	printf "a"
}
export -f pullOracleTime
assert "isMsgNew should fail if oracle returned invalid time" fail isMsgNew "BTC/USD" '{"time":1}'

pullOracleTime() {
	printf "1615917609"
}
export -f pullOracleTime
assert "isMsgNew should fail if passed msg does not have time field" fail isMsgNew "BTC/USD" "{}"
assert "isMsgNew should fail if passed msg is invalid JSON" fail isMsgNew "BTC/USD" "{"
assert "isMsgNew should fail if passed time in msg is invalid" fail isMsgNew "BTC/USD" '{"time":"123"}'

assert "isMsgNew should return false on same time" match "false" < <(capture isMsgNew "BTC/USD" '{"time":1}')
assert "isMsgNew should return true if msg time is greater" match "true" < <(capture isMsgNew "BTC/USD" '{"time":1615917610}')