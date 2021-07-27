#!/bin/bash
test_path=$(cd "${BASH_SOURCE[0]%/*}"; pwd)
root_path=$(cd "$test_path/.."; pwd)
lib_path="$root_path/lib"

. "$lib_path/log.sh"
. "$lib_path/gasprice.sh"

. "$root_path/tap.sh" 2>/dev/null || . "$root_path/../tests/lib/tap.sh"

getGasPriceFromNode () {
  echo "1"
}
export -f getGasPriceFromNode

assert "multiplyGasPrice should return multiplied values" match "2" < <(capture multiplyGasPrice 1 2)
assert "multiplyGasPrice should return multiplied values" match "10" < <(capture multiplyGasPrice 5 2)
assert "multiplyGasPrice should return multiplied values" match "11.0" < <(capture multiplyGasPrice 10 1.1)

ETH_GAS_SOURCE="node"
ETH_GAS_MULTIPLIER="2"
assert "getGasPrice should return node value multiplied by $ETH_GAS_MULTIPLIER" match "2" < <(capture getGasPrice)

ETH_GAS_MULTIPLIER="1"
assert "getGasPrice should return node value multiplied by $ETH_GAS_MULTIPLIER" match "1" < <(capture getGasPrice)

ETH_GAS_MULTIPLIER=""
assert "getGasPrice should fail in case of invalid multiplier" fail getGasPrice


ETH_GAS_MULTIPLIER="1.1"
assert "getGasPrice should return correct gas multiplied" match "1.1" < <(capture getGasPrice)

# validate fallback
ETH_GAS_SOURCE="gasnow"
ETH_GAS_MULTIPLIER=1

getGasPriceFromNode () { 
  echo "1" 
}
export -f getGasPriceFromNode

# mocking for 0 price
getGasPriceFromGasNow () {
  echo "0"
}
export -f getGasPriceFromGasNow

assert "getGasPrice falls back to getGasPriceFromNode in case of invalid price" match "1" < <(capture getGasPrice)

# mocking for invalid price
getGasPriceFromGasNow () {
  echo "abc"
}
export -f getGasPriceFromGasNow

assert "getGasPrice falls back to getGasPriceFromNode in case of non numeric price" match "1" < <(capture getGasPrice)

getGasPriceFromNode () { 
  echo "command not found: seth"
  return 127 
}
export -f getGasPriceFromNode
assert "getGasPrice fails in case of issues with seth" fail getGasPrice