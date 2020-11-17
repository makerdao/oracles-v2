#!/usr/bin/env bash

if [[ -n $OMNIA_DEBUG ]]; then
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
. feed.sh
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

runFeed () {
	while true; do
		readSourcesAndBroadcastAllPriceMessages
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
