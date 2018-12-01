#!/usr/bin/env bash

pullOraclePrice () {
	local _asset="$1"
	local _address
	case ${_asset^^} in
		"ETH")
			_address="$OMNIA_ETH_ORACLE_ADDR" ;;
		"MKR")
			_address="$OMNIA_MKR_ORACLE_ADDR" ;;
		"REP")
			_address="$OMNIA_REP_ORACLE_ADDR" ;;
		"POLY")
			_address="OMNIA_POLY_ORACLE_ADDR" ;;
	esac
	seth --from-wei "$(seth --to-dec "$(seth call "$_address" "read()(bytes32)")")"
}

pullOracleTime () {
	local _asset="$1"
	local _address
	case ${_asset^^} in
		"ETH")
			_address="0xf63A899DAf5F486131600EA31cbDD55C186b2E8b" ;;
		"MKR")
			_address="0x8a4774FE82C63484AFeF97cA8D89A6Ea5E21F973" ;;
		"REP")
			_address="0xB0F88001c76029A25a5A5cf087f619c2b1732D77" ;;
		"POLY")
			_address="0x89ba53cd0455F5b9e9B8F16bBdB6242C26BeF83e" ;;
	esac
	#new medianizer uses age
	#old medianizer doesn't keep track of timestamp
	#instead need to query zzz from individual feed
	#seth --to-dec "$(seth call "$_address" "age()(uint48)")"
	seth --to-dec "$(seth call "$_address" "zzz()(uint32)")"
}

pullOracleQuorum () {
	local _asset="$1"
	local _address
	case ${_asset^^} in
		"ETH")
			_address="$OMNIA_ETH_ORACLE_ADDR" ;;
		"MKR")
			_address="$OMNIA_MKR_ORACLE_ADDR" ;;
		"REP")
			_address="$OMNIA_REP_ORACLE_ADDR" ;;
		"POLY")
			_address="OMNIA_POLY_ORACLE_ADDR" ;;
	esac
	seth --to-dec "$(seth call "$_address" "min()(uint256)")"
}