#!/bin/bash
test_path=$(cd "${BASH_SOURCE[0]%/*}"; pwd)
root_path=$(cd "$test_path/.."; pwd)
lib_path="$root_path/lib"

. "$lib_path/log.sh"
. "$lib_path/util.sh"
. "$lib_path/gasprice.sh"
. "$lib_path/ethereum.sh"

. "$root_path/tap.sh" 2>/dev/null || . "$root_path/../tests/lib/tap.sh"

# Setting up relayer configuration
OMNIA_MODE="RELAYER"

declare -gA assetInfo

# mocking getGasPrice before pushOraclePrice
getGasPrice () {
  echo "1"
}
export -f getGasPrice

# incorrect address validation
assetInfo["BTCUSD"]="0xxxxx,0.5,15500,1800"

assert "pullOracleTime should fail if incorrect address configured" fail pullOracleTime "BTC/USD"
assert "pullOracleQuorum should fail if incorrect address configured" fail pullOracleQuorum "BTC/USD"
assert "pullOraclePrice should fail if incorrect address configured" fail pullOraclePrice "BTC/USD"
assert "pushOraclePrice should fail if incorrect address configured" fail pushOraclePrice "BTC/USD"

_list=$(seq 10)
assert "getMedian returns correct median amount" match "5.5" < <(capture getMedian $_list)

assert "join returns correctly joined args" match "1,2,3" < <(capture join 1 2 3)