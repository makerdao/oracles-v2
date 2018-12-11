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

#convert price to hex
price2Hex () {
	local _price="$1"
	#convert price to wei and then uint256
	#note this assumes token has 18 decimal places
	#need to create more robust solution for other tokens
	seth --to-uint256 "$(seth --to-wei "$_price" eth)"
}

#converts blockstamp to hex
time2Hex () {
	local _time="$1"
	#convert blockstamp to uint256
	seth --to-uint256 "$_time"

}

#gets keccak-256 hash of 1 or more input arguments
keccak256Hash () {
	local _inputs
	for arg in "$@"; do
		_inputs+="$arg"
	done
	seth keccak "$_inputs"
}

lookupOracleContract () {
	local _assetPair="$1"
	local _address
	case ${_assetPair^^} in
		"ETHUSD")
			_address="$OMNIA_ETHUSD_ORACLE_ADDR" ;;
		"MKRUSD")
			_address="$OMNIA_MKRUSD_ORACLE_ADDR" ;;
		"REPUSD")
			_address="$OMNIA_REPUSD_ORACLE_ADDR" ;;
		"POLYUSD")
			_address="$OMNIA_POLYUSD_ORACLE_ADDR" ;;
	esac
	echo "$_address"
}

#this is a hacky wordaround until we update setzer to use asset pairs as input
lookupBaseToken () {
	local _pair="$1"
	case ${_pair^^} in
		"ETHUSD")
			echo "eth" ;;
		"MKRUSD")
			echo "mkr" ;;
		"REPUSD")
			echo "rep" ;;
		"POLYUSD")
			echo "poly" ;;
	esac
}