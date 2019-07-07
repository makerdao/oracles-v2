#!/usr/bin/env bash

#is message empty
isEmpty () {
	local _msg="$1"
	[ -z "$_msg" ] && verbose "Cannot find recent message" && echo true || echo false
}

#is message of type asset
isAssetPair () {
	local _assetPair="$1"
	local _msg="$2"
	[ "$(echo "$_msg" | jq --arg _assetPair "$_assetPair" '.type == $_assetPair')" == "true" ] && echo true || echo false
}

#has interval elapsed
isExpired () {
	local _lastTime="$1"
	local _expiryInterval="$2"
	local _curTime
	_curTime=$(timestampS)
	if ! [[ "$_curTime" =~ ^[1-9]{1}[0-9]{9}$ ]]; then
		error "Error - Invalid current timestamp ($_curTime)"
		echo false
		return 1
	fi
	local _expiryTime=$(( _curTime - _expiryInterval ))
	local _expirationDif=$(( _expiryTime - _lastTime ))
	[ "$_lastTime" -lt "$_expiryTime" ] && log "Previous price posted at t = $_lastTime is expired by $_expirationDif seconds" && echo true || echo false
}

#is last scuttlebot message published expired 
isMsgExpired () {
	local _assetPair="$1"
	local _msg="$2"
	local _lastTime
	local _expirationInterval
	_lastTime=$(echo "$_msg" | jq '.time')
	if [[ "$_lastTime" =~ ^[0-9]{10}$ ]]; then
		echo false
		return 1
	fi
	_expirationInterval=$(getMsgExpiration "$_assetPair")
	[ "$(isExpired "$_lastTime" "$_expirationInterval")" == "true" ] && verbose "Message timestamp is expired, skipping..." && echo true || echo false
}

#is last price update to Oracle expired
isOracleExpired () {
	local _assetPair="$1"
	local _lastTime
	local _expirationInterval
	_lastTime=$(pullOracleTime "$_assetPair")
	if ! [[ "$_lastTime" =~ ^[0-9]{10}|[0]{1}$ ]]; then
		error "Error - Invalid Oracle time ($_lastTime)"
		echo false
		return 1
	fi
	_expirationInterval=$(getOracleExpiration "$_assetPair")
	if ! [[ "$_expirationInterval" =~ ^[1-9][0-9]*$ ]]; then
		error "Error - Invalid Oracle expiration interval ($_expirationInterval)"
		echo false
		return 1
	fi
	[ "$(isExpired "$_lastTime" "$_expirationInterval")" == "true" ] && echo true || echo false
}

#is spread greater than specified spread limit
isStale () {
	local _oldPrice="$1"
	local _newPrice="$2"
	local _spreadLimit="$3"
	local _spread
	log "Old Price = ${_oldPrice}   New Price = ${_newPrice}"
	_spread=$(setzer spread "$_oldPrice" "$_newPrice")
	if ! [[ "$_spread" =~ ^([1-9][0-9]*([.][0-9]+)?|[.][0-9]*[1-9][0-9]*|[0]{1})$ ]]; then
		error "Error - Invalid spread ($_spread)"
		echo false
		return 1
	fi
	log "-> spread = ${_spread#-}"
	test=$(bc <<< "${_spread#-} >= ${_spreadLimit}")
	[[ ${test} -ne 0 ]] && log "Spread is greater than ${_spreadLimit}" && echo true || echo false
}

#is spread between existing Scuttlebot price greatner than spread limit
isMsgStale () {
	local _assetPair="$1"
	local _oldPriceMsg="$2"
	local _newPrice="$3"
	local _oldPrice
	local _spreadLimit
	_oldPrice=$(echo "$_oldPriceMsg" | jq '.price')
	if ! [[ "$_oldPrice" =~ ^([1-9][0-9]*([.][0-9]+)?|[0][.][0-9]*[1-9][0-9]*|[0]{1})$ ]]; then
		error "Error - Invalid Message price ($_oldPrice)"
		echo false
		return 1
	fi
	_spreadLimit=$(getMsgSpread "$_assetPair")
	if ! [[ "$_spreadLimit" =~ ^([1-9][0-9]*([.][0-9]+)?|[0][.][0-9]*[1-9][0-9]*|[0]{1})$ ]]; then
		error "Error - Invalid Message spread limit ($_spreadLimit)"
		echo false
		return 1
	fi
	[ "$(isStale "$_oldPrice" "$_newPrice" "$_spreadLimit")" == "true" ] && echo true || echo false
}

#is spread between existing Oracle price greater than spread limit
isOracleStale () {
	local _assetPair="$1"
	local _newPrice="$2"
	local _oldPrice
	local _spreadLimit
	_spreadLimit=$(getOracleSpread "$_assetPair")
	if ! [[ "$_spreadLimit" =~ ^([1-9][0-9]*([.][0-9]+)?|[0][.][0-9]*[1-9][0-9]*|[0]{1})$ ]]; then
		error "Error - Invalid Oracle spread limit ($_spreadLimit)"
		echo false
		return 1
	fi
	_oldPrice=$(pullOraclePrice "$_assetPair")
	if ! [[ "$_oldPrice" =~ ^([1-9][0-9]*([.][0-9]+)?|[.][0-9]*[1-9][0-9]*|[0]{1})$ ]]; then
		error "Error - Invalid Oracle price ($_oldPrice)"
		echo false
		return 1
	fi
	[ "$(isStale "$_oldPrice" "$_newPrice" "$_spreadLimit")" == "true" ] && echo true || echo false
}

#is timestamp of message more recent than timestamp of last Oracle update
isMsgNew () {
	local _assetPair="$1"
	local _msg="$2"
	local _oracleTime
	local _msgTime
	_oracleTime=$(pullOracleTime "$_assetPair")
	if ! [[ "$_oracleTime" =~ ^[0-9]{10}|[0]{1}$ ]]; then
		error "Error - Invalid Oracle time ($_oracleTime)"
		echo false
		return 1
	fi
	_msgTime=$(echo "$_msg" | jq '.time')
	if ! [[ "$_msgTime" =~ ^[0-9]{10}$ ]]; then
		error "Error - Invalid Message time ($_msgTime)"
		echo false
		return 1
	fi
	[ "$_oracleTime" -gt "$_msgTime" ] && verbose "Message is older than last Oracle update, skipping..." && echo false || echo true
}

#are there enough feed messages to establish quorum
isQuorum () {
	local _assetPair="$1"
	local _numFeeds="$2"
	local _quorum
	#get min number of feeds required for quorum from Oracle contract
	_quorum=$(pullOracleQuorum "$_assetPair")
	if ! [[ "$_quorum" =~ ^[1-9][0-9]*$ ]]; then
		error "Error - Invalid quorum ($_quorum)"
		echo false
		return 1
	fi
	[ "$_numFeeds" -ge "$_quorum" ] && echo true || ( echo false && verbose "Could not reach quorum ($_quorum), only $_numFeeds feeds reporting." )
}