#!/usr/bin/env bash

pullOracleTime () {
	local _assetPair="$1"
	local _address
	_address=$(getOracleContract "$_assetPair")
	seth --to-dec "$(seth --rpc-url "$ETH_RPC_URL" call "$_address" "age()(uint32)")"
}

pullOracleQuorum () {
	local _assetPair="$1"
	local _address
	_address=$(getOracleContract "$_assetPair")
	seth --to-dec "$(seth --rpc-url "$ETH_RPC_URL" call "$_address" "bar()(uint256)")"
}

pullOraclePrice () {
	local _assetPair="$1"
	local _address
	_address=$(getOracleContract "$_assetPair")
	rawStorage=$(seth --rpc-url "$ETH_RPC_URL" storage "$_address" 0x1)
	[[ "${#rawStorage}" -ne 66 ]] || echo "oracle contract storage query failed"
	seth --from-wei "$(seth --to-dec "${rawStorage:34:32}")"
}

pushOraclePrice () {
    local _assetPair="$1"
    local _oracleContract
    #TODO - calculate and use custom gas price
    _oracleContract=$(getOracleContract "$_assetPair")
    verbose "Sending tx..."
    tx=$(seth --rpc-url "$ETH_RPC_URL" send --async "$_oracleContract" 'poke(uint256[] memory,uint256[] memory,uint8[] memory,bytes32[] memory,bytes32[] memory)' \
        "[$(join "${allPrices[@]}")]" \
        "[$(join "${allTimes[@]}")]" \
        "[$(join "${allV[@]}")]" \
        "[$(join "${allR[@]}")]" \
        "[$(join "${allS[@]}")]")
    echo "TX: $tx"
    echo SUCCESS: "$(timeout 45 seth --rpc-url "$ETH_RPC_URL" receipt "$tx" status)"
    echo GAS USED: "$(seth --rpc-url "$ETH_RPC_URL" receipt "$tx" gasUsed)"
}