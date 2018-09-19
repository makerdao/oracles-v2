#!/usr/bin/env bash
EXPIRYINTERVAL=600000
MAXSPREAD=2


declare -a assets=("ETH")
declare -a sources=("bitstamp" "gdax" "gemini" "kraken")

#pull price from source
getPrice () {
	local _asset=$1
	local _source=$2
	local _price=$(timeout 5 setzer price "$_source" 2> /dev/null)
	if [[ $_price =~ ^[+-]?[0-9]+\.?[0-9]*$  ]]; then
		validSources+=( "$_source" )
		validPrices+=( "$_price" )
	fi
}

readSources () {
	local _asset="$1"
	for source in "${sources[@]}"; do
		getPrice "$_asset" "$source"
	done
}

#get median of  a list of numbers
getMedian () {
	prices=( "$@" )
	tr " " "\\n" <<< "${prices[@]}" | datamash median 1
}

getFeedId () {
	local _id=$(/home/nkunkel/scuttlebot/bin.js whoami | jq '.id')
	sed -e 's/^"//' -e 's/"$//' <<<"$_id"
}

#pull latest message from feed
pullLatestFeedMsg () {
	local _feed="$1"
    /home/nkunkel/scuttlebot/bin.js getLatest "$_feed" | jq -S '{author: .value.author, time: .value.timestamp, msgID: .key, previous: .value.previous, type: .value.content.type, price: .value.content.median}' 
}

pullPreviousFeedMsg () {
    #trim quotes from prev key
    local _prev=$(sed -e 's/^"//' -e 's/"$//' <<<"$@")
    echo "Prev msg id = $_prev" >&2
    /home/nkunkel/scuttlebot/bin.js get "$_prev" | jq -S '{author: .author, time: .timestamp, previous: .previous, type: .content.type, price: .content.median}'
}

#pull latest price message from feed
pullLatestFeedMsgType () {
	local _feed=$1
	local _asset=$2
    local _counter=0
    #get latest message from feed
    local _msg=$( pullLatestFeedMsg "$_feed" )
	#DEBUG
	echo "[pullLatestFeedMsgType] msg = $_msg" >&2
    #if message does not contain a price, get the previous message until we find one that does
    while (( _counter < 10 )) &&  [[ $(isAssetType "$_asset" "$_msg") == "false" ]]; do
        #clear previous key
        local _key=""
        #get key of previous message
        _key=$( echo "$_msg" | jq '.previous' )
        #clear previous message
        _msg=""
        #stop looking if no more messages
        [[ $_key == "null" ]] && break
        #DEBUG
        echo "message is not of type \"$_asset\", querying previous message with key = $_key" >&2
        #grab previous message
        _msg=$( pullPreviousFeedMsg "$_key" )
        #increment message counter
        _counter=$(( _counter + 1 ))
        #DEBUG
        echo "[pullLatestFeedMsgType] previous msg = $_msg" >&2
    done
	echo "$_msg"
}

#get unix timestamp
timestamp () {
    date +"%s%3N"
}

isExpired () {
	local _msg="$1"
	local curTime=$(timestamp)
	local expiryTime=$(( curTime - EXPIRYINTERVAL ))
	[ $(echo "$_msg" | jq '.time') -lt "$expiryTime" ] && echo true || echo false
}

isAssetType () {
	local _assetType="$1"
	local _msg="$2"
	[ $(echo "$_msg" | jq --arg _assetType "$_assetType" '.type == "$_assetType"') ] && echo true || echo false
}

isPriceStale () {
	local _msg=$1
	local _newPrice="$2"
	local _oldPrice=$(echo "$_msg" | jq '.price')
	local _spread=$(setzer spread "$_oldPrice" "$_newPrice")
	test=$(bc <<< "${_spread#-} >= ${MAXSPREAD}")
	[[ ${test} -ne 0 ]] && echo "true" || echo "false"
}

#sign message - this is just a placeholder
signMessage () {
    echo -n $1 $2 $3 $4 $5| sha256sum
}

#publish price  to scuttlebot
broadcastPrices () {
	local _assetType="$1"
	local _time="$2"
	local _median="$3"
	cmd="/home/nkunkel/scuttlebot/bin.js publish --type $_assetType --time $_time --median $_median"
	[[ ${#validSources[@]} != ${#validPrices[@]} ]] && exit 1
	for index in ${!validSources[*]}; do
		cmd+=" --${validSources[index]} ${validPrices[index]}"
	done
	eval $cmd
}

execute () {
	for asset in "${assets[@]}"; do
		readSources "$asset"
		median=$(getMedian ${validPrices[@]})
		time=$(timestamp)
		feed=$(getFeedId)
		latestMsg=$(pullLatestFeedMsgType "$feed" "$asset")

		#DEBUG
		[ -z "${latestMsg}" ] && echo "[TRIGGER] LatestMsg is empty" || echo "Latest Msg exists"
		[ $(isExpired "$latestMsg") == "true" ] && echo "[TRIGGER] Latest Msg is Expired" || echo "Latest Msg is Fresh"
		[ $(isAssetType "$asset" "$latestMsg") == "false" ] && echo "[TRIGGER] Latest Msg is NOT of type $asset" || echo "Latest Msg is of type $asset"
		[ $(isPriceStale "$latestMsg" "$median") == "true" ] && echo "[TRIGGER] Latest Msg has a stale price" || echo "Latest Msg has a fresh price"


		if [ -z "${latestMsg}" ] || [ $(isExpired "$latestMsg") == "true" ] || [ $(isAssetType "$asset" "$latestMsg") == "false" ] || [ $(isPriceStale "$latestMsg" "$median") == "true" ]; then
			broadcastPrices $asset $time $median ${validSources[@]} ${validPrices[@]}
		fi
	done
}

execute
