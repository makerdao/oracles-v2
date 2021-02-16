#!/usr/bin/env bash

importEnv () {
	local config
	if [[ -f "$OMNIA_CONFIG" ]]; then
		config="$OMNIA_CONFIG"
	elif [[ -f /etc/omnia.conf ]]; then
		config="/etc/omnia.conf"
	elif [[ -f ./config/omnia.conf ]]; then 
		config="./config/omnia.conf"
	else
		error "Error Could not find omnia.conf config file to load parameters."
		error "Please create /etc/omnia.conf or put it in the config directory."
		exit 1
	fi
	echo "Importing configuration from $config..."

	#check if config file is valid json
	jq -e . "$config" >/dev/null 2>&1 || { error "Error - Config is not valid JSON"; exit 1; }

	importMode "$config"
	importEthereumEnv "$config"
	importStarkwareEnv "$config"
	importAssetPairsEnv "$config"
	importOptionsEnv "$config"
	importScuttlebotEnv
	if [[ "$OMNIA_MODE" == "FEED" ]]; then
		importServicesEnv "$config"
	fi
	if [[ "$OMNIA_MODE" == "RELAYER" ]]; then
		importFeeds "$config"
	fi
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
	#[[ -z "$INFURA_KEY" ]] || [[ "$INFURA_KEY" =~ ^[0-9a-f]{32}$ ]] || errors+=("Error - Invalid Infura Key")
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
		#custom RPC endpoint like Local Node, Ganache or Testchain
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


	ETH_FROM="${ETH_FROM-$(jq -r '.from' <<<"$_json")}"
	#this just checks for valid chars and length, NOT checksum!
	[[ "$ETH_FROM" =~ ^(0x){1}[0-9a-fA-F]{40}$ ]] || errors+=("Error - Ethereum Address is invalid.")
	export ETH_FROM

	ETH_KEYSTORE="${ETH_KEYSTORE-$(jq -r '.keystore' <<<"$_json")}"
	#validate path exists
	[[ -d "$ETH_KEYSTORE" ]] || errors+=("Error - Ethereum Keystore Path is invalid, directory does not exist.")
	export ETH_KEYSTORE

	ETH_PASSWORD="${ETH_PASSWORD-$(jq -r '.password' <<<"$_json")}"
	#validate file exists
	[[ -f "$ETH_PASSWORD" ]] || errors+=("Error - Ethereum Password Path is invalid, file does not exist.")
	export ETH_PASSWORD

	[[ ${errors[*]} ]] && { printf '%s\n' "${errors[@]}"; exit 1; }
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

importStarkwareEnv() {
	verbose "Importing Starkware signature keys"
	local _starkdata
	local _enthropy
	local _seed
	
	STARK_CLI="${STARK_CLI:-stark_cli.py}"
	export STARK_CLI
	
	_starkdata="537461726b4b657944657269766174696f6e" #StarkKeyDerivation
	_enthropy=$(signMessage "$_starkdata")
	_seed=$(keccak256Hash "$_enthropy" | cut -c3-)
	STARK_PRIVATE_KEY="$( printf 'obase=16; ibase=16; %s / %s\n' "${_seed^^}" 20 | BC_LINE_LENGTH=0 bc )"
	export STARK_PRIVATE_KEY

	STARK_PUBLIC_KEY=$($STARK_CLI --method "get_public" --key "$STARK_PRIVATE_KEY")
	export STARK_PUBLIC_KEY
}

importAssetPairsEnv () {
	local _config="$1"
	local _json

	_json="$(jq -S '.pairs' < "$_config")"

	#create array of asset pairs
	readarray -t assetPairs < <(echo "$_json" | jq -r 'keys | .[]')

	[[ ${#assetPairs[@]} -eq 0 ]] && { error "Error - Config must have at least 1 asset pair"; exit 1; }

	[[ $OMNIA_MODE == "FEED" ]] && importAssetPairsFeed
	[[ $OMNIA_MODE == "RELAYER" ]] && importAssetPairsRelayer
}

importAssetPairsFeed () {
	declare -gA assetInfo
	local _msgExpiration
	local _msgSpread

	#Write values as comma seperated list to associative array
	while IFS="=" read -r assetPair info; do
		assetInfo[$assetPair]="$info"
	done < <(jq -r '.pairs | keys[] as $assetPair | "\($assetPair)=\(.[$assetPair] | .msgExpiration),\(.[$assetPair] | .msgSpread)"' "$_config")

	#Verify values
	for assetPair in "${!assetInfo[@]}"; do
		_msgExpiration=$(getMsgExpiration "$assetPair")
		[[ "$_msgExpiration" =~ ^[1-9][0-9]*$ ]] || errors+=("Error - Asset Pair param $assetPair has invalid or missing msgExpiration field, must be positive integer.")
		
		_msgSpread=$(getMsgSpread "$assetPair")
		[[ "$_msgSpread" =~ ^([1-9][0-9]*([.][0-9]+)?|[0][.][0-9]*[1-9][0-9]*)$ ]] || errors+=("Error - Asset Pair param $assetPair has invalid or missing msgSpread field, must be positive integer or float.")
	done
	[[ ${errors[*]} ]] && { printf '%s\n' "${errors[@]}"; exit 1; }
}

importAssetPairsRelayer () {
	declare -gA assetInfo
	local _msgExpiration
	local _oracle
	local _oracleExpiration
	local _oracleSpread

	while IFS="=" read -r assetPair info; do
		assetInfo[$assetPair]="$info"
	done < <(jq -r '.pairs | keys[] as $assetPair | "\($assetPair)=\(.[$assetPair] | .msgExpiration),\(.[$assetPair] | .oracle),\(.[$assetPair] | .oracleExpiration),\(.[$assetPair] | .oracleSpread)"' "$_config")

	for assetPair in "${!assetInfo[@]}"; do
		_msgExpiration=$(getMsgExpiration "$assetPair")
		[[ "$_msgExpiration" =~ ^[1-9][0-9]*$ ]] || errors+=("Error - Asset Pair param $assetPair has invalid or missing msgExpiration field, must be positive integer.")
		
		_oracle=$(getOracleContract "$assetPair")
		[[ "$_oracle" =~ ^(0x){1}[0-9a-fA-F]{40}$ ]] || errors+=("Error - Asset Pair param $assetPair has invalid or missing oracle field, must be ethereum address prefixed with 0x.")
		
		_oracleExpiration=$(getOracleExpiration "$assetPair")
		[[ "$_oracleExpiration" =~ ^[1-9][0-9]*$ ]] || errors+=("Error - Asset Pair param $assetPair has invalid or missing oracleExpiration field, must be positive integer") 

		_oracleSpread=$(getOracleSpread "$assetPair")
		[[ "$_oracleSpread" =~ ^([1-9][0-9]*([.][0-9]+)?|[0][.][0-9]*[1-9][0-9]*)$ ]] || errors+=("Error - Asset Pair param $assetPair has invalid or missing oracleSpread field, must be positive integer or float")
	done
	[[ ${errors[*]} ]] && { printf '%s\n' "${errors[@]}"; exit 1; }
}

importFeeds () {
	local _config="$1"
	local _json

	readarray -t feeds < <(jq -r '.feeds[]' < "$_config")
	for feed in "${feeds[@]}"; do
		[[ $feed =~ ^(@){1}[a-zA-Z0-9+/]{43}(=.ed25519){1}$ ]] || { error "Error - Invalid feed address: $feed"; exit 1; }
	done
	[[ ${errors[*]} ]] && { printf '%s\n' "${errors[@]}"; exit 1; }
}

importOptionsEnv () {
	local _config="$1"
	local _json

	_json=$(jq -S '.options' < "$_config")

	OMNIA_INTERVAL="$(echo "$_json" | jq -S '.interval')"
	[[ "$OMNIA_INTERVAL" =~ ^[1-9][0-9]*$ ]] || errors+=("Error - Interval param is invalid, must be positive integer.")
	export OMNIA_INTERVAL

	OMNIA_MSG_LIMIT="$(echo "$_json" | jq -S '.msgLimit')"
	[[ "$OMNIA_MSG_LIMIT" =~ ^[1-9][0-9]*$ ]] || errors+=("Error - Msg Limit param is invalid, must be positive integer.")
	export OMNIA_MSG_LIMIT

	OMNIA_VERBOSE="$(echo "$_json" | jq -S '.verbose')"
	OMNIA_VERBOSE=$(echo "$OMNIA_VERBOSE" | tr '[:upper:]' '[:lower:]')
	[[ "$OMNIA_VERBOSE" =~ ^(true|false)$ ]] || errors+=("Error - Verbose param is invalid, must be true or false.")
	export OMNIA_VERBOSE

	if [[ "$OMNIA_MODE" == "FEED" ]]; then
		OMNIA_SRC_TIMEOUT="$(echo "$_json" | jq -S '.srcTimeout')"
		[[ "$OMNIA_SRC_TIMEOUT" =~ ^[1-9][0-9]*$ ]] || errors+=("Error - Src Timeout param is invalid, must be positive integer.")
		export OMNIA_SRC_TIMEOUT

		SETZER_TIMEOUT="$(echo "$_json" | jq -S '.setzerTimeout')"
		[[ "$SETZER_TIMEOUT" =~ ^[1-9][0-9]*$ ]] || errors+=("Error - Setzer Timeout param is invalid, must be positive integer.")
		export SETZER_TIMEOUT

		SETZER_CACHE_EXPIRY="$(echo "$_json" | jq -S '.setzerCacheExpiry')"
		[[ "$SETZER_CACHE_EXPIRY" =~ ^[1-9][0-9]*$ ]] || errors+=("Error - Setzer Cache Expiry param is invalid, must be positive integer.")
		export SETZER_CACHE_EXPIRY

		SETZER_MIN_MEDIAN="$(echo "$_json" | jq -S '.setzerMinMedian')"
		[[ "$SETZER_MIN_MEDIAN" =~ ^[1-9][0-9]*$ ]] || errors+=("Error - Setzer Minimum Median param is invalid, must be positive integer.")
		export SETZER_MIN_MEDIAN
	fi
	
	[[ ${errors[*]} ]] && { printf '%s\n' "${errors[@]}"; exit 1; }
}

importServicesEnv () {
	local _config="$1"

	[[ ${errors[*]} ]] && { printf '%s\n' "${errors[@]}"; exit 1; }
}

importScuttlebotEnv () {
	SCUTTLEBOT_FEED_ID=$(getFeedId)
	[[ $SCUTTLEBOT_FEED_ID ]] || { error "Could not get scuttlebot feed id, make sure scuttlebot server is running"; exit 1; }
	export SCUTTLEBOT_FEED_ID
}
