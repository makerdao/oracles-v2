#!/usr/bin/env bash

#get median of  a list of numbers
getMedian () {
	local _numbers=( "$@" )
	tr " " "\\n" <<< "${_numbers[@]}" | datamash median 1
}

#extracts prices from list of messages
extractPrices () {
    local _msgs=( "$@" )
    local _prices
    for msg in "${_msgs[@]}"; do
       _prices+=("$(echo "$msg" | jq '.price')")
    done
    echo "${_prices[@]}"
}

join () { 
	local IFS=","
	echo "$*"
}

#get unix timestamp in ms
timestampMs () {
    date +"%s%3N"
}

#get unix timestamp in s
timestampS () {
	date +"%s"
}

#gets keccak-256 hash of 1 or more input arguments
keccak256Hash () {
	local _inputs
	for arg in "$@"; do
		_inputs+="$arg"
	done
	verbose "inputs to hash function = $_inputs"
	seth keccak "$_inputs"
}

#convert price to hex
price2Hex () {
	local _price="$1"
	#convert price to 32 byte hex
	seth --to-uint256 "$(seth --to-wei "$_price" eth)"
}

#converts timestamp to 32 byte hex
time2Hex () {
	local _time="$1"
	seth --to-uint256 "$_time"
}

getMsgExpiration () {
	local _assetPair="$1"
	local _msgExpiration
	_msgExpiration=$(cut -d ',' -f1 <<<"${assetInfo[$_assetPair]}")
	echo "$_msgExpiration"
}

getMsgSpread () {
	local _assetPair="$1"
	local _msgSpread
	[[ $OMNIA_MODE == "FEED" ]] && _msgSpread=$(cut -d ',' -f2 <<<"${assetInfo[$_assetPair]}")
	echo "$_msgSpread"
}

#get the Oracle contract of an asset pair
getOracleContract () {
	local _assetPair="$1"
	local _address
	[[ $OMNIA_MODE == "RELAYER" ]] && _address=$(cut -d ',' -f2 <<<"${assetInfo[$_assetPair]}")
	echo "$_address"
}

getOracleExpiration () {
	local _assetPair="$1"
	local _oracleExpiration
	[[ "$OMNIA_MODE" == "RELAYER" ]] && _oracleExpiration=$(cut -d ',' -f3 <<<"${assetInfo[$_assetPair]}")
	echo "$_oracleExpiration"
}

getOracleSpread () { 
	local _assetPair="$1"
	local _oracleSpread
	[[ "$OMNIA_MODE" == "RELAYER" ]] && _oracleSpread=$(cut -d ',' -f4 <<<"${assetInfo[$_assetPair]}")
	echo "$_oracleSpread"
}
