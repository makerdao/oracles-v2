#!/usr/bin/env bash
root_path=$(cd "${BASH_SOURCE[0]%/*}/.." && pwd)
bin_path="$root_path/bin"

# Mock ssb-server
export wdir
ssb-server() {
	echo "$1-$2"
	cat > $wdir/output
}
export -f ssb-server

export OMNIA_VERBOSE="true"
export OMNIA_VERSION="dev-test"

. "$root_path/tap.sh" 2>/dev/null || . "$root_path/../tests/lib/tap.sh"

assert "broadcast price message" run "$bin_path"/oracle-transporter-ssb publish '{"hash":"AB","price":0.222,"priceHex":"ABC","signature":"CD","sources":{"s1":"0.1","s2":"0.2","s3":"0.3"},"time":20200101,"timeHex":"DEF","type":"BTCUSD","version":"dev-test"}'
assert "verify the broadcast message" json "." <<<'{"price":0.222,"hash":"AB","priceHex":"ABC","signature":"CD","sources":{"s1":"0.1","s2":"0.2","s3":"0.3"},"time":20200101,"timeHex":"DEF","type":"BTCUSD","version":"dev-test"}'
