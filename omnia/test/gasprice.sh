#!/bin/bash
test_path=$(cd "${BASH_SOURCE[0]%/*}"; pwd)
root_path=$(cd "$test_path/.."; pwd)
lib_path="$root_path/lib"

. "$lib_path/log.sh"
. "$lib_path/gasprice.sh"

. "$root_path/tap.sh" 2>/dev/null || . "$root_path/../tests/lib/tap.sh"

# GasNow test:
ETH_GAS_SOURCE="gasnow"
ETH_MAXPRICE_MULTIPLIER="1"
ETH_TIP_MULTIPLIER="1"

curl () {
  echo '{"code":200,"data":{"rapid":90,"fast":80,"standard":70,"slow":60,"timestamp":1629768330925}}'
}
export -f curl

ETH_GAS_PRIORITY="fastest"
assert "getGasPrice using gasnow should return 90 90 using $ETH_GAS_PRIORITY priority" match "^90 90" < <(capture getGasPrice)
ETH_GAS_PRIORITY="fast"
assert "getGasPrice using gasnow should return: 80 80 using $ETH_GAS_PRIORITY priority" match "^80 80$" < <(capture getGasPrice)
ETH_GAS_PRIORITY="standard"
assert "getGasPrice using gasnow should return: 70 70 using $ETH_GAS_PRIORITY priority" match "^70 70" < <(capture getGasPrice)
ETH_GAS_PRIORITY="slow"
assert "getGasPrice using gasnow should return: 60 60 using $ETH_GAS_PRIORITY priority" match "^60 60" < <(capture getGasPrice)

# GasStation test:
ETH_GAS_SOURCE="ethgasstation"
ETH_MAXPRICE_MULTIPLIER="1"
ETH_TIP_MULTIPLIER="1"

curl () {
  echo '{"fast": 80.0, "fastest": 90.0, "safeLow": 60.0, "average": 70.0, "block_time": 14.456521739130435, "blockNum": 13085129}'
}
export -f curl

ETH_GAS_PRIORITY="fastest"
assert "getGasPrice using gasstation should return 9000000000 9000000000 using $ETH_GAS_PRIORITY priority" match "^9000000000 9000000000" < <(capture getGasPrice)
ETH_GAS_PRIORITY="fast"
assert "getGasPrice using gasstation should return: 8000000000 8000000000 using $ETH_GAS_PRIORITY priority" match "^8000000000 8000000000$" < <(capture getGasPrice)
ETH_GAS_PRIORITY="standard"
assert "getGasPrice using gasstation should return: 7000000000 7000000000 using $ETH_GAS_PRIORITY priority" match "^7000000000 7000000000" < <(capture getGasPrice)
ETH_GAS_PRIORITY="slow"
assert "getGasPrice using gasstation should return: 6000000000 6000000000 using $ETH_GAS_PRIORITY priority" match "^6000000000 6000000000" < <(capture getGasPrice)

# GetGasPrice multipliers:
getGasPriceFromNode () {
  echo "20 10"
}
export -f getGasPriceFromNode

ETH_GAS_SOURCE="node"
ETH_MAXPRICE_MULTIPLIER="1"
ETH_TIP_MULTIPLIER="1"
assert "getGasPrice should return a base fee multiplied by $ETH_MAXPRICE_MULTIPLIER and tip multiplied by $ETH_TIP_MULTIPLIER" \
  match "^20 10$" < <(capture getGasPrice)

ETH_MAXPRICE_MULTIPLIER="3"
ETH_TIP_MULTIPLIER="2"
assert "getGasPrice should return a base fee multiplied by $ETH_MAXPRICE_MULTIPLIER and tip multiplied by $ETH_TIP_MULTIPLIER" \
  match "^60 20$" < <(capture getGasPrice)

ETH_MAXPRICE_MULTIPLIER="1.15"
ETH_TIP_MULTIPLIER="1.25"
assert "getGasPrice should return a base fee multiplied by $ETH_MAXPRICE_MULTIPLIER and tip multiplied by $ETH_TIP_MULTIPLIER" \
  match "^23 12$" < <(capture getGasPrice)

ETH_MAXPRICE_MULTIPLIER=""
ETH_TIP_MULTIPLIER="1"
assert "getGasPrice should fail if the ETH_MAXPRICE_MULTIPLIER is not set" fail getGasPrice

ETH_MAXPRICE_MULTIPLIER="1"
ETH_TIP_MULTIPLIER=""
assert "getGasPrice should fail if the ETH_TIP_MULTIPLIER is not set" fail getGasPrice

# GetGasPrice fallback test:
ETH_GAS_SOURCE="gasnow"
ETH_MAXPRICE_MULTIPLIER="1"
ETH_TIP_MULTIPLIER="1"

getGasPriceFromNode () { 
  echo "20 10"
}
export -f getGasPriceFromNode

getGasPriceFromGasNow () {
  echo "0"
}
export -f getGasPriceFromGasNow

assert "getGasPrice falls back to getGasPriceFromNode in case of invalid price" match "^20 10$" < <(capture getGasPrice)

getGasPriceFromGasNow () {
  echo "err"
}
export -f getGasPriceFromGasNow

assert "getGasPrice falls back to getGasPriceFromNode in case of non numeric price" match "^20 10$" < <(capture getGasPrice)

