#!/usr/bin/env bash

pullOracleTime () {
	local _assetPair="$1"
	local _address
	_address=$(lookupOracleContract "$_assetPair")
	seth --to-dec "$(seth call "$_address" "age()(uint48)")"
	#new medianizer uses age
	#old medianizer doesn't keep track of timestamp
	#if using old contract instead need to query zzz from individual feed
	#seth --to-dec "$(seth call "$_address" "zzz()(uint32)")"
}

pullOracleQuorum () {
	local _assetPair="$1"
	local _address
	_address=$(lookupOracleContract "$_assetPair")
	seth --to-dec "$(seth call "$_address" "min()(uint256)")"
}

pullOraclePrice () {
	local _assetPair="$1"
	local _address
	_address=$(lookupOracleContract "$_assetPair")
	seth --from-wei "$(seth --to-dec "$(seth call "$_address" "peek()(bytes32)")")"
}

pushOraclePrice () {
    local _assetPair="$1"
    local _oracleContract
    #TODO - calculate and use custom gas price
    _oracleContract=$(lookupOracleContract "$_assetPair")
    verbose "Sending tx..."
    tx=$(seth send --async "$_oracleContract" 'poke(uint256[],uint256[],uint8[],bytes32[],bytes32[])' \
        "[$(join "${allPrices[@]}")]" \
        "[$(join "${allTimes[@]}")]" \
        "[$(join "${allV[@]}")]" \
        "[$(join "${allR[@]}")]" \
        "[$(join "${allS[@]}")]")
    echo "TX: $tx"
    echo SUCCESS: "$(seth receipt "$tx" status)"
    echo GAS USED: "$(seth receipt "$tx" gasUsed)"
}