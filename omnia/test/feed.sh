#!/bin/bash
test_path=$(cd "${BASH_SOURCE[0]%/*}"; pwd)
root_path=$(cd "$test_path/.."; pwd)
lib_path="$root_path/lib"
messages_path="$test_path/messages"

. "$lib_path/log.sh"
. "$lib_path/util.sh"
. "$lib_path/config.sh"
. "$lib_path/source.sh"
. "$lib_path/status.sh"
. "$lib_path/feed.sh"

. "$root_path/tap.sh" 2>/dev/null || . "$root_path/../tests/lib/tap.sh"

_config="$test_path/configs/oracle-feed-test.conf"

# Setting up relayer configuration
OMNIA_MODE="FEED"
OMNIA_SRC_TIMEOUT=60
ETH_FROM="0x1f8fbe73820765677e68eb6e933dcb3c94c9b708"
ETH_KEYSTORE="$test_path/../../tests/resources/keys"
ETH_PASSWORD="$test_path/../../tests/resources/password"

importStarkwareEnv

# check configuration requirement before setting everything up
assert "readSourcesAndBroadcastAllPriceMessages should fail without configuration" fail readSourcesAndBroadcastAllPriceMessages

# Setting up config one by one
importAssetPairsEnv "$_config"
assert "readSourcesAndBroadcastAllPriceMessages should fail without OMNIA_FEED_SOURCES configuration" fail readSourcesAndBroadcastAllPriceMessages

importSources "$_config"
assert "readSourcesAndBroadcastAllPriceMessages should fail without OMNIA_TRANSPORTS configuration" fail readSourcesAndBroadcastAllPriceMessages

importTransports "$_config"

assert "readSource should fail on incorrect source" fail readSource "json" "BAT/USD"

# validateAndConstructMessage
_assetPair="BAT/USD"
_json=$(jq -c '.asset = "'$_assetPair'"' "$messages_path/setzer.json")
_median=$(jq -r .median <<<"$_json")
_sources=$(jq -rS '.sources' <<<"$_json")

assert "validateAndConstructMessage should fail on incorrect median" fail validateAndConstructMessage "$_assetPair" "a" "$_sources"

assert "validateAndConstructMessage correctly constracts message" run_json validateAndConstructMessage "$_assetPair" "$_median" "$_sources"
assert "type should be BATUSD" json '.type' <<<'"BATUSD"'
assert "price should be 0.2" json '.price' <<<"0.2"
assert "priceHex should be valid" json '.priceHex' <<<'"00000000000000000000000000000000000000000000000002c68af0bb140000"'

# readSourcesAndBroadcastAllPriceMessages

transportPublish() {
	return 1
}
export -f transportPublish

readSource() {
	printf ""
}
export -f readSource

assert "readSourcesAndBroadcastAllPriceMessages should run without calling for transportPublish on empty source msg" \
	run readSourcesAndBroadcastAllPriceMessages

readSource() {
	printf "{"
}
export -f readSource
assert "readSourcesAndBroadcastAllPriceMessages should run without calling for transportPublish on invalid JSON source msg" \
	run readSourcesAndBroadcastAllPriceMessages

readSource() {
	printf "{}"
}
export -f readSource
assert "readSourcesAndBroadcastAllPriceMessages should run without calling for transportPublish on empty JSON object source msg" \
	run readSourcesAndBroadcastAllPriceMessages

readSource() {
	jq -c '.asset = "'$2'"' "$messages_path/setzer.json"
}
export -f readSource
transportPublish() {
	return 0
}
export -f transportPublish
assert "readSourcesAndBroadcastAllPriceMessages should run without calling for transportPublish on empty JSON object source msg" \
	run readSourcesAndBroadcastAllPriceMessages