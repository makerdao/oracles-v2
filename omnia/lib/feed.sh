#!/usr/bin/env bash

readSourcesAndBroadcastAllPriceMessages()  {
	if [[ "${#assetPairs[@]}" -eq 0 || "${#OMNIA_FEED_SOURCES[@]}" -eq 0 || "${#OMNIA_FEED_PUBLISHERS[@]}" -eq 0 ]]
	then
		error "Error - Loop in readSourcesAndBroadcastAllPriceMessages"
		return 1
	fi

	local -A _unpublishedPairs
	local _assetPair
	for _assetPair in "${assetPairs[@]}"; do
		_unpublishedPairs[$_assetPair]=
	done

	local _src
	for _src in "${OMNIA_FEED_SOURCES[@]}"; do
		if [[ "${#_unpublishedPairs[@]}" == 0 ]]; then
			break
		fi

		while IFS= read -r _json; do
			if [[ -z "$_json" ]]; then
				continue
			fi
			local _assetPair=$(jq -r .asset <<<"$_json")
			local _median=$(jq -r .median <<<"$_json")
			local _sources=$(jq -rS '.sources' <<<"$_json")
			local	_message=$(validateAndConstructMessage "$_assetPair" "$_median"	"$_sources")

			if [[ -z "$_message" ]]; then
				error "Failed constructing $_assetPair price message"
				continue
			fi

			unset _unpublishedPairs[$_assetPair]

			local _publisher
			for _publisher in "${OMNIA_FEED_PUBLISHERS[@]}"; do
				log "Publishing $_assetPair price message with $_publisher"
				"$_publisher" publish "$_message" || error "Failed publishing $_assetPair price with $_publisher"
			done
		done < <(readSource "$_src" "${!_unpublishedPairs[@]}")
	done
}

readSource() {
	local _src="${1,,}"
	local _assetPairs=("${@:2}")

	case "$_src" in
		setzer)
			for _assetPair in "${_assetPairs[@]}"; do
				log "Querying ${_assetPair} prices and calculating median with setzer..."
				readSourcesWithSetzer "$_assetPair"
			done
			;;
		gofer)
			log "Querying ${_assetPairs[*]} prices and calculating medians with gofer..."
			readSourcesWithGofer "${_assetPairs[@]}"
			;;
		*)
			error "Error - Unknown Feed Source: $_src"
			return 1
			;;
	esac
}

constructMessage() {
	local _assetPair="${1/\/}"
	local _price="$2"
	local _priceHex="$3"
	local _time="$4"
	local _timeHex="$5"
	local _hash="$6"
	local _signature="$7"
	local _sourcePrices="$8"

	# compose jq message arguments
	_jqArgs=(
		--arg assetPair "$_assetPair"
		--arg version "$OMNIA_VERSION"
		--arg price "$_price"
		--arg priceHex "$_priceHex"
		--arg time "$_time"
		--arg timeHex "$_timeHex"
		--arg hash "${_hash:2}"
		--arg signature "${_signature:2}"
		--argjson sourcePrices "$_sourcePrices"
	)

	# generate JSON msg
	#shellcheck disable=2068
	if ! _json=$(jq -ne "${_jqArgs[@]}" '{type: $assetPair, version: $version, price: $price | tonumber, priceHex: $priceHex, time: $time | tonumber, timeHex: $timeHex, hash: $hash, signature: $signature, sources: $sourcePrices}'); then
			error "Error - failed to generate JSON msg"
			return 1
	fi

	echo "$_json"
}

validateAndConstructMessage() {
	local _assetPair="$1"
	_assetPair="${_assetPair/\/}"
	_assetPair="${_assetPair^^}"
	local median="$2"
	local sourcePrices="$3"

	if [[ "$(isPriceValid "$median")" == "false" ]]; then
		error "Error - Failed to calculate valid median: ($median)"
		debug "Sources = $sourcePrices"
		return 1
	fi

	#Get latest message for asset pair
	latestMsg=$(pullLatestFeedMsgOfType "$SCUTTLEBOT_FEED_ID" "$_assetPair")

	if [ "$(isEmpty "$latestMsg")" == "false" ] \
		&& [ "$(isAssetPair "$_assetPair" "$latestMsg")" == "true" ] \
		&& [ "$(isMsgExpired "$_assetPair" "$latestMsg")" == "false" ] \
		&& [ "$(isMsgStale "$_assetPair" "$latestMsg" "$median")" == "false" ]; then
		return 1
	fi

	#Get timestamp
	time=$(timestampS)
	if [[ ! "$time" =~ ^[1-9]{1}[0-9]{9}$ ]]; then
		error "Error - Got invalid timestamp"
		debug "Invalid Timestamp = $time"
		return 1
	fi

	#Convert timestamp to hex
	timeHex=$(time2Hex "$time")
	timeHex=${timeHex#"0x"}
	if [[ ! "$timeHex" =~ ^[0-9a-fA-F]{64}$ ]]; then
		error "Error - Failed to convert timestamp to hex"
		debug "Timestamp = $time"
		debug "Invalid Timestamp Hex = $timeHex"
		return 1
	fi

	#Convert median to hex
	medianHex=$(price2Hex "$median")
	medianHex=${medianHex#"0x"}
	if [[ ! "$medianHex" =~ ^[0-9a-fA-F]{64}$ ]]; then
		error "Error - Failed to convert median to hex:"
		debug "Median = $median"
		debug "Invalid Median Hex = $medianHex"
		return 1
	fi

	#Convert asset pair to hex
	assetPairHex=$(seth --to-bytes32 "$(seth --from-ascii "$_assetPair")")
	assetPairHex=${assetPairHex#"0x"}
	if [[ ! "$assetPairHex" =~ ^[0-9a-fA-F]{64}$ ]]; then
		error "Error - Failed to convert asset pair to hex:"
		debug "Asset Pair = $_assetPair"
		debug "Invalid Asset Pair Hex = $assetPairHex"
		return 1
	fi

	#Create hash
	hash=$(keccak256Hash "0x" "$medianHex" "$timeHex" "$assetPairHex")
	if [[ ! "$hash" =~ ^(0x){1}[0-9a-fA-F]{64}$ ]]; then
		error "Error - failed to generate valid hash"
		debug "Median Hex = $medianHex"
		debug "Timestamp Hex = $timeHex"
		debug "Asset Pair Hex = $assetPairHex"
		debug "Invalid Hash = $hash"
		return 1
	fi

	#Sign hash
	sig=$(signMessage "$hash")
	if [[ ! "$sig" =~ ^(0x){1}[0-9a-f]{130}$ ]]; then
		error "Error - Failed to generate valid signature"
		debug "Hash = $hash"
		debug "Invalid Signature = $sig"
		return 1
	fi

	verbose "Constructing message..."
	constructMessage "$_assetPair" "$median" "$medianHex" "$time" "$timeHex" \
		"$hash" "$sig" "$sourcePrices"
}
