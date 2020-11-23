#!/usr/bin/env bash

if command -v ssb-server; then
	# ssb-server is in PATH, do nothing
	true
else
	# ssb-server not in PATH add a shim pointing to local install in HOME
	ssb-server() {
		"$HOME"/ssb-server/bin.js "$@"
	}
fi

#get id of scuttlebot peer
getFeedId() {
	ssb-server whoami 2> /dev/null | jq -r '.id'
}

#optimized message search algorithm
pullLatestFeedMsgOfType() {
	local	_feed=$1
	local	_assetPair="$2"
	_assetPair=${_assetPair/\/}
	_assetPair=${_assetPair^^}
	ssb-server createUserStream \
		--id "$_feed" --limit "$OMNIA_MSG_LIMIT" \
		--reverse --fillCache 1 \
	| jq -s --arg pair "$_assetPair" '
		[.[] | select(.value.content.type == $pair)]
		| max_by(.value.content.time)
		| {
			author: .value.author,
			version: .value.content.version,
			time: .value.content.time,
			timeHex: .value.content.timeHex,
			msgID: .key,
			previous: .value.previous,
			type: .value.content.type,
			price: .value.content.price,
			priceHex: .value.content.priceHex,
			signature: .value.content.signature
		}
	'
}

