#!/usr/bin/env bash

if command -v ssb-server; then
	# ssb-server is in PATH, do nothing
	true
else
	# ssb-server not in PATH add a shim pointing to local install in HOME
	ssb-server () {
		"$HOME"/ssb-server/bin.js "$@"
	}
fi

#get id of scuttlebot peer
getFeedId () {
	ssb-server whoami 2> /dev/null | jq -r '.id'
}

#pull latest message from feed
pullLatestFeedMsg () {
	local _feed="$1"
	local _rawMsg
	_rawMsg=$(ssb-server getLatest "$_feed")
	[[ $? != 0 ]] || [[ $_rawMsg == false ]] || [[ -z $_rawMsg ]] && error "Error - Failed to retrieve latest message" && return
	echo "$_rawMsg" | jq -S '{author: .value.author, version: .value.content.version, time: .value.content.time, timeHex: .value.content.timeHex, msgID: .key, previous: .value.previous, type: .value.content.type, price: .value.content.price, priceHex: .value.content.priceHex, signature: .value.content.signature}'
}

#pull previous message
pullPreviousFeedMsg () {
    local _prev="$1"
    [[ -z "$_prev" ]] || [[ "$_prev" =~ ^(%){1}[0-9a-zA-Z+/]{43}$ ]] && error "Error - Invalid previous msg id" && return
    ssb-server get "$_prev" | jq -S '{author: .author, version: .content.version, time: .content.time, timeHex: .content.timeHex, previous: .previous, type: .content.type, price: .content.price, priceHex: .content.priceHex, signature: .content.signature}'
}

#optimized message search algorithm
pullLatestFeedMsgOfType () {
	local	_feed=$1
	local	_assetPair=$2
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
	#error handling
}

#publish price  to scuttlebot
broadcastPriceMsg () {
    local _assetPair="$1"
    local _price="$2"
    local _priceHex="$3"
    local _time="$4"
    local _timeHex="$5"
    local _hash="$6"
    local _signature="$7"
    local _sourcePrices
    local _jqArgs=()
    local _json

    verbose "Constructing message..."
    #generate JSON for transpose of sources with prices
    if ! _sourcePrices=$(jq -nce --argjson vs "$(printf '%s\n' "${validSources[@]}" | jq -nR '[inputs]')" --argjson vp "$(printf '%s\n' "${validPrices[@]}" | jq -nR '[inputs]')" '[$vs, $vp] | transpose | map({(.[0]): .[1]}) | add'); then
        error "Error - failed to transpose sources with prices"
        return
    fi
    #compose jq message arguments
    _jqArgs=( "--arg assetPair $_assetPair" "--arg version $OMNIA_VERSION" "--arg price $_price" "--arg priceHex $_priceHex" "--arg time $_time" "--arg timeHex $_timeHex" "--arg hash ${_hash:2}" "--arg signature ${_signature:2}" "--argjson sourcePrices $_sourcePrices" )
    #debug
    verbose "${_jqArgs[*]}"
    #generate JSON msg
    # shellcheck disable=2068
    if ! _json=$(jq -ne ${_jqArgs[@]} '{type: $assetPair, version: $version, price: $price | tonumber, priceHex: $priceHex, time: $time | tonumber, timeHex: $timeHex, hash: $hash, signature: $signature, sources: $sourcePrices}'); then
        error "Error - failed to generate JSON msg"
        return
    fi
    #debug
    verbose "$_json"
    #publish msg to scuttlebot
    log "Publishing new price message..."
    echo "$_json" | ssb-server publish .
}
