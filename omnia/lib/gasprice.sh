#!/usr/bin/env bash

# Calculate gas price
getGasPrice () {
  # check if multiplier set
  [[ $ETH_GAS_MULTIPLIER =~ ^[0-9\.]+$ ]] || return 1

  local _price

  # Getting price from source
  _price=$(case $ETH_GAS_SOURCE in
    node) getGasPriceFromNode ;;
    gasnow) getGasPriceFromGasNow ;;
    ethgasstation) getGasPriceFromEthGasStation ;;
    *) getGasPriceFromNode ;;
  esac)

  # Fallback to node price in case of 0 or invalid price
  [[ $_price =~ ^[0-9\.]+$ ]] || _price=$(getGasPriceFromNode)
  [[ $_price -eq 0 ]] && _price=$(getGasPriceFromNode)
  
  echo "After: $_price"
  # handle issues with seth
  if [[ ! $_price =~ ^[0-9\.]+$ ]]; then
    error "Error - Invalid GAS price received: $_price"
    return 1
  fi

  # Making multiplication
  multiplyGasPrice $_price $ETH_GAS_MULTIPLIER
}

# Makes multiplication for given gas price.
# Example: `multiplyGasPrice $GAS_TO_SPEND $MULTIPLIER`
multiplyGasPrice () {
  echo "$1 * $2" | bc
}

# Using node gas price
getGasPriceFromNode () {
  seth gas-price
}

# Using gasnow.org API for fetching gas price
getGasPriceFromGasNow () {
  local _price=$(curl --silent --location https://www.gasnow.org/api/v3/gas/price | jq -r '.data.standard // 0')
  [[ $_price =~ ^[0-9\.]+$ ]] && echo $_price || echo 0
}

# Takes gas amount from EthGasStation API and multiplies it to 100000000 (converting to wei)
# API return gas price in x10 Gwei(divite by 10 to convert it to gwei)
# Will return 0 if API response will be corrupted
# Or exit code `1` in case of it wouldn't be able to make request
getGasPriceFromEthGasStation () {
  local _price=$(curl --silent --location https://ethgasstation.info/json/ethgasAPI.json | jq -r '.average // 0')
  [[ $_price =~ ^[0-9\.]+$ ]] && multiplyGasPrice $_price 100000000 || echo 0
}

