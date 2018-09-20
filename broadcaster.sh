#!/usr/bin/env bash
EXPIRYINTERVAL=600000
MAXSPREAD=2

declare -a assets=("eth" "mkr" "rep" "poly")

#pull price data of asset from source
getPriceFromSource () {
	local _asset=$1
	local _source=$2
	local _price
	_price=$(timeout 5 setzer price "$_asset"-"$_source" 2> /dev/null)
	printf "\\t%s = %s\\n" "$_source" "$_price"
	if [[ $_price =~ ^[+-]?[0-9]+\.?[0-9]*$  ]]; then
		validSources+=( "$_source" )
		validPrices+=( "$_price" )
	fi
}

#read price data of asset
readSources () {
	local _asset="$1"
	mapfile -t _sources < <(setzer sources "$_asset")
	if [[ "${#_sources[@]}" -ne 0 ]]; then
		for source in "${_sources[@]}"; do
			getPriceFromSource "$_asset" "$source"
		done
	fi
}

#get median of  a list of numbers
getMedian () {
	prices=( "$@" )
	tr " " "\\n" <<< "${prices[@]}" | datamash median 1
}

#get id of scuttlebot peer
getFeedId () {
	local _id
	_id=$(/home/nkunkel/scuttlebot/bin.js whoami | jq '.id')
	sed -e 's/^"//' -e 's/"$//' <<<"$_id"
}

#pull latest message from feed
pullLatestFeedMsg () {
	local _feed="$1"
    /home/nkunkel/scuttlebot/bin.js getLatest "$_feed" | jq -S '{author: .value.author, time: .value.timestamp, msgID: .key, previous: .value.previous, type: .value.content.type, price: .value.content.median}' 
}

pullPreviousFeedMsg () {
    #trim quotes from prev key
    local _prev
    _prev=$(sed -e 's/^"//' -e 's/"$//' <<<"$@")
    /home/nkunkel/scuttlebot/bin.js get "$_prev" | jq -S '{author: .author, time: .timestamp, previous: .previous, type: .content.type, price: .content.median}'
}

#pull latest price message from feed
pullLatestFeedMsgType () {
	local _feed=$1
	local _asset=$2
    local _counter=0
    local _msg
    #get latest message from feed
    _msg=$( pullLatestFeedMsg "$_feed" )
    #if message does not contain a price, get the previous message until we find one that does
    while (( _counter < 10 )) && [[ $(isAssetType "$_asset" "$_msg") == "false" ]]; do
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
        #increment message counter
        _counter=$(( _counter + 1 ))
    done
	echo "$_msg"
}

#get unix timestamp
timestamp () {
    date +"%s%3N"
}

#is message expired
isExpired () {
	local _msg="$1"
	local _curTime
	_curTime=$(timestamp)
	local expiryTime=$(( _curTime - EXPIRYINTERVAL ))
	[ "$(echo "$_msg" | jq '.time')" -lt "$expiryTime" ] && echo "Previous price is expired" >&2 && echo true || echo false
}

#is message of type asset
isAssetType () {
	local _assetType="$1"
	local _msg="$2"
	[ "$(echo "$_msg" | jq --arg _assetType "$_assetType" '.type == $_assetType')" == "true" ] && echo true || echo false
}

#is price significantly different from previous price
isPriceStale () {
	local _msg=$1
	local _newPrice="$2"
	local _oldPrice
	local _spread
	_oldPrice=$(echo "$_msg" | jq '.price')
	_spread=$(setzer spread "$_oldPrice" "$_newPrice")
	#echo "Old Price = $_oldPrice vs New Price = $_newPrice -> spread = $_spread" >&2
	printf "\\tOld Price = %s\\n\\tNew Price = %s\\n-> spread = %s\\n" "$_oldPrice" "$_newPrice" "$_spread" >&2
	test=$(bc <<< "${_spread#-} >= ${MAXSPREAD}")
	[[ ${test} -ne 0 ]] && echo true || echo false
}

#sign message - this is just a placeholder
signMessage () {
    echo -n "$1" "$2" "$3" "$4" "$5" | sha256sum
}

#init/clear price and source data
initStorage () {
	validSources=()
	validPrices=()
}

#publish price  to scuttlebot
broadcastPrices () {
	local _assetType="$1"
	local _time="$2"
	local _median="$3"
	cmd="/home/nkunkel/scuttlebot/bin.js publish --type $_assetType --time $_time --median $_median"
	[[ "${#validSources[@]}" != "${#validPrices[@]}" ]] && echo "error: number of sources doesn't match number of prices" && exit 1
	for index in ${!validSources[*]}; do
		cmd+=" --${validSources[index]} ${validPrices[index]}"
	done
	eval "$cmd"
}

#publish new price messages for all assets
execute () {
	for asset in "${assets[@]}"; do
		printf "\\nQuerying %s prices...\\n" "${asset^^}"
		initStorage 
		readSources "$asset"
		median=$(getMedian "${validPrices[@]}")
		echo "-> median = $median" >&2
		time=$(timestamp)
		feed=$(getFeedId)
		latestMsg=$(pullLatestFeedMsgType "$feed" "$asset")
		if [ -z "${latestMsg}" ] || [ "$(isAssetType "$asset" "$latestMsg")" == "false" ] || [ "$(isExpired "$latestMsg")" == "true" ] || [ "$(isPriceStale "$latestMsg" "$median")" == "true" ]; then
			echo "Submitting new price message..."
			broadcastPrices "$asset" "$time" "$median" "${validSources[@]}" "${validPrices[@]}"
		fi
	done
}

execute
