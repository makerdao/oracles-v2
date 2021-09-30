# Returns the estimated gas price and tip value as two numbers separated
# by a space. It requires three environmental variables to work:
# ETH_MAXPRICE_MULTIPLIER - float number
# ETH_TIP_MULTIPLIER - float number
# ETH_GAS_SOURCE - node or ethgasstation
getGasPrice() {
	[[ $ETH_MAXPRICE_MULTIPLIER =~ ^[0-9\.]+$  ]] || return 1
	[[ $ETH_TIP_MULTIPLIER =~ ^[0-9\.]+$  ]] || return 1

	# Getting price from a source
	local _fees
	case $ETH_GAS_SOURCE in
		node) _fees=($(getGasPriceFromNode)) ;;
		ethgasstation) _fees=($(getGasPriceFromEthGasStation)) ;;
		*) _fees=($(getGasPriceFromNode)) ;;
	esac

  # Fallback to node price in case of 0 or invalid price
  if [[ ! ${_fees[0]} =~ ^[0-9\.]+$ || ${_fees[0]} -eq 0 ]]; then
    _fees=($(getGasPriceFromNode))
  fi

	verbose "Sourced gas price" "source=$ETH_GAS_SOURCE" "maxPrice#=${_fees[0]}" "tip#=${_fees[1]}"

	# Handle issues with seth
	if  [[ ! ${_fees[0]} =~ ^[0-9\.]+$ ]]; then
		error "Error - Invalid GAS price received: ${_fees[0]}"
		return 1
	fi

	local _maxPrice
	_maxPrice=$(echo "(${_fees[0]} * $ETH_MAXPRICE_MULTIPLIER) / 1" | bc)
	local _tip
  _tip=$(echo "(${_fees[1]} * $ETH_TIP_MULTIPLIER) / 1" | bc)

  echo "$_maxPrice $_tip"
}

getGasPriceFromNode() {
  local _tip
  _tip=$(ethereum rpc eth_maxPriorityFeePerGas)
  if [[ ! $_tip =~ ^[0-9\.]+$ ]]; then
    echo 0
    return
  fi

  local _maxPrice
  _maxPrice=$(ethereum rpc eth_gasPrice)
  if [[ ! $_maxPrice =~ ^[0-9\.]+$ ]]; then
    echo 0
    return
  fi

  echo "$_maxPrice $_tip"
}

getGasPriceFromEthGasStation() {
	local _key
	_key=$( case $ETH_GAS_PRIORITY in
		slow) printf "safeLow" ;;
		standard) printf "average" ;;
		fast) printf "fast" ;;
		fastest) printf "fastest" ;;
		*) printf "fast" ;;
	esac)

	local _price
	_price=$(curl -m 30 --silent --location "https://ethgasstation.info/json/ethgasAPI.json" | jq -r --arg key "$_key" '.[$key] // 0')

	echo $((_price * 100000000)) $((_price * 100000000))
}