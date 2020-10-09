#!/usr/bin/env bash
set -e

tpath="$(cd ${0%/*}; pwd)"

. "$tpath/_init.sh"
. "$tpath/_mocks.sh"

OMNIA_FEED_SOURCES=("setzer")
assetPairs=("MKR/USD")

. "$tpath/../../smoke-tests/tap.sh"
assert "read sources and broadcast" run readSourcesAndBroadcastAllPriceMessages
assert "ssb message .type" json ".type" <<< '"MKR/USD"'
assert "ssb message .price" json ".price" <<< '523.8932234794577'
assert "ssb message .priceHex" json ".priceHex" <<< '"00000000000000000000000000000000000000000000001c667a9f0c9f6958a0"'
