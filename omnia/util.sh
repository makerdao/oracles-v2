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

#convert price to hex with respect to that tokens decimals
price2Hex () {
	local _price="$1"
	local _assetPair="$2"
	local _decimals
	_decimals=$(lookupOracleContract "$_assetPair")
	bc <<<"$_price * 10 ^ $_decimals / 1"
}

#convert price to hex
#assumes standard token (18 decimals)
#price2Hex () {
#	local _price="$1"
	#convert price to wei and then uint256
	#note this assumes token has 18 decimal places
	#need to create more robust solution for other tokens
#	seth --to-uint256 "$(seth --to-wei "$_price" eth)"
#}

#converts timestamp to 32 byte hex
time2Hex () {
	local _time="$1"
	seth --to-uint256 "$_time"
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

lookupOracleContract () {
	local _assetPair="$1"
	local _address
	_address=$(cut -d ',' -f2 <<<"${assetInfo[$_assetPair]}")
	echo "$_address"
}

lookupTokenDecimals () {
	local _assetPair="$1"
	local _decimals
	_decimals=$(cut -d ',' -f1 <<<"${assetInfo[$_assetPair]}")
	echo "$_decimals"
}