#!/usr/bin/env bash

#is message empty
isEmpty () {
	[ -z "$1" ] && verbose "Cannot find recent message for asset $asset" && echo true || echo false
}

#is message of type asset
isAsset () {
	local _asset="$1"
	local _msg="$2"
	[ "$(echo "$_msg" | jq --arg _asset "$_asset" '.type == $_asset')" == "true" ] && echo true || echo false
}

#is message expired
#note that this uses the timestamp on the message itself (which is in ms),
#and NOT the timestamp within the message content (which is in s).
isExpired () {
	local _msg="$1"
	local _curTime
	local _lastTime
	_curTime=$(timestampMs)
	_lastTime="$(echo "$_msg" | jq '.time')"
	local _expiryTime=$(( _curTime - OMNIA_EXPIRY_INTERVAL_MS ))
	local _expirationDif=$(( (_curTime - _lastTime - OMNIA_EXPIRY_INTERVAL_MS) / 1000))
	[ "$_lastTime" -lt "$_expiryTime" ] && log "Previous price posted at t = $(( _lastTime / 1000 )) is expired by $_expirationDif seconds" && echo true || echo false
}

#is price significantly different ( >> $OMNIA_SPREAD) from previous price
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