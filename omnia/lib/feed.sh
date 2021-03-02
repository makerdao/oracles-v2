#!/usr/bin/env bash

readSourcesAndBroadcastAllPriceMessages()  {
	if [[ "${#assetPairs[@]}" -eq 0 || "${#OMNIA_FEED_SOURCES[@]}" -eq 0 || "${#OMNIA_TRANSPORTS[@]}" -eq 0 ]]
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
			_assetPair="${_assetPair^^}"
			_assetPair="${_assetPair/\/}"
			local _median=$(jq -r .median <<<"$_json")
			local _sources=$(jq -rS '.sources' <<<"$_json")
			local	_message=$(validateAndConstructMessage "$_assetPair" "$_median"	"$_sources")

			if [[ -z "$_message" ]]; then
				error "Failed constructing $_assetPair price message"
				continue
			fi

			unset _unpublishedPairs[$_assetPair]

			transportPublish "$_assetPair" "$_message"
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
	local _starkSignatureR="$9"
	local _starkSignatureS="${10}"
	local _starkPublicKey="${11}"
	local _starkSignature
	local _jqArgs=()
	local _json

	#format starkware sig
	_starkSignature=(
		--arg r "$_starkSignatureR"
		--arg s "$_starkSignatureS"
		--arg publicKey "$_starkPublicKey"
	)

	if ! _starkSignatureJson=$(jq -nce  "${_starkSignature[@]}" '{r: $r, s:$s, publicKey:$publicKey}'); then
		error "Error - failed to generate stark signature json"
	fi

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
		--argjson starkSignature "$_starkSignatureJson"
	)

	# generate JSON msg
	if ! _json=$(jq -nce "${_jqArgs[@]}" '{type: $assetPair, version: $version, price: $price | tonumber, priceHex: $priceHex, time: $time | tonumber, timeHex: $timeHex, hash: $hash, signature: $signature, sources: $sourcePrices, starkSignature: $starkSignature}'); then
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
	constructMessage "$_assetPair" "$median" "$medianHex" "$time" "$timeHex" \
		"$hash" "$sig" "$sourcePrices" "$starkSigR" "$starkSigS" "$STARK_PUBLIC_KEY"
}
