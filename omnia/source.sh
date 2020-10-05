#!/usr/bin/env bash

mapSetzer() {
	local _assetPair=$1
	local _source=$2
	echo "$_source" "$(setzer price "$_assetPair" "$_source")"
}
export -f mapSetzer

#read price data of asset
readSources () {
	local _assetPair="${1,,}"
	local _prices
	local _price
	local _source

	mapfile -t _prices < <(
		setzer sources "$_assetPair" \
		| parallel -j0 --termseq KILL --timeout "$OMNIA_SRC_TIMEOUT" \
			mapSetzer "$_assetPair" \
			2>/dev/null
	)

	for i in "${!_prices[@]}"; do
		_source=${_prices[$i]% *}
		_price=${_prices[$i]#* }
		addPriceFromSource "$_source" "$_price"
	done

	median=$(getMedian "${validPrices[@]}")
	verbose "median => $median"
}

addPriceFromSource () {
	local _source=$1
	local _price=$2
	if [[ $_price =~ ^([1-9][0-9]*([.][0-9]+)?|[0][.][0-9]*[1-9]+[0-9]*)$  ]]; then
		validSources+=( "$_source" )
		validPrices+=( "$_price" )
		verbose "$_source => $_price"
	else
		error "Error - [$_source] Invalid price data = $_price"
	fi
}

readSourcesFromGofer ()  {
	local  _output
	_output=$(gofer price --format json "${1}")
	local _jqFilter='[
		.[]
		|select(.error? == null)
		|..
		|.ticks?
		|select(type == "array" and length > 0)
		|.[]
		|select(.["type"] == "origin" and .error? == null)
		|{"source":(.base+"/"+.quote+"@"+.origin),price}
	]|unique'
	local _jqFilter2='.[]|(.source+" "+(.price|tostring))'

	local _prices
	mapfile -t _prices < <(echo "${_output}" | jq -r "${_jqFilter}|${_jqFilter2}" 2>/dev/null)

	for i in "${!_prices[@]}"; do
		_source=${_prices[$i]% *}
		_price=${_prices[$i]#* }
		addPriceFromSource "$_source" "$_price"
	done

	median=$(echo "${_output}" | jq -r '.[0].price')
}
