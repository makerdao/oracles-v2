#!/usr/bin/env bash

importEnv () {
	local config
	if [[ -e /etc/omnia.conf ]]; then
		config="/etc/omnia.conf"
	elif [[ -e ./omnia.conf ]]; then 
		config="./omnia.conf"
	else
		error "Error Could not find omnia.conf config file to load parameters."
		error "Please create /etc/omnia.conf or put it in the working directory."
		exit 1
	fi
	echo "Importing configuration from $config..."

	#check if config file is valid json

	importMode $config
	importEthereumEnv $config
	importAssetPairsEnv $config
	importOptionsEnv $config
	importScuttlebotEnv
	[[ "$OMNIA_MODE" == "RELAYER" ]] && importFeeds $config
}

importMode () {
	local _config="$1"
	OMNIA_MODE="$(jq -r '.mode' < "$_config" | tr '[:lower:]' '[:upper:]')"
	[[ "$OMNIA_MODE" =~ ^(FEED|RELAYER){1}$ ]] || { error "Error - Invalid Mode param, valid values are 'FEED' and 'RELAYER'"; exit 1; }
	export OMNIA_MODE
}

importNetwork () {
	local _json="$1"
	#this parameter is not needed when using a custom rpc node
	INFURA_KEY="$(echo "$_json" | jq -r .infuraKey)"
	[[ -z "$INFURA_KEY" ]] || [[ "$INFURA_KEY" =~ ^[0-9a-f]{32}$ ]] || errors+=("Error - Invalid Infura Key")
	export INFURA_KEY

	network="$(echo "$_json" | jq -r .network)"
	case "${network,,}" in
	ethlive|mainnet)
		ETH_RPC_URL=https://mainnet.infura.io/v3/$INFURA_KEY
		;;
	ropsten|kovan|rinkeby|goerli)
		ETH_RPC_URL=https://${network,,}.infura.io/v3/$INFURA_KEY
		;;
	*)
		#custom RPC endpoint like Ganache or Testchain
		ETH_RPC_URL=$network
		;;
	esac
	#validate connection to ethereum network
	[[ $(seth --rpc-url "$ETH_RPC_URL" block latest number) =~ ^[1-9]*[0-9]*$ ]] || errors+=("Error - Unable to connect to Ethereum network.\nValid options are: ethlive, mainnet, ropsten, kovan, rinkeby, goerli, or a custom endpoint")
	[[ ${errors[*]} ]] && { printf '%s\n' "${errors[@]}"; exit 1; }
	export ETH_RPC_URL
}

importEthereumEnv () {
	local _config="$1"
	local _json

	_json=$(jq -S '.ethereum' < "$_config")

	[[ "$OMNIA_MODE" == "RELAYER" ]] && importNetwork "$_json"


	ETH_FROM="$(echo "$_json" | jq -r '.from')"
	#this just checks for valid chars and length, NOT checksum!
	[[ "$ETH_FROM" =~ ^(0x){1}[0-9a-fA-F]{40}$ ]] || errors+=("Error - Ethereum Address is invalid.")
	export ETH_FROM

	ETH_KEYSTORE="$(echo "$_json" | jq -r '.keystore')"
	#validate path exists
	[[ -d "$ETH_KEYSTORE" ]] || errors+=("Error - Ethereum Keystore Path is invalid, directory does not exist.")
	export ETH_KEYSTORE

	ETH_PASSWORD="$(echo "$_json" | jq -r '.password')"
	#validate file exists
	[[ -f "$ETH_PASSWORD" ]] || errors+=("Error - Ethereum Password Path is invalid, file does not exist.")
	export ETH_PASSWORD

	[[ ${errors[*]} ]] && { printf '%s\n' "${errors[@]}"; exit 1; }
}

importAssetPairsEnv () {
	local _config="$1"
	local _json
	local _decimals
	local _contract
	local _msgExpiration
	declare -gA assetInfo

	_json="$(jq -S '.pairs' < "$_config")"

	#create array of asset pairs
	readarray -t assetPairs < <(echo "$_json" | jq -r 'keys | .[]')

	[[ ${#assetPairs[@]} -eq 0 ]] && { error "Error - Config must have at least 1 asset pair"; exit 1; }

	[[ $OMNIA_MODE == "FEED" ]] && importAssetPairsFeed
	[[ $OMNIA_MODE == "RELAYER" ]] && importAssetPairsRelayer
}

importAssetPairsFeed () {
	local _decimals
	local _msgSpread
	local _msgExpiration

	#verify config is complete
	jq -r '.pairs | keys[] as $assetPair | "\($assetPair)=\(.[$assetPair] | .decimals),\(.[$assetPair] | .msgExpiration),\(.[$assetPair] | .msgSpread)"' "$_config"
	[[ $? -gt 0 ]]

	#Write values as comma seperated list to associative array
	while IFS="=" read -r assetPair info; do
		assetInfo[$assetPair]="$info"
	done < <(jq -r '.pairs | keys[] as $assetPair | "\($assetPair)=\(.[$assetPair] | .decimals),\(.[$assetPair] | .msgExpiration),\(.[$assetPair] | .msgSpread)"' "$_config")

	#Verify values
	for assetPair in "${!assetInfo[@]}"; do
		_decimals=$(getTokenDecimals "$assetPair")
		[[ "$_decimals" =~ ^[1-9][0-9]*$ ]] || errors+=("Error - Asset Pair param $assetPair has invalid decimals field, must be positive integer.")
		
		_msgExpiration=$(getMsgExpiration "$assetPair")
		[[ "$_msgExpiration" =~ ^[1-9][0-9]*$ ]] || errors+=("Error - Asset Pair param $assetPair has invalid msgExpiration field, must be positive integer.")
		
		_msgSpread=$(getMsgSpread "$assetPair")
		[[ "$_msgSpread" =~ ^([1-9][0-9]*([.][0-9]+)?|[0][.][0-9]*[1-9][0-9]*)$ ]] || errors+=("Error - Asset Pair param $assetPair has invalid msgSpread field, must be positive integer or float.")
	done
	[[ ${errors[*]} ]] && { printf '%s\n' "${errors[@]}"; exit 1; }
}

importAssetPairsRelayer () {
	local _decimals
	local _oracle
	local _msgExpiration
	local _oracleSpread
	local _oracleExpiration

	jq -r '.pairs | keys[] as $assetPair | "\($assetPair)=\(.[$assetPair] | .decimals),\(.[$assetPair] | .msgExpiration),\(.[$assetPair] | .oracle),\(.[$assetPair] | .oracleExpiration),\(.[$assetPair] | .oracleSpread)"' "$_config"
	[[ $? -gt 0 ]]

	while IFS="=" read -r assetPair info; do
		assetInfo[$assetPair]="$info"
	done < <(jq -r '.pairs | keys[] as $assetPair | "\($assetPair)=\(.[$assetPair] | .decimals),\(.[$assetPair] | .msgExpiration),\(.[$assetPair] | .oracle),\(.[$assetPair] | .oracleExpiration),\(.[$assetPair] | .oracleSpread)"' "$_config")

	for assetPair in "${!assetInfo[@]}"; do
		_decimals=$(getTokenDecimals "$assetPair")
		[[ "$_decimals" =~ ^[1-9][0-9]*$ ]] || errors+=("Error - Asset Pair param $assetPair has invalid decimals field, must be positive integer.")
		
		_msgExpiration=$(getMsgExpiration "$assetPair")
		[[ "$_msgExpiration" =~ ^[1-9][0-9]*$ ]] || errors+=("Error - Asset Pair param $assetPair has invalid msgExpiration field, must be positive integer.")
		
		_oracle=$(getOracleContract "$assetPair")
		[[ "$_oracle" =~ ^(0x){1}[0-9a-fA-F]{40}$ ]] || errors+=("Error - Asset Pair param $assetPair has invalid oracle field, must be ethereum address prefixed with 0x.")
		
		_oracleExpiration=$(getOracleExpiration "$assetPair")
		[[ "$_oracleExpiration" =~ ^[1-9][0-9]*$ ]] || errors+=("Error - Asset Pair param $assetPair has invalid oracleExpiration field, must be positive integer") 

		_oracleSpread=$(getOracleSpread "$assetPair")
		[[ "$_oracleSpread" =~ ^([1-9][0-9]*([.][0-9]+)?|[0][.][0-9]*[1-9][0-9]*)$ ]] || errors+=("Error - Asset Pair param $assetPair has invalid oracleSpread field, must be positive integer or float")
	done
	[[ ${errors[*]} ]] && { printf '%s\n' "${errors[@]}"; exit 1; }
}

importFeeds () {
	local _config="$1"
	local _json

	readarray -t feeds < <(jq -r '.feeds[]' < "$_config")
	for feed in "${feeds[@]}"; do
		[[ $feed =~ ^(@){1}[a-zA-Z0-9+]{43}(=.ed25519){1}$ ]] || { error "Error - Invalid feed address: $feed"; exit 1; }
	done
}

importOptionsEnv () {
	local _config="$1"
	local _json

	_json=$(jq -S '.options' < "$_config")

	OMNIA_INTERVAL="$(echo "$_json" | jq -S '.interval')"
	[[ "$OMNIA_INTERVAL" =~ ^[1-9][0-9]*$ ]] || errors+=("Error - Interval param is invalid, must be positive whole number.")
	export OMNIA_INTERVAL

	OMNIA_VERBOSE="$(echo "$_json" | jq -S '.verbose')"
	OMNIA_VERBOSE=$(echo "$OMNIA_VERBOSE" | tr '[:upper:]' '[:lower:]')
	[[ "$OMNIA_VERBOSE" =~ ^(true|false)$ ]] || errors+=("Error - Verbose param is invalid, must be true or false.")
	export OMNIA_VERBOSE
	
	[[ ${errors[*]} ]] && { printf '%s\n' "${errors[@]}"; exit 1; }
}

importScuttlebotEnv () {
	SCUTTLEBOT_FEED_ID=$(getFeedId)
	[[ $SCUTTLEBOT_FEED_ID ]] || { error "Could not get scuttlebot feed id, make sure scuttlebot server is running"; exit 1; }
	export SCUTTLEBOT_FEED_ID
}