#!/usr/bin/env bash

declare -a assets=("eth" "mkr" "rep" "poly")
declare -a feeds=("@SoGPH4un5Voz98oAZIbo4hYftc4slv4A+OHXPGCFHpA=.ed25519" "@aS9pDFHSTfy2CY0PsO0hIpnY1BYgcpdGL2YWXHc73lI=.ed25519") 
#"@lplSEbzl8cEDE7HTLQ2Fk2TasjZhEXbEzGzKBFQvVvc=.ed25519"
#"@4wuvO7zjo4Cp71w1mUJBOXbRAZjtr91rt7bpfhcEDmE=.ed25519"

. ethereum.sh
. log.sh
. scuttlebot.sh
. source.sh
. status.sh
. util.sh
. relayer.sh

#initialize environment
initEnv () {
	OMNIA_VERSION="0.7.9"

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
	[[ $OMNIA_ETH_ORACLE_ADDR ]] || errors+=("No Oracle contract address set. Please set it via OMNIA_ETH_ORACLE_ADDR ")
	[[ $OMNIA_MKR_ORACLE_ADDR ]] || errors+=("No Oracle contract address set. Please set it via OMNIA_MKR_ORACLE_ADDR ")
	[[ $OMNIA_REP_ORACLE_ADDR ]] || errors+=("No Oracle contract address set. Please set it via OMNIA_REP_ORACLE_ADDR ")
	[[ $OMNIA_POLY_ORACLE_ADDR ]] || errors+=("No Oracle contract address set. Please set it via OMNIA_POLY_ORACLE_ADDR ")

	export SCUTTLEBOT_FEED_ID=$(getFeedId)
	[[ $SCUTTLEBOT_FEED_ID ]] || errors+=("Could not get scuttlebot feed id, make sure scuttlebot server is running ")

	[[ ${errors[*]} ]] && { printf '%s\n' "${errors[@]}"; exit 1; }

	#Set default configuration if none found
	[[ $OMNIA_INTERVAL ]] || export OMNIA_INTERVAL=60
	[[ $OMNIA_MSG_SPREAD ]] || export OMNIA_MSG_SPREAD=1
	[[ $OMNIA_MSG_EXPIRY_INTERVAL ]] || export OMNIA_MSG_EXPIRY_INTERVAL=180
	[[ $OMNIA_ORACLE_SPREAD ]] || export OMNIA_ORACLE_SPREAD=1
	[[ $OMNIA_ORACLE_EXPIRY_INTERVAL ]] || export OMNIA_ORACLE_EXPIRY_INTERVAL=3600

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
	echo "ETH Oracle address:                $OMNIA_ETH_ORACLE_ADDR"
	echo "MKR Oracle address:                $OMNIA_MKR_ORACLE_ADDR"
	echo "REP Oracle address:                $OMNIA_REP_ORACLE_ADDR"
	echo "POLY Oracle address:               $OMNIA_POLY_ORACLE_ADDR"
	echo "Spread to update:                  $OMNIA_ORACLE_SPREAD %"
	echo "Price expiration interval          $OMNIA_ORACLE_EXPIRY_INTERVAL seconds"
	echo ""
	echo "Verbose Mode:                      $OMNIA_VERBOSE"
	echo "Relay Mode:                        $OMNIA_RELAY"
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
		log "Querying ${asset^^} prices..."
		readSources "$asset"
		median=$(getMedian "${validPrices[@]}")
		verbose "-> median = $median"
		latestMsg=$(pullLatestFeedMsgOfType "$SCUTTLEBOT_FEED_ID" "$asset")
		if [ "$(isEmpty "$latestMsg")" == "true" ] || [ "$(isAsset "$asset" "$latestMsg")" == "false" ] || [ "$(isMsgExpired "$latestMsg")" == "true" ] || [ "$(isMsgStale "$latestMsg" "$median")" == "true" ]; then
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

oracle () {
	initEnv
	while true; do
		execute
		verbose "sleeping for $OMNIA_INTERVAL seconds"
		sleep $OMNIA_INTERVAL
	done
}

relayer () {
	initEnv
	updateOracle
	#for asset in "${assets[@]}"; do
	#	pullLatestPricesOfAsset "$asset"
	#done
}

relayer
oracle