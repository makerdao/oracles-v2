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
adjustDecimalsLeft () {
	local _price="$1"
	local _assetPair="$2"
	local _decimals
	_decimals=$(lookupTokenDecimals "$_assetPair")
	#debug
	verbose "decimals = $_decimals"
	bc <<<"$_price * 10 ^ $_decimals / 1"
}

#convert price to hex with respect to that tokens decimals
adjustDecimalsRight () {
	local _price="$1"
	local _assetPair="$2"
	local _decimals
	_decimals=$(lookupTokenDecimals "$_assetPair")
	#debug
	verbose "decimals = $_decimals"
	bc <<<"scale=$_decimals; $_price * 10^-$_decimals"
}

#convert price to hex
price2Hex () {
	local _price="$1"
	local _assetPair="$2"
	local _adjustedPrice
	#adjust price to decimals corresponding to asset pair
	_adjustedPrice=$(adjustDecimals "$_price" "$_assetPair")
	#debug
	verbose "Adjusted Price = $_adjustedPrice"
	#convert price to 32 byte hex
	seth --to-uint256 "$_adjustedPrice"
}

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

#get the Oracle contract of an asset pair
lookupOracleContract () {
	local _assetPair="$1"
	local _address
	_address=$(cut -d ',' -f2 <<<"${assetInfo[$_assetPair]}")
	echo "$_address"
}

#get the number of decimals of a token 
lookupTokenDecimals () {
	local _assetPair="$1"
	local _decimals
	_decimals=$(cut -d ',' -f1 <<<"${assetInfo[$_assetPair]}")
	echo "$_decimals"
}