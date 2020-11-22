readSourcesWithSetzer()  {
	local _assetPair
	_assetPair="${1,,}"
	_assetPair="${_assetPair/\/}"
	local _prices

	mapfile -t _prices < <(
		setzer sources "$_assetPair" \
		| parallel \
			-j${OMNIA_SOURCE_PARALLEL:-0} \
			--termseq KILL \
			--timeout "$OMNIA_SRC_TIMEOUT" \
			_mapSetzer "$_assetPair"
	)

	local _price
	local _source
	local _median=$(getMedian $(jq -sr 'add|.[]' <<<"${_prices[@]}"))
	verbose "median => $_median"

	jq -s \
		--arg a "$_assetPair" \
		--argjson m "$_median" '
		{ asset: $a
		, median: $m
		, sources: .|add
		}' <<<"${_prices[@]}"
	#for i in "${!_prices[@]}"; do
	#	_source=${_prices[$i]% *}
	#	_price=${_prices[$i]#* }
	#	_addPriceFromSource "$_source" "$_price"
	#done

	#median=$(getMedian "${validPrices[@]}")
	#verbose "median => $median"
}

_mapSetzer() {
	local _assetPair=$1
	local _setzerAssetPair=${1/\/}
	local _source=$2
	local _price=$(setzer price "$_setzerAssetPair" "$_source")
	if [[ "$(isPriceValid "$_price")" == "true" ]]; then
		echo "{\"$_source\": $_price}"
	else
		error "Error - [$_source] Invalid price data from setzer = $_price"
	fi
}
export -f _mapSetzer
export -f isPriceValid
export -f error

readSourcesWithGofer()   {
	local _output
	_output=$(gofer price --config "$OMNIA_GOFER_CONFIG" --format json "$@")

	echo "$_output" | jq -c '
		.[]
		| {
			asset: (.base+"/"+.quote),
			median: .price,
			sources: (
				[ ..
				| select(type == "object" and .type == "origin" and .error == null)
				| {(.base+"/"+.quote+"@"+.origin): .price}
				]
				| add
			)
		}
	'

	#local _source
	#local _price
	#for i in "${!_prices[@]}"; do
	#	_source=${_prices[$i]% *}
	#	_price=${_prices[$i]#* }
	#	_addPriceFromSource "$_source" "$_price"
	#done

	#median=$(echo "$_output" | jq -r '.[0].price')
	#verbose  "median => $median"
}

#_addPriceFromSource()  {
#	local _source="$1"
#	local _price="$(LC_ALL=POSIX printf "%.10f" "$2")"
#	if [[ "$(isPriceValid "$_price")" == "true" ]]; then
#		validSources+=("$_source")
#		validPrices+=("$_price")
#		verbose "$_source => $_price"
#	else
#		error "Error - [$_source] Invalid price data = $_price"
#	fi
#}
