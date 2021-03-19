#!/bin/bash
test_path=$(cd "${BASH_SOURCE[0]%/*}"; pwd)
root_path=$(cd "$test_path/.."; pwd)
lib_path="$root_path/lib"

. "$lib_path/log.sh"
. "$lib_path/util.sh"
. "$lib_path/config.sh"
. "$lib_path/relayer.sh"

. "$root_path/tap.sh" 2>/dev/null || . "$root_path/../tests/lib/tap.sh"

# Setting up relayer configuration
OMNIA_MODE="RELAYER"

importAssetPairsEnv "$test_path/configs/oracle-relayer-test.conf"
assert "assetPairs assigned" match "3" < <(capture printf ${#assetPairs[@]})

_pricePulled="false"

resetTestState() {
  _pricePulled="false"
}
export -f resetTestState

pullLatestPricesOfAssetPair() { _pricePulled="true" ; }
export -f pullLatestPricesOfAssetPair

extractPrices() { printf "" ; }
export -f extractPrices

getMedian() { printf "" ; }
export -f getMedian

# Mocking isPriceValid to prevent publishing messages
isPriceValid() { printf "false" ; }
export -f isPriceValid

isQuorum() { printf "false" ; }
export -f isQuorum

# testing for empty quorum
pullOracleQuorum() { printf "" ; }
export -f pullOracleQuorum

# Reset test vars before testing
resetTestState 
assert "updateOracle runs without failure" run updateOracle
assert "updateOracle with empty quorum should not call pullLatestPricesOfAssetPair" match "false" <<<$_pricePulled

# testing for 0 quorum
pullOracleQuorum() { printf "0" ; }
export -f pullOracleQuorum

# Reset test vars before testing
resetTestState
assert "updateOracle runs without failure" run updateOracle
assert "updateOracle with quorum 0 should not call pullLatestPricesOfAssetPair" match "false" <<<$_pricePulled

pullOracleQuorum() { printf "12" ; }
export -f pullOracleQuorum

# Reset test vars before testing
resetTestState
assert "updateOracle runs without failure" run updateOracle
assert "updateOracle call pullLatestPricesOfAssetPair with correct quorum" match "true" <<<$_pricePulled

# testing with valid quorum
isQuorum() { printf "true" ; }
# export -f isQuorum

# Reset test vars before testing
resetTestState
assert "updateOracle runs without failure" run updateOracle
assert "updateOracle call pullLatestPricesOfAssetPair with correct quorum" match "true" <<<$_pricePulled