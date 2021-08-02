
#get median of  a list of numbers
getMedian () {
	local _numbers=( "$@" )
	tr " " "\\n" <<< "${_numbers[@]}" | datamash median 1
}

#extracts prices from list of messages
extractPrices () {
    local _msgs=( "$@" )
    local _prices
    for msg in "${_msgs[@]}"; do
       _prices+=("$(echo "$msg" | jq '.price')")
    done
    echo "${_prices[@]}"
}

join () {
	local IFS=","
	echo "$*"
}

#get unix timestamp in ms
timestampMs () {
    date +"%s%3N"
}

#get unix timestamp in s
timestampS () {
	date +"%s"
}

#gets keccak-256 hash of 1 or more input arguments
keccak256Hash () {
	local _inputs
	for arg in "$@"; do
		_inputs+="$arg"
	done
	verbose "inputs to hash function = $_inputs"
	seth keccak "$_inputs"
}

#convert price to hex
price2Hex () {
	local _price="$1"
	#convert price to 32 byte hex
	seth --to-uint256 "$(seth --to-wei "$_price" eth)" | sed s/0x//
}

#converts timestamp to 32 byte hex
time2Hex () {
	local _time="$1"
	seth --to-uint256 "$_time" | sed s/0x//
}

getAssetInfo () {
	local _assetPair="$1"
	_assetPair="${_assetPair^^}"
	_assetPair="${_assetPair/\/}"
	echo "${assetInfo[$_assetPair]}"
}

getMsgExpiration () {
	getAssetInfo "$1" | cut -d ',' -f1
}

getMsgSpread () {
	[[ $OMNIA_MODE == "FEED" ]] && getAssetInfo "$1" | cut -d ',' -f2
}

#get the Oracle contract of an asset pair
getOracleContract () {
	[[ $OMNIA_MODE == "RELAYER" || "$OMNIA_MODE" == "RELAY" ]] && getAssetInfo "$1" | cut -d ',' -f2
}

getOracleExpiration () {
	[[ "$OMNIA_MODE" == "RELAYER" || "$OMNIA_MODE" == "RELAY" ]] && getAssetInfo "$1" | cut -d ',' -f3
}

getOracleSpread () { 
	[[ "$OMNIA_MODE" == "RELAYER" || "$OMNIA_MODE" == "RELAY" ]] && getAssetInfo "$1" | cut -d ',' -f4
}

signMessage () {
	local _data
	for arg in "$@"; do
		_data+="$arg"
	done
	verbose "Signing message..."
	ethsign message --from "$ETH_FROM" --key-store "$ETH_KEYSTORE" --passphrase-file "$ETH_PASSWORD" --data "$_data"
}
