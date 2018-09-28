#!/usr/bin/env bash

declare -a assets=("eth" "mkr" "rep" "poly")

. log.sh
. scuttlebot.sh
. source.sh
. status.sh
. util.sh

#initialize environment
initEnv () {
	OMNIA_VERSION="0.7.0"

	# Global configuration
	if [[ -e /etc/omnia.conf ]]; then
  		# shellcheck source=/dev/null
  		. "/etc/omnia.conf"
  		verbose "Imported configuration from /etc/omnia.conf"
	fi

	# Local configuration (via -C or --config)
	if [[ -e $OMNIA_CONF ]]; then
		# shellcheck source=/dev/null
  		. "$SETZER_CONF"
  		verbose "Imported configuration from $OMNIA_CONF"
	fi

	# Verify required env params 
	[[ $ETH_FROM ]] || errors+=("No default account set. Please set it via ETH_FROM ")
	[[ $ETH_KEYSTORE ]] || errors+=("No path to keystore file set. Please set it via ETH_KEYSTORE ")
	[[ $ETH_PASSWORD ]] || errors+=("No path to password set. Please set it via ETH_PASSWORD ")

	export SCUTTLEBOT_FEED_ID=$(getFeedId)
	[[ $SCUTTLEBOT_FEED_ID ]] || errors+=("Could not get scuttlebot feed id, make sure scuttlebot server is running ")

	[[ ${errors[*]} ]] && { printf '%s\n' "${errors[@]}"; exit 1; }

	#Set default configuration if none found
	[[ $OMNIA_SPREAD ]] || export OMNIA_SPREAD=2
	[[ $OMNIA_EXPIRY_INTERVAL_MS ]] || export OMNIA_EXPIRY_INTERVAL_MS=600000
	[[ $OMNIA_INTERVAL_SECONDS ]] || export OMNIA_INTERVAL_SECONDS=60

	echo ""
	echo "--------- STARTING OMNIA ---------"
  	echo "Bot started $(date)"
  	echo "Omnia Version:               V$OMNIA_VERSION"
	echo "Ethereum account:            $ETH_FROM"
	echo "Feed address:                $SCUTTLEBOT_FEED_ID"
	echo ""
	echo "Spread to update:            $OMNIA_SPREAD %"
	echo "Price check interval:        $OMNIA_INTERVAL_SECONDS seconds"
	echo "Price expiration interval:   $OMNIA_EXPIRY_INTERVAL_MS ms"
	echo ""
	echo "Verbose Mode:                $OMNIA_VERBOSE"
	echo "------- INITIALIZATION COMPLETE -------"
	echo ""
}

#init/clear price and source data
initStorage () {
	validSources=()
	validPrices=()
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
	for asset in "${assets[@]}"; do
		initStorage
		log "Querying ${asset^^} prices..."s
		readSources "$asset"
		median=$(getMedian "${validPrices[@]}")
		verbose "-> median = $median"
		latestMsg=$(pullLatestFeedMsgOfType "$SCUTTLEBOT_FEED_ID" "$asset")
		if [ "$(isEmpty "$latestMsg")" == "true" ] || [ "$(isAsset "$asset" "$latestMsg")" == "false" ] || [ "$(isExpired "$latestMsg")" == "true" ] || [ "$(isPriceStale "$latestMsg" "$median")" == "true" ]; then
			time=$(timestampS)
			timeHex=$(time2Hex "$time")
			medianHex=$(price2Hex "$median")
			hash=$(keccak256Hash "$medianHex" "$timeHex")
			sig=$(signMessage "$hash")
			verbose "-> Message Signature = $sig"
			broadcastPriceMsg "$asset" "$median" "$medianHex" "$time" "$timeHex" "$hash" "$sig" "${validSources[@]}" "${validPrices[@]}"
		fi
	done
}

auto () {
	initEnv
	while true; do
		execute
		verbose "sleeping for $OMNIA_INTERVAL_SECONDS seconds"
		sleep $OMNIA_INTERVAL_SECONDS
	done
}

auto