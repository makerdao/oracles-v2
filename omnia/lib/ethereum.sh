#!/usr/bin/env bash

pullOracleTime () {
	local _assetPair="$1"
	local _address
	_address=$(getOracleContract "$_assetPair")
	if ! [[ "$_address" =~ ^(0x){1}[0-9a-fA-F]{40}$ ]]; then
		error "Error - Invalid Oracle contract"
		return 1
	fi

	timeout -s9 10 seth --to-dec "$(seth --rpc-url "$ETH_RPC_URL" call "$_address" "age()(uint32)")"
}

pullOracleQuorum () {
	local _assetPair="$1"
	local _address
	_address=$(getOracleContract "$_assetPair")
	if ! [[ "$_address" =~ ^(0x){1}[0-9a-fA-F]{40}$ ]]; then
		error "Error - Invalid Oracle contract"
		return 1
	fi

	timeout -s9 10 seth --to-dec "$(seth --rpc-url "$ETH_RPC_URL" call "$_address" "bar()(uint256)")"
}

pullOraclePrice () {
	local _assetPair="$1"
	local _address
	local _rawStorage
	_address=$(getOracleContract "$_assetPair")
	if ! [[ "$_address" =~ ^(0x){1}[0-9a-fA-F]{40}$ ]]; then
			error "Error - Invalid Oracle contract"
			return 1
	fi

	_rawStorage=$(timeout -s9 10 seth --rpc-url "$ETH_RPC_URL" storage "$_address" 0x1)

	[[ "${#_rawStorage}" -ne 66 ]] && error "oracle contract storage query failed" && return

	seth --from-wei "$(seth --to-dec "${_rawStorage:34:32}")"
}

pushOraclePrice () {
		local _assetPair="$1"
		local _oracleContract
		#TODO - use custom gas pricing strategy
		_oracleContract=$(getOracleContract "$_assetPair")
		if ! [[ "$_oracleContract" =~ ^(0x){1}[0-9a-fA-F]{40}$ ]]; then
		  error "Error - Invalid Oracle contract"
		  return 1
		fi
		log "Sending tx..."
		tx=$(seth --rpc-url "$ETH_RPC_URL" send --async "$_oracleContract" 'poke(uint256[] memory,uint256[] memory,uint8[] memory,bytes32[] memory,bytes32[] memory)' \
				"[$(join "${allPrices[@]}")]" \
				"[$(join "${allTimes[@]}")]" \
				"[$(join "${allV[@]}")]" \
				"[$(join "${allR[@]}")]" \
				"[$(join "${allS[@]}")]")
		echo "TX: $tx"
		echo SUCCESS: "$(timeout -s9 60 seth --rpc-url "$ETH_RPC_URL" receipt "$tx" status)"
		echo GAS USED: "$(timeout -s9 10 seth --rpc-url "$ETH_RPC_URL" receipt "$tx" gasUsed)"
}
