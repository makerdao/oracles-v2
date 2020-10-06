#!/usr/bin/env bash

#publish new price messages for all assets
readSourcesAndBroadcastAllPriceMessages()  {
	local _feed_source="$OMNIA_FEED_SOURCE"

	for assetPair in "${assetPairs[@]}"; do
		readSourceAndBroadcastPriceMessage "$assetPair"
		if [[ "$_feed_source" == "gofer" ]]
		then
			OMNIA_FEED_SOURCE="setzer"
			readSourceAndBroadcastPriceMessage "$assetPair"
			OMNIA_FEED_SOURCE="$_feed_source"
		fi
	done
}

readSourceAndBroadcastPriceMessage() {
	validSources=()
	validPrices=()
	median=0

	log "Querying ${assetPair^^} prices and calculating median..."
	readSources "$1"

	if [[ "${median}" -eq 0 ]] || [[ "$(isPriceValid "$median")" == "false" ]]; then
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
	latestMsg=$(pullLatestFeedMsgOfType "$SCUTTLEBOT_FEED_ID" "$assetPair")

	if [ "$(isEmpty "$latestMsg")" == "false" ] \
		&& [ "$(isAssetPair "$assetPair" "$latestMsg")" == "true" ] \
		&& [ "$(isMsgExpired "$assetPair" "$latestMsg")" == "false" ] \
		&& [ "$(isMsgStale "$assetPair" "$latestMsg" "$median")" == "false" ]; then
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
	assetPairHex=$(seth --to-bytes32 "$(seth --from-ascii "$assetPair")")
	assetPairHex=${assetPairHex#"0x"}
	if [[ ! "$assetPairHex" =~ ^[0-9a-fA-F]{64}$ ]]; then
		error "Error - Failed to convert asset pair to hex:"
		debug "Asset Pair = $assetPair"
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

	#generate stark hash message
	assetPairHexShortened=$(echo "$assetPairHex" | cut -c1-32)
	starkHash=$("$STARK_CLI" --method "hash" --time "$timeHex" --price "$medianHex" --oracle "4d616b6572" --asset "$assetPairHexShortened")
	if [[ ! "$starkHash" =~ ^[0-9a-fA-F]{1,64}$ ]]; then
		error "Error - failed to generate valid stark hash"
		debug "Median Hex = $medianHex"
		debug "Timestamp Hex = $timeHex"
		debug "Asset Pair Hex = $assetPairHexShortened"
		debug "Invalid Hash = $starkHash"
		continue
	fi

	#generate stark sig
	starkSig=$("$STARK_CLI" --method "sign" --data "$starkHash" --key "$STARK_PRIVATE_KEY")
	if [[ ! "$starkSig" =~ ^0x[0-9a-f]{1,64}[[:space:]]0x[0-9a-f]{1,64}$ ]]; then
		error "Error - Failed to generate valid stark signature"
		debug "Hash = $starkHash"
		debug "Invalid Signature = $starkSig"
		continue
	fi
	starkSigR=$(echo "$starkSig" | cut -d " " -f1)
	starkSigS=$(echo "$starkSig" | cut -d " " -f2)

	#broadcast message to scuttelbot
	broadcastPriceMsg "$assetPair" "$median" "$medianHex" "$time" "$timeHex" "$hash" "$sig" "$starkSigR" "$starkSigS" "$STARK_PUBLIC_KEY" "${validSources[@]}" "${validPrices[@]}"
}
