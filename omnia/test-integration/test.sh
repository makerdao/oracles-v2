#!/usr/bin/env bash
set -e

function fullPath() {
	[[ $1 == /*  ]] && echo "$1" || echo "$PWD/${1#./}"
}

_HERE="$(dirname "$(fullPath "$0")")"
_TOP="$(dirname "$(dirname "${_HERE}")")"

gofer() {
	local _pwd=$PWD
	cd "$(dirname "${_TOP}")/gofer"
	go run "./cmd/gofer" "$@"
	cd "$_pwd"
}

ethsign() {
	local _pwd=$PWD
	cd "$(dirname "${_TOP}")/dapptools/src/ethsign"
	go run "./ethsign.go" "$@"
	cd "$_pwd"
}

ssb-server() {

}

_OMNIA="$_TOP/omnia"
# shellcheck source=../../omnia/log.sh
. "$_OMNIA/log.sh"
# shellcheck source=../../omnia/util.sh
. "$_OMNIA/util.sh"
# shellcheck source=../../omnia/source.sh
. "$_OMNIA/source.sh"
# shellcheck source=../../omnia/status.sh
. "$_OMNIA/status.sh"
# shellcheck source=../../omnia/scuttlebot.sh
. "$_OMNIA/scuttlebot.sh"
# shellcheck source=../../omnia/feed.sh
. "$_OMNIA/feed.sh"

function pullLatestFeedMsgOfType {
	echo "{\"$0\": \"$1 $2\"}"
}

OMNIA_VERBOSE="true"
OMNIA_VERSION="1.3.9-dev"
OMNIA_FEED_SOURCE="gofer"

median=0
validSources=()
validPrices=()
assetPairs=("MKR/USD")

. "$_HERE/eth.local.sh"

readSourcesAndBroadcastAllPriceMessages
