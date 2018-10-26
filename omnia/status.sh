#!/usr/bin/env bash

#is message empty
isEmpty () {
	local _msg="$1"
	[ -z "$_msg" ] && verbose "Cannot find recent message" && echo true || echo false
}

#is message of type asset
isAsset () {
	local _asset="$1"
	local _msg="$2"
	[ "$(echo "$_msg" | jq --arg _asset "$_asset" '.type == $_asset')" == "true" ] && echo true || echo false
}

#has interval elapsed
isExpired () {
	local _curTime="$1"
	local _lastTime="$2"
	local _expiryInterval="$3"
	local _expiryTime=$(( _curTime - _expiryInterval ))
	local _expirationDif=$(( _expiryTime - _lastTime ))
	[ "$_lastTime" -lt "$_expiryTime" ] && log "Previous price posted at t = $_lastTime is expired by $_expirationDif seconds" && echo true || echo false
}

#is last scuttlebot message published expired 
isMsgExpired () {
	local _msg="$1"
	local _curTime
	local _lastTime
	_curTime=$(timestampS)
	_lastTime=$(( "$(echo "$_msg" | jq '.time')" / 1000 ))
	[ "$(isExpired "$_curTime" "$_lastTime" "$OMNIA_MSG_EXPIRY_INTERVAL")" == "true" ] && echo true || echo false
}

#is last price update to Oracle expired
isOracleExpired () {
	local _curTime
	local _lastTime
	_curTime=$(timestampS)
	_lastTime=$(pullOracleTime)
	[ "$(isExpired "$_curTime" "$_lastTime" "$OMNIA_ORACLE_EXPIRY_INTERVAL")" == "true" ] && echo true || echo false
}

#is spread larger than specified spread limit
isStale () {
	local _oldPrice="$1"
	local _newPrice="$2"
	local _spreadLimit="$3"
	local _spread
	_spread=$(setzer spread "$_oldPrice" "$_newPrice")
	log "Old Price = ${_oldPrice}   New Price = ${_newPrice}"
	log "-> spread = $_spread"
	test=$(bc <<< "${_spread#-} >= ${_spreadLimit}")
	[[ ${test} -ne 0 ]] && log "Spread is greater than ${_spreadLimit}" && echo true || echo false
}

#is spread between existing Scuttlebot price larger than spread limit
isMsgStale () {
	local _oldPriceMsg="$1"
	local _newPrice="$2"
	local _oldPrice
	_oldPrice=$(echo "$_oldPriceMsg" | jq '.price')
	[ "$(isPriceStale "$_oldPrice" "$_newPrice" "$OMNIA_MSG_SPREAD")" == "true" ] && echo true || echo false
}

#is spread between existing Oracle price larger than spread limit
isOracleStale () {
	local _newPrice="$1"
	local _oldPrice
	_oldPrice=$(pullOraclePrice)
	[ "$(isPriceStale "$_oldPrice" "$_newPrice" "$OMNIA_ORACLE_SPREAD")" == "true" ] && echo true || echo false
}

#are there enough feed messages to establish quorum
isQuorum () {
	local _msgs=( "$@" )
	local numMsgs=${#_msgs[@]}
	local quorum
	#get min number of feeds from Oracle contract
	#note we cant trust users not to run modified clients
	#so whether quorum is achieved is reinforced in the contract
	quorum="$(seth --to-dec "$(seth call "$OMNIA_ORACLE_ADDR" "min()(uint256)")")"

	#DEBUG
	verbose "Number of message passed = $numMsgs"
	verbose "Min Quorum = $quorum"

	[ "$numMsgs" -ge "$quorum" ] && echo true || echo false && log "Error: Could not reach quorum ($quorum), only $numMsgs feeds reporting."
}