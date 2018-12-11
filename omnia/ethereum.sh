#!/usr/bin/env bash

pullOraclePrice () {
	local _assetPair="$1"
	local _address
	_address=$(lookupOracleContract "$_assetPair")
	seth --from-wei "$(seth --to-dec "$(seth call "$_address" "peek()(bytes32)")")"
}

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