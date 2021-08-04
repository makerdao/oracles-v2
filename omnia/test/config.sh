#!/bin/bash
test_path=$(cd "${BASH_SOURCE[0]%/*}"; pwd)
root_path=$(cd "$test_path/.."; pwd)
lib_path="$root_path/lib"

. "$lib_path/log.sh"
. "$lib_path/config.sh"

. "$root_path/tap.sh" 2>/dev/null || . "$root_path/../tests/lib/tap.sh"

# Setting up clean vars
ETH_GAS_SOURCE=""
ETH_GAS_MULTIPLIER=""
ETH_GAS_PRIORITY=""

_validConfig="$(jq -c . "$test_path/configs/oracle-relayer-test.conf")"

_json="{\"ethereum\":{\"gasPrice\":{\"source\":\"node\",\"multiplier\":\"test\"}}}"
assert "importGasPrice should fail in case of invalid multiplier" fail importGasPrice $_json

_json="{\"ethereum\":{\"gasPrice\":{\"source\":\"node\",\"multiplier\":1,\"priority\":\"invalid\"}}}"
assert "importGasPrice should fail in case of invalid priority" fail importGasPrice $_json

# Happy path
ETH_GAS_SOURCE=""
ETH_GAS_MULTIPLIER=""
ETH_GAS_PRIORITY=""

assert "importGasPrice should correctly parse values" run importGasPrice $_validConfig

assert "ETH_GAS_SOURCE should have value: node" match "node" <<<$ETH_GAS_SOURCE
assert "ETH_GAS_MULTIPLIER should have value: 1" match "1" <<<$ETH_GAS_MULTIPLIER
assert "ETH_GAS_PRIORITY should have value: fast" match "fast" <<<$ETH_GAS_PRIORITY
