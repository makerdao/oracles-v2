#!/bin/bash
tpath="$(cd ${0%/*}; pwd)"
rpath="$tpath/resources"

from_addr="0x1f8fbe73820765677e68eb6e933dcb3c94c9b708"
keystore_path="$rpath/keys"
key_path="$rpath/key"

install_feed() {
  install-omnia feed \
    --from         "$from_addr" \
    --keystore     "$keystore_path" \
    --password     "$key_path" \
    --ssb-external "example.org" \
    --ssb-caps     "$rpath/caps.json" \
    | sudo sh
}

install_relayer() {
  # Start geth testnet
  rm -rf "$HOME/.dapp/testnet"
  nohup >/dev/null 2>&1 \
    dapp --testnet-launch &
  sleep 2

  install-omnia relayer \
    --ssb-external "example-2.org" \
    | sudo sh
}

after() {
  pkill dapp
  sudo systemctl stop omnia ssb-server
}

. "$tpath/tap.sh"

plan 30
timeout 60

note <<<"INSTALL FEED"

feed_start=$(date +"%F %T")
assert "Install feed" run install_feed

assert "Scuttlebot config installed" \
  test -f $HOME/.ssb/config

cat $HOME/.ssb/config > $wdir/output
assert "SSB external IP set" \
  json '.connections.incoming.net[0].external' <<<'"example.org"'
assert "SSB external IP set" \
  json '.connections.incoming.ws[0].external' <<<'"example.org"'
assert "SSB caps set" \
  json .caps < "$rpath/caps.json"

assert "Omnia feed config installed" \
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

sleep 2

assert "Omnia feed service is active" \
  match "Active: active" < <(capture systemctl status omnia)
assert "Scuttlebot service is active" \
  match "Active: active" < <(capture systemctl status ssb-server)

sleep 5

assert "Omnia feed service is up" \
  match "INITIALIZATION COMPLETE" < <(capture journalctl --since "$feed_start" -u omnia)
assert "Scuttlebot service is up" \
  match "my key ID:" < <(capture journalctl --since "$feed_start" -u ssb-server)

assert "SSB create invite" \
  match '^"example.org:8007:' < <(capture ssb-server invite.create 1)

note <<<"INSTALL RELAYER"

relayer_start=$(date +"%F %T")
assert "Install relayer" run install_relayer

assert "Scuttlebot config installed" \
  test -f $HOME/.ssb/config

cat $HOME/.ssb/config > $wdir/output
assert "SSB external IP set" \
  json '.connections.incoming.net[0].external' <<<'"example-2.org"'
assert "SSB external IP set" \
  json '.connections.incoming.ws[0].external' <<<'"example-2.org"'
assert "SSB caps set" \
  json .caps < "$rpath/caps.json"

assert "Omnia relayer config installed" \
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
  match "Active: active" < <(capture systemctl status omnia)
assert "Scuttlebot service is active" \
  match "Active: active" < <(capture systemctl status ssb-server)

sleep 5

assert "Omnia relayer service is up" \
  match "INITIALIZATION COMPLETE" < <(capture journalctl --since "$relayer_start" -u omnia)
assert "Scuttlebot service is up" \
  match "my key ID:" < <(capture journalctl --since "$relayer_start" -u ssb-server)

assert "SSB create invite" \
  match '^"example-2.org:8007:' < <(capture ssb-server invite.create 1)
