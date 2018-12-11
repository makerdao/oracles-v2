#!/usr/bin/env bash

#read price data of asset
readSources () {
	local _assetPair="$1"
	mapfile -t _sources < <(setzer sources "${_assetPair,,}")
	if [[ "${#_sources[@]}" -ne 0 ]]; then
		for source in "${_sources[@]}"; do
			getPriceFromSource "$_assetPair" "$source"
		done
	fi
}

#pull price data of asset from source
getPriceFromSource () {
	local _assetPair=$1
	local _source=$2
	local _price
	_price=$(timeout 5 setzer price "${_assetPair,,}"-"$_source" 2> /dev/null)
	verbose "$_source = $_price"
	if [[ $_price =~ ^[+-]?[0-9]+\.?[0-9]*$  ]]; then
		validSources+=( "$_source" )
		validPrices+=( "$_price" )
	fi
}