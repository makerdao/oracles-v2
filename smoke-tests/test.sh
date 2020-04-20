#!/bin/bash
tpath="$(cd ${0%/*}; pwd)"
rpath="$tpath/resources"

from_addr="0x1f8fbe73820765677e68eb6e933dcb3c94c9b708"
keystore_path="$rpath/keys"
key_path="$rpath/key"
cmc_api_key="9e70da6e-09fc-4167-a8f7-68f4e7e907a5"

install_feed() {
  install-omnia feed \
    --from        "$from_addr" \
    --keystore    "$keystore_path" \
    --password    "$key_path" \
    --cmc-api-key "$cmc_api_key" \
    | sudo sh
}

install_relayer() {
  # Start geth testnet
  rm -rf "$HOME/.dapp/testnet"
  nohup >/dev/null 2>&1 \
    dapp --testnet-launch &
  sleep 2

  install-omnia relayer \
    | sudo sh
}

after() {
  pkill dapp
  sudo systemctl stop omnia
}

. "$tpath/tap.sh"

plan 19
timeout 60

# Install feed

run install_feed

assert "Install config" \
  test -f /etc/omnia.conf

cat /etc/omnia.conf > $wdir/output
assert "Mode is feed" \
  json .mode <<<'"feed"'
assert "Has set ethereum from address" \
  json .ethereum.from <<<"\"$from_addr\""
assert "Has set ethereum keystore" \
  json .ethereum.keystore <<<"\"$keystore_path\""
assert "Has set keystore password file" \
  json .ethereum.password <<<"\"$key_path\""
assert "Has CMC API key" \
  json .services.cmcApiKey <<<"\"$cmc_api_key\""

sleep 2

assert "Omnia feed service is active" \
  match "Active: active" < <(systemctl status omnia)
assert "Scuttlebot service is active" \
  match "Active: active" < <(systemctl status ssb-server)

sleep 5

assert "Omnia feed service is up" \
  no_match "Error" < <(journalctl --lines=10 -u omnia)
assert "Scuttlebot service is up" \
  no_match "Error" < <(journalctl --lines=10 -u ssb-server)

# Install relayer

run install_relayer

assert "Install config" \
  test -f /etc/omnia.conf

cat /etc/omnia.conf > $wdir/output
assert "Mode is relayer" \
  json .mode <<<'"relayer"'
assert "Ethereum from address not overwritten" \
  json .ethereum.from <<<"\"$from_addr\""
assert "Ethereum keystore not overwritten" \
  json .ethereum.keystore <<<"\"$keystore_path\""
assert "Keystore password file not overwritten" \
  json .ethereum.password <<<"\"$key_path\""

sleep 2

assert "Omnia relayer service is active" \
  match "Active: active" < <(systemctl status omnia)
assert "Scuttlebot service is active" \
  match "Active: active" < <(systemctl status ssb-server)

sleep 5

assert "Omnia relayer service is up" \
  match "INITIALIZATION COMPLETE" < <(journalctl --lines=10 -u omnia)
assert "Scuttlebot service is up" \
  no_match "Error" < <(journalctl --lines=10 -u ssb-server)
