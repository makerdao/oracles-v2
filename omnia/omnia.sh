#!/usr/bin/env bash
declare -a feeds=("@SoGPH4un5Voz98oAZIbo4hYftc4slv4A+OHXPGCFHpA=.ed25519" "@aS9pDFHSTfy2CY0PsO0hIpnY1BYgcpdGL2YWXHc73lI=.ed25519" "@lplSEbzl8cEDE7HTLQ2Fk2TasjZhEXbEzGzKBFQvVvc=.ed25519" "@EbPRv+q8uPZBd9C+ATINR7gRKgRC4eNz3a0NGMoneak=.ed25519")

. config.sh
. ethereum.sh
. log.sh
. scuttlebot.sh
. source.sh
. status.sh
. util.sh
. relayer.sh

#initialize environment
initEnv () {
	OMNIA_VERSION="0.8.9"

	#Load Global configuration
  	importEnv

	echo ""
	echo "--------- STARTING OMNIA ---------"
  	echo "Bot started $(date)"
  	echo "Omnia Version:                     V$OMNIA_VERSION"
	echo "Ethereum account:                  $ETH_FROM"
	echo "Price check interval:              $OMNIA_INTERVAL seconds"
	echo ""
	echo "SCUTTLEBOT"
	echo "Feed address:                      $SCUTTLEBOT_FEED_ID"
	echo "Spread to update:                  $OMNIA_MSG_SPREAD %"
	echo "Price expiration interval:         $OMNIA_MSG_EXPIRY_INTERVAL seconds"
	echo ""
	echo "ORACLE"
	for assetPair in "${assetPairs[@]}"
	do
		printf '%s Oracle Address:             %s\n' "$assetPair" "$(lookupOracleContract "$assetPair")"
	done
	echo "Spread to update:                  $OMNIA_ORACLE_SPREAD %"
	echo "Price expiration interval          $OMNIA_ORACLE_EXPIRY_INTERVAL seconds"
	echo ""
	echo "Verbose Mode:                      $OMNIA_VERBOSE"
	echo "Relayer Mode:                      $OMNIA_RELAYER"
	echo "------- INITIALIZATION COMPLETE -------"
	echo ""
}

#sign message
signMessage () {
	local _data
	for arg in "$@"; do
		_data+="$arg"
	done
	verbose "Signing message..."
    ethsign message --from "$ETH_FROM" --key-store "$ETH_KEYSTORE" --passphrase-file "$ETH_PASSWORD" --data "$_data"
}

#publish new price messages for all assets
execute () {
	for assetPair in "${assetPairs[@]}"; do
		validSources=()
		validPrices=()

		log "Querying ${assetPair^^} prices..."
		#Query prices of asset pair
		readSources "$assetPair"
		if [[ "${#validPrices[@]}" -eq 0 ]] || [[ "${#validSources[@]}" -eq 0 ]] || [[ "${#validPrices[@]}" -ne "${#validSources[@]}" ]]; then
			error "Failed to fetch valid prices from sources."
			continue
		fi

		#Calculate median of prices
		median=$(getMedian "${validPrices[@]}")
		verbose "median => $median"
		if [[ ! "$median" =~ ^([1-9][0-9]*([.][0-9]+)?|[0][.][0-9]*)$ ]]; then
			error "Error - Failed to calculate valid median:"
			error "Sources = ${validSources[*]}"
			error "Prices = ${validPrices[*]}"
			error "Invalid median = $median"
			continue
		fi

		 #Get latest message for this asset pair
		latestMsg=$(pullLatestFeedMsgOfType "$SCUTTLEBOT_FEED_ID" "$assetPair")
			

		if [ "$(isEmpty "$latestMsg")" == "false" ] && [ "$(isAssetPair "$assetPair" "$latestMsg")" == "true" ] && [ "$(isMsgExpired "$latestMsg")" == "false" ] && [ "$(isMsgStale "$latestMsg" "$median")" == "false" ]; then
			continue
		fi

		#Get timestamp
		time=$(timestampS)
		if [[ ! "$time" =~ ^[1-9]{1}[0-9]{9}$ ]]; then
			error "Error - Got invalid timestamp"
			error "Timestamp = $time"
			continue
		fi

		#Convert timestamp to hex
		timeHex=$(time2Hex "$time")
		if [[ ! "$timeHex" =~ ^[0-9a-fA-F]{64}$ ]]; then
			error "Error - Failed to convert timestamp to hex"
			error "Timestamp = $time"
			error "Hex Timestamp = $timeHex"
			continue
		fi

		#Convert median to hex
		medianHex=$(price2Hex "$median" "$assetPair")
		if [[ ! "$medianHex" =~ ^[0-9a-fA-F]{64}$ ]]; then
			error "Error - Failed to convert median to hex:"
			error "Median = $median"
			error "Hex median = $medianHex"
			continue
		fi

		#Convert asset pair to hex
		assetPairHex=$(seth --to-bytes32 "$(seth --from-ascii "$assetPair")")
		if [[ ! "$assetPairHex" =~ ^[0-9a-fA-F]{64}$ ]]; then
			error "Error - Failed to convert asset pair to hex:"
			error "Asset Pair = $assetPair"
			error "Asset Pair Hex = $assetPairHex"
			continue
		fi

		#Create hash
		hash=$(keccak256Hash "0x" "$medianHex" "$timeHex" "$assetPairHex")

		#Sign hash
		sig=$(signMessage "$hash")
		verbose "-> Message Signature = $sig"

		#broadcast message to scuttelbot
		broadcastPriceMsg "$assetPair" "$median" "$medianHex" "$time" "$timeHex" "$hash" "$sig" "${validSources[@]}" "${validPrices[@]}"
	
	done
}

oracle () {
	while true; do
		execute
		verbose "sleeping for $OMNIA_INTERVAL seconds"
		sleep "$OMNIA_INTERVAL"
	done
}

relayer () {
    while true; do
	updateOracle
	verbose "SLEEPING FOR $OMNIA_INTERVAL seconds"
	sleep "$OMNIA_INTERVAL"
    done
}

initEnv
[ "$OMNIA_RELAYER" == "true" ] && relayer || oracle