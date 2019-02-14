#!/usr/bin/env bash

# shellcheck source=./config.sh
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
	OMNIA_VERSION="0.9.3"

	#Load Global configuration
  	importEnv

  	if [[ $OMNIA_MODE == "FEED" ]]; then
	  	echo ""
	  	echo ""
		echo "  /\$\$\$\$\$\$                          /\$\$                                "          
		echo " /\$\$__  \$\$                        |__/                                    "          
		echo "| \$\$  \ \$\$ /\$\$\$\$\$\$/\$\$\$\$  /\$\$\$\$\$\$\$  /\$\$  /\$\$\$\$\$\$  "
		echo "| \$\$  | \$\$| \$\$_  \$\$_  \$\$| \$\$__  \$\$| \$\$ |____  \$\$            "
		echo "| \$\$  | \$\$| \$\$ \ \$\$ \ \$\$| \$\$  \ \$\$| \$\$  /\$\$\$\$\$\$\$       "
		echo "| \$\$  | \$\$| \$\$ | \$\$ | \$\$| \$\$  | \$\$| \$\$ /\$\$__  \$\$          "
		echo "|  \$\$\$\$\$\$/| \$\$ | \$\$ | \$\$| \$\$  | \$\$| \$\$|  \$\$\$\$\$\$\$     "
		echo " \______/ |__/ |__/ |__/|__/  |__/|__/ \_______/                              "
		echo ""
		echo ""
	fi
	echo "-------------------- STARTING OMNIA --------------------"
  	echo "Bot started $(date)"
  	echo "Omnia Version:                     V$OMNIA_VERSION"
  	echo "Mode:                              $OMNIA_MODE"
  	echo "Verbose Mode:                      $OMNIA_VERBOSE"
  	echo "Interval:                          $OMNIA_INTERVAL seconds"
  	echo ""
  	echo "ETHEREUM"
  	echo "Network:                           $ETH_RPC_URL"
	echo "Ethereum account:                  $ETH_FROM"
	echo ""
	echo "SCUTTLEBOT"
	echo "Feed address:                      $SCUTTLEBOT_FEED_ID"
	[[ $OMNIA_MODE == "RELAYER" ]] && echo "   Peers:"
	for feed in "${feeds[@]}"; do
		printf '                                  %s\n' "$feed"
	done
	echo ""
	echo "ORACLE"
	for assetPair in "${assetPairs[@]}"; do
		printf '   %s\n' "$assetPair" 
		[[ $OMNIA_MODE == "RELAYER" ]] && printf '      Oracle Address:             %s\n' "$(getOracleContract "$assetPair")"
		[[ $OMNIA_MODE == "FEED" ]] && printf '      Message Spread:             %s %% \n' "$(getMsgSpread "$assetPair")"
		printf '      Message Expiration:         %s seconds\n' "$(getMsgExpiration "$assetPair")"
		[[ $OMNIA_MODE == "RELAYER" ]] && printf '      Oracle Spread:              %s %% \n' "$(getOracleSpread "$assetPair")"
		[[ $OMNIA_MODE == "RELAYER" ]] && printf '      Oracle Expiration:          %s seconds\n' "$(getOracleExpiration "$assetPair")"
		printf '      Decimals:                   %s\n' "$(getTokenDecimals "$assetPair")"
	done
	echo ""
	echo "--------------- INITIALIZATION COMPLETE ----------------"
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
			error "Error - Failed to fetch valid prices from sources."
			continue
		fi

		#Calculate median of prices
		median=$(getMedian "${validPrices[@]}")
		verbose "median => $median"
		if [[ ! "$median" =~ ^([1-9][0-9]*([.][0-9]+)?|[0][.][0-9]*)$ ]]; then
			error "Error - Failed to calculate valid median:"
			debug "Sources = ${validSources[*]}"
			debug "Prices = ${validPrices[*]}"
			debug "Invalid Median = $median"
			continue
		fi

		 #Get latest message for this asset pair
		latestMsg=$(pullLatestFeedMsgOfType "$SCUTTLEBOT_FEED_ID" "$assetPair")
			
		if [ "$(isEmpty "$latestMsg")" == "false" ] && [ "$(isAssetPair "$assetPair" "$latestMsg")" == "true" ] && [ "$(isMsgExpired "$assetPair" "$latestMsg")" == "false" ] && [ "$(isMsgStale "$assetPair" "$latestMsg" "$median")" == "false" ]; then
			#TODO make the above functions print out a message when they hit
			continue
		fi

		#Get timestamp
		time=$(timestampS)
		if [[ ! "$time" =~ ^[1-9]{1}[0-9]{9}$ ]]; then
			error "Error - Got invalid timestamp"
			debug "Invalid Timestamp = $time"
			continue
		fi

		#Convert timestamp to hex
		timeHex=$(time2Hex "$time")
		if [[ ! "$timeHex" =~ ^[0-9a-fA-F]{64}$ ]]; then
			error "Error - Failed to convert timestamp to hex"
			debug "Timestamp = $time"
			debug "Invalid Timestamp Hex = $timeHex"
			continue
		fi

		#Convert median to hex
		medianHex=$(price2Hex "$median" "$assetPair")
		if [[ ! "$medianHex" =~ ^[0-9a-fA-F]{64}$ ]]; then
			error "Error - Failed to convert median to hex:"
			debug "Median = $median"
			debug "Invalid Median Hex = $medianHex"
			continue
		fi

		#Convert asset pair to hex
		assetPairHex=$(seth --to-bytes32 "$(seth --from-ascii "$assetPair")")
		if [[ ! "$assetPairHex" =~ ^[0-9a-fA-F]{64}$ ]]; then
			error "Error - Failed to convert asset pair to hex:"
			debug "Asset Pair = $assetPair"
			debug "Invalid Asset Pair Hex = $assetPairHex"
			continue
		fi

		#Create hash
		hash=$(keccak256Hash "0x" "$medianHex" "$timeHex" "$assetPairHex")
		if [[ ! "$hash" =~ ^(0x){1}[0-9a-fA-F]{64}$ ]]; then
			error "Error - failed to generate valid hash"
			debug "Median Hex = $medianHex"
			debug "Timestamp Hex = $timeHex"
			debug "Asset Pair Hex = $assetPairHex"
			debug "Invalid Hash = $hash"
			continue
		fi

		#Sign hash
		sig=$(signMessage "$hash")
		if [[ ! "$sig" =~ ^(0x){1}[0-9a-f]{130}$ ]]; then
			error "Error - Failed to generate valid signature"
			debug "Hash = $hash"
			debug "Invalid Signature = $sig"
			continue
		fi

		#broadcast message to scuttelbot
		broadcastPriceMsg "$assetPair" "$median" "$medianHex" "$time" "$timeHex" "$hash" "$sig" "${validSources[@]}" "${validPrices[@]}"
	
	done
}

runFeed () {
	while true; do
		execute
		verbose "Sleeping for $OMNIA_INTERVAL seconds..."
		sleep "$OMNIA_INTERVAL"
	done
}

runRelayer () {
    while true; do
		updateOracle
		verbose "Sleeping $OMNIA_INTERVAL seconds.."
		sleep "$OMNIA_INTERVAL"
    done
}

initEnv
[ "$OMNIA_MODE" == "RELAYER" ] && runRelayer
[ "$OMNIA_MODE" == "FEED" ] && runFeed