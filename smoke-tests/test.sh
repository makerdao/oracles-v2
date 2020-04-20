#!/bin/bash
tpath="${0%/*}"
rpath="$(cd $tpath; pwd)/resources"

from_addr=0x1f8fbe73820765677e68eb6e933dcb3c94c9b708
keystore_path="$rpath/keys"
key_path="$rpath/key"
cmc_api_key="9e70da6e-09fc-4167-a8f7-68f4e7e907a5"

before() {
  #nix run -f . pkgs.go-ethereum-unlimited pkgs.dapp -c dapp --testnet-launch &
  nix run -f $tpath/.. -c install-omnia feed \
    --from        "$from_addr" \
    --keystore    "$keystore_path" \
    --password    "$key_path" \
    --cmc-api-key "$cmc_api_key" \
    | sudo sh
}

after() {
  sudo systemctl stop omnia
}

. $tpath/tap.sh

plan 9
timeout 60

assert "Install config" \
  test -f /etc/omnia.conf

cat /etc/omnia.conf > $wdir/output
assert "Has set ethereum from address" \
  json .ethereum.from <<<"\"$from_addr\""
assert "Has set ethereum keystore" \
  json .ethereum.keystore <<<"\"$keystore_path\""
assert "Has set keystore password file" \
  json .ethereum.password <<<"\"$key_path\""
assert "Has CMC API key" \
  json .services.cmcApiKey <<<"\"$cmc_api_key\""

sleep 2

assert "Omnia service is active" \
  match "Active: active" < <(systemctl status omnia)
assert "Scuttlebot service is active" \
  match "Active: active" < <(systemctl status ssb-server)

sleep 5

assert "Omnia service is up" \
  no_match "Error" < <(journalctl --lines=10 -u omnia)
assert "Scuttlebot service is up" \
  no_match "Error" < <(journalctl --lines=10 -u ssb-server)
