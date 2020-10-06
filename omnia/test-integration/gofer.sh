#!/bin/bash
set -e

tpath="$(cd ${0%/*}; pwd)"

. "$tpath/_init.sh"
. "$tpath/_mocks.sh"

OMNIA_FEED_SOURCES=("gofer")
assetPairs=("MKR/USD")

#. "$tpath/../../smoke-tests/tap.sh"
#assert "read sources and broadcast" run readSourcesAndBroadcastAllPriceMessages
#assert "ssb message .type" json ".type" <<< '"MKR/USD"'

readSourcesAndBroadcastAllPriceMessages
cat "$tpath/output" && rm "$tpath/output"