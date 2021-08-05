#!/bin/bash
test_path=$(cd "${BASH_SOURCE[0]%/*}"; pwd)
root_path=$(cd "$test_path/.."; pwd)
lib_path="$root_path/lib"

. "$lib_path/log.sh"
. "$lib_path/util.sh"
. "$lib_path/config.sh"

. "$root_path/tap.sh" 2>/dev/null || . "$root_path/../tests/lib/tap.sh"

_validConfig="$(jq -c . "$test_path/configs/oracle-relayer-test.conf")"

# Setting up clean vars
ETH_GAS_SOURCE=""
ETH_GAS_MULTIPLIER=""
ETH_GAS_PRIORITY=""

# Helper function
exact () {
  [[ $1 == $2 ]] || { cat <<EOF
got: $1
expect: $2
EOF
return 1
  }
}
export -f exact

# Testing default values
_json=$(jq -c '.ethereum' <<< "$_validConfig")
assert "importGasPrice should correctly parse values" run importGasPrice $_json

# Testing exact values, no quotes/anything else
assert "ETH_GAS_SOURCE should be exact value: node" run exact $ETH_GAS_SOURCE 'node'
assert "ETH_GAS_MULTIPLIER should be exact value: 1" run exact $ETH_GAS_MULTIPLIER '1'
assert "ETH_GAS_PRIORITY should be exact value: fast" run exact $ETH_GAS_PRIORITY 'fast'

# Testing changed values
_json="{\"gasPrice\":{\"source\":\"gasnow\",\"multiplier\":0.5,\"priority\":\"slow\"}}"
assert "importGasPrice should correctly parse new values" run importGasPrice $_json

assert "ETH_GAS_SOURCE should be exact value: gasnow" run exact $ETH_GAS_SOURCE 'gasnow'
assert "ETH_GAS_MULTIPLIER should be exact value: 0.5" run exact $ETH_GAS_MULTIPLIER '0.5'
assert "ETH_GAS_PRIORITY should be exact value: slow" run exact $ETH_GAS_PRIORITY 'slow'
