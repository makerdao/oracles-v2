readSourcesWithSetzer()  {
	local _assetPair="$1"
	_assetPair="${_assetPair/\/}"
	_assetPair="${_assetPair,,}"
	local _prices

	_prices=$(
		setzer sources "$_assetPair" \
		| parallel \
			-j${OMNIA_SOURCE_PARALLEL:-0} \
			--termseq KILL \
			--timeout "$OMNIA_SRC_TIMEOUT" \
			_mapSetzer "$_assetPair"
	)

	local _price
	local _source
	local _median=$(getMedian $(jq -sr 'add|.[]' <<<"$_prices"))
	verbose "median => $_median"

	jq -cs \
		--arg a "$_assetPair" \
		--argjson m "$_median" '
		{ asset: $a
		, median: $m
		, sources: .|add
		}' <<<"$_prices"
}

_mapSetzer() {
	local _assetPair=$1
	local _setzerAssetPair=${1/\/}
	local _source=$2
	local _price=$(setzer price "$_setzerAssetPair" "$_source")
	if [[ -n "$_price" && "$_price" =~ ^([1-9][0-9]*([.][0-9]+)?|[0][.][0-9]*[1-9]+[0-9]*)$ ]]; then
		echo "{\"$_source\": \"$(LANG=POSIX printf %0.10f $_price)\"}"
	else
		echo "[$(date "+%D %T")] [E] $1" >&2
	fi
}
export -f _mapSetzer

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
				| {(.base+"/"+.quote+"@"+.origin): (.price|tostring)}
				]
				| add
			)
		}
	'
}
