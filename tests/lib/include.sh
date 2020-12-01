exportEthEnvs() {
  local _path=$(cd "${BASH_SOURCE[0]%/*}"; pwd)
  local r_path="$_path/../resources"

  export ETH_FROM="0x1f8fbe73820765677e68eb6e933dcb3c94c9b708"
  export ETH_KEYSTORE="$r_path/keys"
  export ETH_PASSWORD="$r_path/password"
}

ssbReadMessages() {
  local _id=$(ssb-server whoami | jq -r .id)
  local _limit="$1"

  ssb-server createUserStream \
    --id "$_id" \
    --limit "$limit" \
    --reverse --fillCache 1 \
    | jq -s
}

runOmnia() {
  local _tmp=$(mktemp -d "${TMPDIR:-/tmp}"/home.XXXXXXXX)
  mkdir -p logs

  (
    exportEthEnvs

    export HOME="$_tmp"
    mkdir -p "$_tmp/.ssb"

    echo >&2 "# Starting SSB server"
    ssb-server start >"logs/${E2E_TARGET-test}-ssb.out" 2>&1 &
    sleep 3

    echo >&2 "# Starting Omnia"
    omnia 2>&1 | tee logs/${E2E_TARGET-test}-omnia.out >"$_tmp/omnia.out" &
    grep -q "${E2E_OMNIA_STOP_PHRASE:-Sleeping}" \
      <(tail -f "$_tmp/omnia.out")
    echo >&2 "# Killing Omnia"
    pkill -9 omnia >/dev/null 2>&1

    echo >&2 "# Reading messages from SSB"
    ssbReadMessages 100

    echo >&2 "# Killing SSB server"
    pkill -9 ssb-server >/dev/null 2>&1
  )
  rm -rf "$_tmp"
}
