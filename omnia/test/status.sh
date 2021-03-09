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

transportMessage="$(jq -c . "$test_path/transport-message.json")"

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