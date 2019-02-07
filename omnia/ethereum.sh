#!/usr/bin/env bash

pullOracleTime () {
	local _assetPair="$1"
	local _address
	_address=$(lookupOracleContract "$_assetPair")
	seth --to-dec "$(seth --rpc-url "$ETH_RPC_URL" call "$_address" "age()(uint32)")"
}

pullOracleQuorum () {
	local _assetPair="$1"
	local _address
	_address=$(lookupOracleContract "$_assetPair")
	seth --to-dec "$(seth --rpc-url "$ETH_RPC_URL" call "$_address" "bar()(uint256)")"
}

pullOraclePrice () {
	local _assetPair="$1"
	local _address
	local _currentPrice
	_address=$(lookupOracleContract "$_assetPair")
	_currentPrice=$(seth --to-dec "$(seth --rpc-url "$ETH_RPC_URL" call "$_address" "peek()(uint256)")")
	adjustDecimalsRight "$_currentPrice" "$_assetPair"
}

pushOraclePrice () {
    local _assetPair="$1"
    local _oracleContract
    #TODO - calculate and use custom gas price
    _oracleContract=$(lookupOracleContract "$_assetPair")
    verbose "Sending tx..."
    tx=$(seth --rpc-url "$ETH_RPC_URL" send "$_oracleContract" 'poke(uint256[] calldata,uint256[] calldata,uint8[] calldata,bytes32[] calldata,bytes32[] calldata)' \
        "[$(join "${allPrices[@]}")]" \
        "[$(join "${allTimes[@]}")]" \
        "[$(join "${allV[@]}")]" \
        "[$(join "${allR[@]}")]" \
        "[$(join "${allS[@]}")]")
    echo "TX: $tx"
    echo SUCCESS: "$(seth --rpc-url "$ETH_RPC_URL" receipt "$tx" status)"
    echo GAS USED: "$(seth --rpc-url "$ETH_RPC_URL" receipt "$tx" gasUsed)"
}