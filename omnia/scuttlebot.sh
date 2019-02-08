#!/usr/bin/env bash

#get id of scuttlebot peer
getFeedId () {
	local _id
	_id=$("$HOME"/scuttlebot/bin.js whoami 2> /dev/null | jq '.id')
	sed -e 's/^"//' -e 's/"$//' <<<"$_id"
}

#not functional yet
#not needed until we start having watchdog peers policing Oracle activity
pullMessages () {
    #this id used for pulling all messages from all feeds with in-bounds timestamp
    #returns an array of objects containg only relevant info
    #breaks up that array into nested subarrays by feed
    local _type=$1
    local _after=$2
    local _limit=$3
    #TODO pass args into jq
    "$HOME"/scuttlebot/bin.js logt --type "$_type" | jq -S 'select(.value.content.time >= 1536082440) | {author: .value.author, time: .value.timestamp, price: .value.content.median}' | jq -s 'group_by(.author)'
}

#pull latest message from feed
pullLatestFeedMsg () {
	local _feed="$1"
    local _rawMsg
    _rawMsg=$("$HOME"/scuttlebot/bin.js getLatest "$_feed")
    [[ $? -gt 0 ]] || [[ -z "$_rawMsg" ]] && error "Error - Error retrieving latest message" && return
    echo "$_rawMsg" | jq -S '{author: .value.author, version: .value.content.version, time: .value.content.time, time0x: .value.content.time0x, msgID: .key, previous: .value.previous, type: .value.content.type, price: .value.content.median, price0x: .value.content.median0x, signature: .value.content.signature}' 
}

#pull previous message
pullPreviousFeedMsg () {
    local _prev
    #trim quotes from prev key
    _prev=$(sed -e 's/^"//' -e 's/"$//' <<<"$@")
    [[ -z "$_prev" ]] || [[ "$_prev" =~ ^(%){1}[0-9a-zA-Z+/]{43}$ ]] && error "Error - Invalid previous msg id" && return
    "$HOME"/scuttlebot/bin.js get "$_prev" | jq -S '{author: .author, version: .content.version, time: .content.time, time0x: .content.time0x, previous: .previous, type: .content.type, price: .content.median, price0x: .content.median0x, signature: .content.signature}'
}

#pull latest message of type _ from feed
pullLatestFeedMsgOfType () {
	local _feed=$1
	local _assetPair=$2
    local _counter=0
    local _msg
    #get latest message from feed
    _msg=$( pullLatestFeedMsg "$_feed" )
    verbose "latest message = $_msg"
    [[ -z "$_msg" ]] && return 

    #if message does not contain a price, get the previous message until we find one that does
    while (( _counter < 10 )) && [[ $(isAssetPair "$_assetPair" "$_msg") == "false" ]]; do
        #clear previous key
        local _key=""
        #get key of previous message
        _key=$( echo "$_msg" | jq '.previous' )
        #clear previous message
        _msg=""
        #stop looking if no more messages
        [[ $_key == "null" ]] && break
        #grab previous message
        _msg=$( pullPreviousFeedMsg "$_key" )
        verbose "previous message = $_msg"
        #increment message counter
        _counter=$(( _counter + 1 ))
    done
	echo "$_msg"
}

#publish price  to scuttlebot
broadcastPriceMsg () {
    local _assetPair="$1"
    local _median="$2"
    local _medianHex="$3"
    local _time="$4"
    local _timeHex="$5"
    local _hash="$6"
    local _signature="$7"
    local _sourcePrices
    local _jqArgs=()
    local _json

    #generate JSON for transpose of sources with prices
    verbose Constructing message...  
    _sourcePrices=$(jq -nce --argjson vs "$(printf '%s\n' "${validSources[@]}" | jq -nR '[inputs]')" --argjson vp "$(printf '%s\n' "${validPrices[@]}" | jq -nR '[inputs]')" '[$vs, $vp] | transpose | map({(.[0]): .[1]}) | add')
    [[ $? -gt 0 ]] && error "Error - failed to transpose sources with prices" && return

    _jqArgs=( "--arg assetPair $_assetPair" "--arg version $OMNIA_VERSION" "--arg median $_median" "--arg medianHex $_medianHex" "--arg time $_time" "--arg timeHex $_timeHex" "--arg hash ${_hash:2}" "--arg signature ${_signature:2}" "--argjson sourcePrices $_sourcePrices" )

    #debug
    verbose "${_jqArgs[*]}"

    #generate JSON msg
    # shellcheck disable=2068
    _json=$(jq -ne ${_jqArgs[@]} '{type: $assetPair, version: $version, median: $median | tonumber, medianHex: $medianHex, time: $time | tonumber, timeHex: $timeHex, hash: $hash, signature: $signature, sources: $sourcePrices}')
    [[ $? -gt 0 ]] && error "Error - failed to generate JSON msg" && return
    
    #debug
    verbose "$_json"

    #publish msg to scuttlebot
    log "Publishing new price message..."
    echo "$_json" | "$HOME"/scuttlebot/bin.js publish .
}