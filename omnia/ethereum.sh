#!/usr/bin/env bash

pullOraclePrice () {
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
	seth --from-wei "$(seth --to-dec "$(seth call "$_address" "read()(bytes32)")")"
}

pullOracleTime () {
	local _assetPair="$1"
	local _address
	case ${_assetPair^^} in
		"ETHUSD")
			_address="0xf63A899DAf5F486131600EA31cbDD55C186b2E8b" ;;
		"MKRUSD")
			_address="0x8a4774FE82C63484AFeF97cA8D89A6Ea5E21F973" ;;
		"REPUSD")
			_address="0xB0F88001c76029A25a5A5cf087f619c2b1732D77" ;;
		"POLYUSD")
			_address="0x89ba53cd0455F5b9e9B8F16bBdB6242C26BeF83e" ;;
	esac
	#new medianizer uses age
	#old medianizer doesn't keep track of timestamp
	#instead need to query zzz from individual feed
	#seth --to-dec "$(seth call "$_address" "age()(uint48)")"
	seth --to-dec "$(seth call "$_address" "zzz()(uint32)")"
}

pullOracleQuorum () {
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
	seth --to-dec "$(seth call "$_address" "min()(uint256)")"
}