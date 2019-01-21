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
	OMNIA_VERSION="0.8.8"

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
		readSources "$assetPair"
		median=$(getMedian "${validPrices[@]}")
		verbose "-> median = $median"
		latestMsg=$(pullLatestFeedMsgOfType "$SCUTTLEBOT_FEED_ID" "$assetPair")
		if [ "$(isEmpty "$latestMsg")" == "true" ] || [ "$(isAssetPair "$assetPair" "$latestMsg")" == "false" ] || [ "$(isMsgExpired "$latestMsg")" == "true" ] || [ "$(isMsgStale "$latestMsg" "$median")" == "true" ]; then
			time=$(timestampS)
			timeHex=$(time2Hex "$time")
			medianHex=$(price2Hex "$median" "$assetPair")
			assetPairHex=$(seth --to-bytes32 "$(seth --from-ascii "$assetPair")")
			hash=$(keccak256Hash "0x" "$medianHex" "$timeHex" "$assetPairHex")
			sig=$(signMessage "$hash")
			verbose "-> Message Signature = $sig"
			broadcastPriceMsg "$assetPair" "$median" "$medianHex" "$time" "$timeHex" "$hash" "$sig" "${validSources[@]}" "${validPrices[@]}"
		fi
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