#!/usr/bin/env bash

readSourcesAndBroadcastAllPriceMessages()  {
	if [[ "${#assetPairs[@]}" -eq 0 ]] || [[ "${#OMNIA_FEED_SOURCES[@]}" -eq 0 ]]
	then
		error "Error - Loop in readSourcesAndBroadcastAllPriceMessages"
		return
	fi

	for _assetPair in "${assetPairs[@]}"; do
		for OMNIA_FEED_SOURCE in "${OMNIA_FEED_SOURCES[@]}"; do
			readSourcesAndBroadcastPriceMessage "$_assetPair"
		done
	done
}

readSourcesAndBroadcastPriceMessage() {
	local _assetPair="${1^^}"

	validSources=()
	validPrices=()
	median=0

	log "Querying ${_assetPair} prices and calculating median..."
	readSources "$_assetPair"

	if [[ "$(isPriceValid "$median")" == "false" ]]; then
		error "Error - Failed to calculate valid median: ($median)"
		debug "Sources = ${validSources[*]}"
		debug "Prices = ${validPrices[*]}"
		return
	fi

	if [[ "${#validPrices[@]}" -lt 2 ]] || [[ "${#validSources[@]}" -lt 2 ]] || [[ "${#validPrices[@]}" -ne "${#validSources[@]}" ]]; then
		error "Error - Failed to fetch sufficient valid prices from sources."
		return
	fi

	#Get latest message for asset pair
	latestMsg=$(pullLatestFeedMsgOfType "$SCUTTLEBOT_FEED_ID" "$_assetPair")

	if [ "$(isEmpty "$latestMsg")" == "false" ] \
		&& [ "$(isAssetPair "$_assetPair" "$latestMsg")" == "true" ] \
		&& [ "$(isMsgExpired "$_assetPair" "$latestMsg")" == "false" ] \
		&& [ "$(isMsgStale "$_assetPair" "$latestMsg" "$median")" == "false" ]; then
		return
	fi

	#Get timestamp
	time=$(timestampS)
	if [[ ! "$time" =~ ^[1-9]{1}[0-9]{9}$ ]]; then
		error "Error - Got invalid timestamp"
		debug "Invalid Timestamp = $time"
		return
	fi

	#Convert timestamp to hex
	timeHex=$(time2Hex "$time")
	timeHex=${timeHex#"0x"}
	if [[ ! "$timeHex" =~ ^[0-9a-fA-F]{64}$ ]]; then
		error "Error - Failed to convert timestamp to hex"
		debug "Timestamp = $time"
		debug "Invalid Timestamp Hex = $timeHex"
		return
	fi

	#Convert median to hex
	medianHex=$(price2Hex "$median")
	medianHex=${medianHex#"0x"}
	if [[ ! "$medianHex" =~ ^[0-9a-fA-F]{64}$ ]]; then
		error "Error - Failed to convert median to hex:"
		debug "Median = $median"
		debug "Invalid Median Hex = $medianHex"
		return
	fi

	#Convert asset pair to hex
	assetPairHex=$(seth --to-bytes32 "$(seth --from-ascii "$_assetPair")")
	assetPairHex=${assetPairHex#"0x"}
	if [[ ! "$assetPairHex" =~ ^[0-9a-fA-F]{64}$ ]]; then
		error "Error - Failed to convert asset pair to hex:"
		debug "Asset Pair = $_assetPair"
		debug "Invalid Asset Pair Hex = $assetPairHex"
		return
	fi

	#Create hash
	hash=$(keccak256Hash "0x" "$medianHex" "$timeHex" "$assetPairHex")
	if [[ ! "$hash" =~ ^(0x){1}[0-9a-fA-F]{64}$ ]]; then
		error "Error - failed to generate valid hash"
		debug "Median Hex = $medianHex"
		debug "Timestamp Hex = $timeHex"
		debug "Asset Pair Hex = $assetPairHex"
		debug "Invalid Hash = $hash"
		return
	fi

	#Sign hash
	sig=$(signMessage "$hash")
	if [[ ! "$sig" =~ ^(0x){1}[0-9a-f]{130}$ ]]; then
		error "Error - Failed to generate valid signature"
		debug "Hash = $hash"
		debug "Invalid Signature = $sig"
		return
	fi

	#broadcast message to scuttelbot
	broadcastPriceMsg "$_assetPair" "$median" "$medianHex" "$time" "$timeHex" "$hash" "$sig" "${validSources[@]}" "${validPrices[@]}"
}

readSources() {
	local _assetPair="$1"

	if [[ "$OMNIA_FEED_SOURCE" == "setzer" ]]; then
		readSourcesWithSetzer "$_assetPair"
	elif [[ "$OMNIA_FEED_SOURCE" == "gofer" ]]; then
		readSourcesWithGofer "$_assetPair"
	else
		error "Error - Unknown Feed Source: $OMNIA_FEED_SOURCE"
		return
	fi
}
