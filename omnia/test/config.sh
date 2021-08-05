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

plan 8

# Testing default values
_json=$(jq -c '.ethereum' <<< "$_validConfig")
assert "importGasPrice should correctly parse values" run importGasPrice $_json

assert "ETH_GAS_SOURCE should have value: gasnow" match "^node" <<<$ETH_GAS_SOURCE
assert "ETH_GAS_MULTIPLIER should have value: 0.5" match "^1$" <<<$ETH_GAS_MULTIPLIER
assert "ETH_GAS_PRIORITY should have value: slow" match "^fast" <<<$ETH_GAS_PRIORITY

# Testing changed values
_json="{\"gasPrice\":{\"source\":\"gasnow\",\"multiplier\":0.5,\"priority\":\"slow\"}}"
assert "importGasPrice should correctly parse new values" run importGasPrice $_json

assert "ETH_GAS_SOURCE should have value: gasnow" match "^gasnow$" <<<$ETH_GAS_SOURCE
assert "ETH_GAS_MULTIPLIER should have value: 0.5" match "^0.5$" <<<$ETH_GAS_MULTIPLIER
assert "ETH_GAS_PRIORITY should have value: slow" match "^slow$" <<<$ETH_GAS_PRIORITY
