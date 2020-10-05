#!/usr/bin/env bash

mapSetzer() {
	local _assetPair=$1
	local _source=$2
	echo "$_source" "$(setzer price "$_assetPair" "$_source")"
}
export -f mapSetzer

#read price data of asset
readSourcesWithSetzer () {
	local _assetPair="${1,,}"
	local _prices
	local _price
	local _source

	mapfile -t _prices < <(
		setzer sources "$_assetPair" \
		| parallel \
			-j${OMNIA_SOURCE_PARALLEL:-0} \
			--termseq KILL \
			--timeout "$OMNIA_SRC_TIMEOUT" \
			mapSetzer "$_assetPair" \
			#2>/dev/null
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
	local _source="$1"
	local _price="$2"
	if [[ "$(isPriceValid "$_price")" == "true" ]]; then
		validSources+=( "$_source" )
		validPrices+=( "$_price" )
		verbose "$_source => $_price"
	else
		error "Error - [$_source] Invalid price data = $_price"
	fi
}

readSourcesWithGofer ()  {
	local  _output
	_output=$(gofer price --format json "${1}")
	local _jqFilter='
		[ ..
			| select(type == "object" and .type == "origin" and .error == null)
			| (.base+"/"+.quote+"@"+.origin)+" "+(.price|tostring)
		]
		| unique
		| .[]
	'

	local _prices
	mapfile -t _prices < <(echo "${_output}" | jq -r "$_jqFilter" 2>/dev/null)

	for i in "${!_prices[@]}"; do
		_source=${_prices[$i]% *}
		_price=${_prices[$i]#* }
		addPriceFromSource "$_source" "$_price"
	done

	median=$(echo "${_output}" | jq -r '.[0].price')
  verbose "median => $median"
}
