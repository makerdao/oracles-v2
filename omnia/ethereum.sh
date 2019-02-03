#!/usr/bin/env bash

pullOracleTime () {
	local _assetPair="$1"
	local _address
	_address=$(lookupOracleContract "$_assetPair")
	seth --to-dec "$(seth --rpc-url "$ETH_RPC_URL" call "$_address" "age()(uint48)")"
}

pullOracleQuorum () {
	local _assetPair="$1"
	local _address
	_address=$(lookupOracleContract "$_assetPair")
	seth --to-dec "$(seth --rpc-url "$ETH_RPC_URL" call "$_address" "min()(uint256)")"
}

pullOraclePrice () {
	local _assetPair="$1"
	local _address
	local _currentPrice
	_address=$(lookupOracleContract "$_assetPair")
	_currentPrice=$(seth --to-dec "$(seth --rpc-url "$ETH_RPC_URL" call "$_address" "peek()(bytes32)")")
	adjustDecimalsRight "$_currentPrice" "$_assetPair"
}

pushOraclePrice () {
    local _assetPair="$1"
    local _oracleContract
    #TODO - calculate and use custom gas price
    _oracleContract=$(lookupOracleContract "$_assetPair")
    verbose "Sending tx..."
    tx=$(seth --rpc-url "$ETH_RPC_URL" send --async "$_oracleContract" 'poke(uint256[],uint256[],uint8[],bytes32[],bytes32[])' \
        "[$(join "${allPrices[@]}")]" \
        "[$(join "${allTimes[@]}")]" \
        "[$(join "${allV[@]}")]" \
        "[$(join "${allR[@]}")]" \
        "[$(join "${allS[@]}")]")
    echo "TX: $tx"
    echo SUCCESS: "$(seth --rpc-url "$ETH_RPC_URL" receipt "$tx" status)"
    echo GAS USED: "$(seth --rpc-url "$ETH_RPC_URL" receipt "$tx" gasUsed)"
}