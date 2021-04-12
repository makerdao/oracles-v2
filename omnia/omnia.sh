#!/usr/bin/env bash

if [[ -n $OMNIA_DEBUG ]]; then
	env
	set -x
fi

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
	OMNIA_VERSION="$(cat ./version)"

	#Load Global configuration
  	importEnv

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
	echo "------------------------------- STARTING OMNIA -------------------------------"
  	echo "Bot started $(date)"
  	echo "Omnia Version:                     V$OMNIA_VERSION"
  	echo "Mode:                              $OMNIA_MODE"
  	echo "Verbose Mode:                      $OMNIA_VERBOSE"
  	echo "Interval:                          $OMNIA_INTERVAL seconds"
  	echo ""
  	echo "ETHEREUM"
  	[[ $OMNIA_MODE == "RELAYER" ]] && echo "Network:                           $ETH_RPC_URL"
	echo "Ethereum account:                  $ETH_FROM"
	echo ""
	echo "SCUTTLEBOT"
	echo "Feed address:                      $SCUTTLEBOT_FEED_ID"
	[[ $OMNIA_MODE == "RELAYER" ]] && echo "   Peers:"
	for feed in "${feeds[@]}"; do
		printf '                                   %s\n' "$feed"
	done
	echo ""
	echo "ORACLE"
	for assetPair in "${assetPairs[@]}"; do
		printf '   %s\n' "$assetPair" 
		[[ $OMNIA_MODE == "RELAYER" ]] && printf '      Oracle Address:              %s\n' "$(getOracleContract "$assetPair")"
		printf '      Message Expiration:          %s seconds\n' "$(getMsgExpiration "$assetPair")"
		[[ $OMNIA_MODE == "FEED" ]] && printf '      Message Spread:              %s %% \n' "$(getMsgSpread "$assetPair")"
		[[ $OMNIA_MODE == "RELAYER" ]] && printf '      Oracle Expiration:           %s seconds\n' "$(getOracleExpiration "$assetPair")"
		[[ $OMNIA_MODE == "RELAYER" ]] && printf '      Oracle Spread:               %s %% \n' "$(getOracleSpread "$assetPair")"
	done
	echo ""
	echo "-------------------------- INITIALIZATION COMPLETE ---------------------------"
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

		log "Querying ${assetPair^^} prices and calculating median..."
		readSources "$assetPair"

		if [[ "${#validPrices[@]}" -lt 2 ]] || [[ "${#validSources[@]}" -lt 2 ]] || [[ "${#validPrices[@]}" -ne "${#validSources[@]}" ]]; then
			error "Error - Failed to fetch sufficient valid prices from sources."
			continue
		fi

		if [ "$(isPriceValid "$median")" == "false" ]; then
			error "Error - Failed to calculate valid median: ($median)"
			debug "Sources = ${validSources[*]}"
			debug "Prices = ${validPrices[*]}"
			continue
		fi

		#Get latest message for asset pair
		latestMsg=$(pullLatestFeedMsgOfType "$SCUTTLEBOT_FEED_ID" "$assetPair")

		if [ "$(isEmpty "$latestMsg")" == "false" ] \
		&& [ "$(isAssetPair "$assetPair" "$latestMsg")" == "true" ] \
		&& [ "$(isMsgExpired "$assetPair" "$latestMsg")" == "false" ] \
		&& [ "$(isMsgStale "$assetPair" "$latestMsg" "$median")" == "false" ]
		then
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
		medianHex=$(price2Hex "$median")
		if [[ ! "$medianHex" =~ ^[0-9a-fA-F]{64}$ ]]; then
			error "Error - Failed to convert median to hex:"
			debug "Median = $median"
			debug "Invalid Median Hex = $medianHex"
			continue
		fi

		#Convert asset pair to hex
		assetPairHex=$(seth --to-bytes32 "$(seth --from-ascii "$assetPair")" | sed s/^0x//)
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
