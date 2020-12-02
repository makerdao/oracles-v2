_include() {
  E2E_LOGS="./logs"
  mkdir -p "$E2E_LOGS"
  E2E_HOME=$(mktemp -d "${TMPDIR:-/tmp}"/home.XXXXXXXX)
  mkdir -p "$E2E_HOME"
  E2E_EXIT_HOOK="
    rm -rf \"$E2E_HOME\"
  "
  trap 'trap - EXIT; bash -c "$E2E_EXIT_HOOK"' EXIT
  set -eo pipefail
}
_include

startProxyRecord() {
  local proxyUrl=http://localhost:8080
  local _path=$(cd "${BASH_SOURCE[0]%/*}"; pwd)

  echo >&2 "# Record through proxy"
  rm -f "$E2E_TARGET_DIR/replay.mitm"
  {
    pkill mitmdump || true
    mitmdump \
      -w "$E2E_TARGET_DIR/replay.mitm" \
      --set "confdir=$_path/../resources/mitmproxy"

    "$_path/dedup-mitm" "$E2E_TARGET_DIR/replay.mitm"
  } >"$E2E_LOGS/${E2E_TARGET-test}-rec-mitm.out" 2>&1 &
  E2E_EXIT_HOOK+='pkill mitmdump;'

  export HTTP_PROXY="$proxyUrl"
  export HTTPS_PROXY="$proxyUrl"
  sleep 1
}

startProxyReplay() {
  local proxyUrl=http://localhost:8080
  local _path=$(cd "${BASH_SOURCE[0]%/*}"; pwd)

  echo >&2 "# Replay through proxy"
  pkill mitmdump || true
  mitmdump \
    -S "$E2E_TARGET_DIR/replay.mitm" \
    --set "confdir=$_path/../resources/mitmproxy" \
    --set upstream_cert=false \
    -k \
    --server-replay-refresh \
    --server-replay-kill-extra \
    --server-replay-nopop \
    >"logs/${E2E_TARGET-test}-replay-mitm.out" 2>&1 &
  E2E_EXIT_HOOK+='pkill mitmdump;'

  export HTTP_PROXY="$proxyUrl"
  export HTTPS_PROXY="$proxyUrl"
  sleep 1
}

startProxy() {
  if [[ $E2E_RECORD ]]; then
    startProxyRecord
  else
    startProxyReplay
  fi
}

exportEthEnvs() {
  local _path=$(cd "${BASH_SOURCE[0]%/*}"; pwd)
  local r_path="$_path/../resources"

  export ETH_FROM="0x1f8fbe73820765677e68eb6e933dcb3c94c9b708"
  export ETH_KEYSTORE="$r_path/keys"
  export ETH_PASSWORD="$r_path/password"
}

ssbId() {
  HOME="$E2E_HOME" ssb-server whoami | jq -r .id
}

ssbReadMessages() {
  local _id=$(ssbId)
  local _limit="$1"

  HOME="$E2E_HOME" \
    ssb-server createUserStream \
    --id "$_id" \
    --limit "$limit" \
    --reverse --fillCache 1 \
    | jq -s
}

ssbPublishMessages() {
  while IFS= read -r msg; do
    HOME="$E2E_HOME" ssb-server publish . <<<"$msg" >/dev/null
  done < <(cat)
}

startSSB() {
  echo >&2 "# Start SSB server"
  mkdir -p "$E2E_HOME/.ssb"
  HOME="$E2E_HOME" \
    ssb-server start >"$E2E_LOGS/${E2E_TARGET-test}-ssb.out" 2>&1 &
  E2E_EXIT_HOOK+='pkill ssb-server;'

  sleep 3
}

startGeth() {
  local _path=$(cd "${BASH_SOURCE[0]%/*}"; pwd)
  echo >&2 "# Start Geth testnet"
  {
    HOME="$E2E_HOME" \
      dapp testnet 2>&1 </dev/null || echo DAPP_EXIT
  } >"$E2E_LOGS/${E2E_TARGET-test}-dapp.out" &
  E2E_EXIT_HOOK+='pkill dapp;'

  grep -q 'DAPP_EXIT\|0x[a-zA-Z0-9]\{40\}' \
    <(tail -f "$E2E_LOGS/${E2E_TARGET-test}-dapp.out")

  export ETH_FROM=$(grep -o '0x[a-zA-Z0-9]\{40\}' < "$E2E_LOGS/${E2E_TARGET-test}-dapp.out")
  export ETH_KEYSTORE="$E2E_HOME"/.dapp/testnet/8545/keystore
  export ETH_PASSWORD="$_path/../resources/password"
  export ETH_RPC_URL="http://127.0.0.1:8545"
  export ETH_GAS=7000000
  #env | grep ETH_ >&2
}

startOmnia() {
  echo >&2 "# Start omnia"
  {
    HOME="$E2E_HOME" omnia 2>&1 || echo OMNIA_EXIT
  } >"$E2E_LOGS/${E2E_TARGET-test}-omnia.out" &

  grep -q "OMNIA_EXIT\|${1:-${E2E_OMNIA_STOP_PHRASE:-Sleeping}}" \
    <(tail -f "$E2E_LOGS/${E2E_TARGET-test}-omnia.out")
  pkill omnia
}
