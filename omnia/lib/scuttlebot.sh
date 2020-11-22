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

#pull latest message from feed
pullLatestFeedMsg() {
	local _feed="$1"
	local _rawMsg
	_rawMsg=$(ssb-server getLatest "$_feed")
	[[ $? != 0 ]] || [[ $_rawMsg == false ]] || [[ -z $_rawMsg ]] && error "Error - Failed to retrieve latest message" && return
	echo "$_rawMsg" | jq -S '{author: .value.author, version: .value.content.version, time: .value.content.time, timeHex: .value.content.timeHex, msgID: .key, previous: .value.previous, type: .value.content.type, price: .value.content.price, priceHex: .value.content.priceHex, signature: .value.content.signature}'
}

#pull previous message
pullPreviousFeedMsg() {
    local _prev="$1"
    [[ -z "$_prev" ]] || [[ "$_prev" =~ ^(%){1}[0-9a-zA-Z+/]{43}$ ]] && error "Error - Invalid previous msg id" && return
    ssb-server get "$_prev" | jq -S '{author: .author, version: .content.version, time: .content.time, timeHex: .content.timeHex, previous: .previous, type: .content.type, price: .content.price, priceHex: .content.priceHex, signature: .content.signature}'
}

#optimized message search algorithm
pullLatestFeedMsgOfType() {
	local	_feed=$1
	local	_assetPair=${2/\/}
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
