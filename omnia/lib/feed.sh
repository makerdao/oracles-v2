#!/usr/bin/env bash

readSourcesAndBroadcastAllPriceMessages()  {
	if [[ "${#assetPairs[@]}" -eq 0 || "${#OMNIA_FEED_SOURCES[@]}" -eq 0 || "${#OMNIA_FEED_PUBLISHERS[@]}" -eq 0 ]]
	then
		error "Error - Loop in readSourcesAndBroadcastAllPriceMessages"
		return 1
	fi

	for _assetPair in "${assetPairs[@]}"; do
		local _message

		for _src in "${OMNIA_FEED_SOURCES[@]}"; do
			_message=$(readSourcesAndConstructPriceMessage "$_src" "$_assetPair")

			if [[ -z "$_message" ]]; then
				error "Failed constructing $_assetPair price from $_src"
				continue
			fi
			verbose "$_message"
			break
		done

		if [[ -z "$_message" ]]; then
			error "Failed constructing $_assetPair price message"
			continue
		fi

		local _publisher
		for _publisher in "${OMNIA_FEED_PUBLISHERS[@]}"; do
			log "Publishing $_assetPair price message with $_publisher"
			"$_publisher" publish "$_message" || error "Failed publishing $_assetPair price with $_publisher"
		done
	done
}

readSourcesAndConstructPriceMessage() {
	local _src="$1"
	local _assetPair="$2"

	validSources=()
	validPrices=()
	median=0

	log "Querying ${_assetPair} prices and calculating median..."
	readSource "$_assetPair" "$_src"

	if [[ "$(isPriceValid "$median")" == "false" ]]; then
		error "Error - Failed to calculate valid median: ($median)"
		debug "Sources = ${validSources[*]}"
		debug "Prices = ${validPrices[*]}"
		return 1
	fi

	if [[ "${#validPrices[@]}" -lt 2 ]] || [[ "${#validSources[@]}" -lt 2 ]] || [[ "${#validPrices[@]}" -ne "${#validSources[@]}" ]]; then
		error "Error - Failed to fetch sufficient valid prices from sources."
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

	verbose "Constructing message..."
	constructMessage "$_assetPair" "$median" "$medianHex" "$time" "$timeHex" "$hash" "$sig" "$starkSigR" "$starkSigS" "$STARK_PUBLIC_KEY" \
		"${validSources[*]}" \
		"${validPrices[*]}"
}

readSource() {
	local _src="${1,,}"
	local _assetPair="$2"

	if [[ "$_src" == "setzer" ]]; then
		_assetPair="${_assetPair,,}"
		_assetPair="${_assetPair/\/}"
		readSourcesWithSetzer "$_assetPair"
	elif [[ "$_src" == "gofer" ]]; then
		_assetPair="${_assetPair^^}"
		readSourcesWithGofer "$_assetPair"
	else
		error "Error - Unknown Feed Source: $OMNIA_FEED_SOURCE"
		return 1
	fi
}

constructMessage() {
	local _assetPair="$1"
	local _price="$2"
	local _priceHex="$3"
	local _time="$4"
	local _timeHex="$5"
	local _hash="$6"
	local _signature="$7"
  local _starkSignatureR="$8"
  local _starkSignatureS="$9"
  local _starkPublicKey="$10"
	local _validSources=($11)
	local _validPrices=($12)
  local _sourcePrices
  local _jqArgs=()
  local _json

	# generate JSON for transpose of sources with prices
	if ! _sourcePrices=$(jq -nce --argjson vs "$(printf '%s\n' "${_validSources[@]}" | jq -nR '[inputs]')" --argjson vp "$(printf '%s\n' "${_validPrices[@]}" | jq -nR '[inputs]')" '[$vs, $vp] | transpose | map({(.[0]): .[1]}) | add'); then
			error "Error - failed to transpose sources with prices"
			return 1
	fi

	#format starkware sig
	_starkSignature=( --arg r "$_starkSignatureR" --arg s "$_starkSignatureS" --arg publicKey "$_starkPublicKey" )
	if ! _starkSignatureJson=$(jq -nce  "${_starkSignature[@]}" '{r: $r, s:$s, publicKey:$publicKey}'); then
	    error "Error - failed to generate stark signature json"
	fi
	#compose jq message arguments
	_jqArgs=( --arg assetPair "$_assetPair" --arg version "$OMNIA_VERSION" --arg price "$_price" --arg priceHex "$_priceHex" --arg time "$_time" --arg timeHex "$_timeHex" --arg hash "${_hash:2}" --arg signature "${_signature:2}" --argjson starkSignature "$_starkSignatureJson" --argjson sourcePrices "$_sourcePrices" )

	#generate JSON msg
	if ! _json=$(jq -ne "${_jqArgs[@]}" '{type: $assetPair, version: $version, price: $price | tonumber, priceHex: $priceHex, time: $time | tonumber, timeHex: $timeHex, hash: $hash, signature: $signature, starkSignature: $starkSignature, sources: $sourcePrices}'); then
	    error "Error - failed to generate JSON msg"
	    return 1
	fi

	echo "$_json"
}
