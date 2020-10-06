#!/bin/bash

tpath="$(cd ${0%/*}; pwd)"
. "$tpath/../log.sh"
. "$tpath/../util.sh"
. "$tpath/../source.sh"
. "$tpath/../status.sh"
. "$tpath/../feed.sh"
. "$tpath/../scuttlebot.sh"
. "$tpath/_mocks.sh"

. "$tpath/../../smoke-tests/tap.sh"
wdir="${wdir:-$tpath}"

OMNIA_VERSION="1.3.9-dev"
OMNIA_FEED_SOURCE="gofer"

assert "read sources and broadcast" run readSourceAndBroadcastPriceMessage "MKR/USD"
assert "ssb message .type" json ".type" <<<'"MKR/USD"'
