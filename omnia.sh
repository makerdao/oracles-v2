#!/usr/bin/env bash

declare -a assets=("eth" "mkr" "rep" "poly")

#pull price data of asset from source
getPriceFromSource () {
	local _asset=$1
	local _source=$2
	local _price
	_price=$(timeout 5 setzer price "$_asset"-"$_source" 2> /dev/null)
	verbose "$_source = $_price"
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
	_id=$("$HOME"/scuttlebot/bin.js whoami | jq '.id')
	sed -e 's/^"//' -e 's/"$//' <<<"$_id"
}

#pull latest message from feed
pullLatestFeedMsg () {
	local _feed="$1"
    "$HOME"/scuttlebot/bin.js getLatest "$_feed" | jq -S '{author: .value.author, time: .value.timestamp, msgID: .key, previous: .value.previous, type: .value.content.type, price: .value.content.median}' 
}

pullPreviousFeedMsg () {
    #trim quotes from prev key
    local _prev
    _prev=$(sed -e 's/^"//' -e 's/"$//' <<<"$@")
    "$HOME"/scuttlebot/bin.js get "$_prev" | jq -S '{author: .author, time: .timestamp, previous: .previous, type: .content.type, price: .content.median}'
}

#pull latest price message from feed
pullLatestFeedMsgType () {
	local _feed=$1
	local _asset=$2
    local _counter=0
    local _msg
    #get latest message from feed
    _msg=$( pullLatestFeedMsg "$_feed" )
    verbose "latest message = $_msg"
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
        verbose "previous message = $_msg"
        #increment message counter
        _counter=$(( _counter + 1 ))
    done
	echo "$_msg"
}

#get unix timestamp in ms
timestamp () {
    date +"%s%3N"
}

#is message empty
isEmpty () {
	[ -z "$1" ] && verbose "Cannot find recent message for asset $asset" && echo true || echo false
}

#is message of type asset
isAssetType () {
	local _assetType="$1"
	local _msg="$2"
	[ "$(echo "$_msg" | jq --arg _assetType "$_assetType" '.type == $_assetType')" == "true" ] && echo true || echo false
}

#is message expired
#note that this uses the timestamp on the message itself (which is in ms),
#and NOT the timestamp within the message content (which is in s).
isExpired () {
	local _msg="$1"
	local _curTime
	local _lastTime
	_curTime=$(timestamp)
	_lastTime="$(echo "$_msg" | jq '.time')"
	local _expiryTime=$(( _curTime - OMNIA_EXPIRY_INTERVAL_MS ))
	local _expirationDif=$(( (_curTime - _lastTime - OMNIA_EXPIRY_INTERVAL_MS) / 1000))
	[ "$_lastTime" -lt "$_expiryTime" ] && log "Previous price posted at t = $(( _lastTime / 1000 )) is expired by $_expirationDif seconds" && echo true || echo false
}

#is price significantly different from previous price
isPriceStale () {
	local _msg=$1
	local _newPrice="$2"
	local _oldPrice
	local _spread
	_oldPrice=$(echo "$_msg" | jq '.price')
	_spread=$(setzer spread "$_oldPrice" "$_newPrice")
	log "Old Price = ${_oldPrice}   New Price = ${_newPrice}"
	log "-> spread = $_spread"
	test=$(bc <<< "${_spread#-} >= ${OMNIA_SPREAD}")
	[[ ${test} -ne 0 ]] && log "Spread is greater than ${OMNIA_SPREAD}" && echo true || echo false
}

#convert price to hex
price2Hex() {
	local _price=$1
	#convert price to wei and then uint256
	seth --to-uint256 "$(seth --to-wei "$_price" eth)"
}

#converts blockstamp to hex
time2Hex() {
	local _time=$1
	#convert blockstamp to uint256
	seth --to-uint256 "$_time"

}

#gets keccak-256 hash of 1 or more input arguments
keccak256Hash() {
	local _inputs
	for arg in "$@"; do
		_inputs+="$arg"
	done
	seth keccak "$_inputs"
}

#sign message
signMessage () {
	local _data
	for arg in "$@"; do
		_data+="$arg"
	done
	verbose "Signing message..."
    ethsign message --from "$ETH_FROM" --key-store "$ETH_KEYSTORE" --passphrase-file "$ETH_PASSWORD" --data "$_data"
}

#init/clear price and source data
initStorage () {
	validSources=()
	validPrices=()
}

#publish price  to scuttlebot
broadcastPrices () {
	local _assetType="$1"
	local _median="$2"
	local _medianHex="$3"
	local _time="$4"
	local _timeHex="$5"
	local _hash="$6"
	local _sig="$7"
	cmd="$HOME/scuttlebot/bin.js publish --type $_assetType --median $_median --0xmedian $_medianHex --time $_time --0xtime $_timeHex --hash ${_hash:2} --signature ${_sig:2}"
	[[ "${#validSources[@]}" != "${#validPrices[@]}" ]] && error "Error: number of sources doesn't match number of prices" && exit 1
	for index in ${!validSources[*]}; do
		cmd+=" --${validSources[index]} ${validPrices[index]}"
	done
	log "Submitting new price message..."
	verbose "$cmd"
	verbose "$(eval "$cmd")"
}

#publish new price messages for all assets
execute () {
	for asset in "${assets[@]}"; do
		initStorage
		log "Querying ${asset^^} prices..."
		readSources "$asset"
		median=$(getMedian "${validPrices[@]}")
		verbose "-> median = $median"
		latestMsg=$(pullLatestFeedMsgType "$SCUTTLEBOT_FEED_ID" "$asset")
		if [ "$(isEmpty "$latestMsg")" == "true" ] || [ "$(isAssetType "$asset" "$latestMsg")" == "false" ] || [ "$(isExpired "$latestMsg")" == "true" ] || [ "$(isPriceStale "$latestMsg" "$median")" == "true" ]; then
			time=$(date +%s)
			timeHex=$(time2Hex "$time")
			medianHex=$(price2Hex "$median")
			hash=$(keccak256Hash "$medianHex" "$timeHex")
			sig=$(signMessage "$hash")
			verbose "-> Message Signature = $sig"
			broadcastPrices "$asset" "$median" "$medianHex" "$time" "$timeHex" "$hash" "$sig" "${validSources[@]}" "${validPrices[@]}"
		fi
	done
}

initEnv () {
	# Global configuration
	if [[ -e $HOME/omnia.conf ]]; then
  		# shellcheck source=/dev/null
  		. "$HOME/omnia.conf"
  		verbose "Imported configuration from $HOME/omnia.conf"
	fi

	# Local configuration (via -C or --config)
	if [[ -e $OMNIA_CONF ]]; then
		# shellcheck source=/dev/null
  		. "$SETZER_CONF"
  		verbose "Imported configuration from $OMNIA_CONF"
	fi

	# Verify required env params 
	[[ $ETH_FROM ]] || errors+=("No default account set. Please set it via ETH_FROM ")
	[[ $ETH_KEYSTORE ]] || errors+=("No path to keystore file set. Please set it via ETH_KEYSTORE ")
	[[ $ETH_PASSWORD ]] || errors+=("No path to password set. Please set it via ETH_PASSWORD ")

	export SCUTTLEBOT_FEED_ID=$(getFeedId)
	[[ $SCUTTLEBOT_FEED_ID ]] || errors+=("Could not get scuttlebot feed id, make sure scuttlebot server is running ")

	[[ ${errors[*]} ]] && { printf '%s\n' "${errors[@]}"; exit 1; }

	#Set default configuration if none found
	[[ $OMNIA_SPREAD ]] || export OMNIA_SPREAD=2
	[[ $OMNIA_EXPIRY_INTERVAL_MS ]] || export OMNIA_EXPIRY_INTERVAL_MS=600000
	[[ $OMNIA_INTERVAL_SECONDS ]] || export OMNIA_INTERVAL_SECONDS=60

	echo ""
	echo "--------- STARTING OMNIA ---------"
  	echo "Bot started $(date)"
	echo "Ethereum account:            $ETH_FROM"
	echo "Feed address:                $SCUTTLEBOT_FEED_ID"
	echo ""
	echo "Spread to update:            $OMNIA_SPREAD %"
	echo "Price check interval:        $OMNIA_INTERVAL_SECONDS seconds"
	echo "Price expiration interval:   $OMNIA_EXPIRY_INTERVAL_MS ms"
	echo ""
	echo "Verbose Mode:                $OMNIA_VERBOSE"
	echo "------- INITIALIZATION COMPLETE -------"
	echo ""
}

function log {
 	echo "[$(date "+%D %T")] $1" >&2
}

function verbose {
 	[[ $OMNIA_VERBOSE ]] && echo "[$(date "+%D %T")] [V] $1" >&2
}

function error {
	echo "[$(date "+%D %T")] [E] $1" >&2
}

auto () {
	initEnv
	while true; do
		execute
		verbose "sleeping for $OMNIA_INTERVAL_SECONDS seconds"
		sleep $OMNIA_INTERVAL_SECONDS
	done
}

auto