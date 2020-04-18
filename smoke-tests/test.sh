#!/bin/bash
tpath="${0%/*}"
. $tpath/tap.sh

plan 7
timeout 60

{
  set -x
  #nix run -f . go-ethereum-unlimited dapp -c dapp --testnet-launch &
  nix run -f $tpath/.. -c install-omnia feed \
    --from        0x0 \
    --keystore    ./keystore \
    --password    ./passw0rd \
    --cmc-api-key hej \
    | sudo sh
} 2>&1 | log

assert "Install config" \
  test -f /etc/omnia.conf

cat /etc/omnia.conf > $wdir/output
assert "Has set ethereum from address" \
  json .ethereum.from <<<'"0x0"'
assert "Has set ethereum keystore" \
  json .ethereum.keystore <<<'"./keystore"'
assert "Has set keystore password file" \
  json .ethereum.password <<<'"./passw0rd"'
assert "Has CMC API key" \
  json .services.cmcApiKey <<<'"hej"'

assert "Omnia service is active" match "Active: active" < <(systemctl status omnia)
assert "Scuttlebot service is active" match "Active: active" < <(systemctl status ssb-server)
