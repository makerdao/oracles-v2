#!/usr/bin/env bash

# set -o errexit

OMNIA_HOME=/home/omnia
NIX_BIN=$OMNIA_HOME/.nix-profile/bin

mkdir -p $OMNIA_HOME/secrets
# Convert required env vars to files for install-omnia
[[ -z "$OMNIA_CAPS" ]] && echo "OMNIA_CAPS not set" || echo "$OMNIA_CAPS" > $OMNIA_HOME/secrets/caps.json
[[ -z "$OMNIA_KEYSTORE" ]] && echo "OMNIA_KEYSTORE not set" || echo "$OMNIA_KEYSTORE" > $OMNIA_HOME/secrets/keystore.json
[[ -z "$OMNIA_PASSWORD" ]] && echo "OMNIA_PASSWORD not set" || echo "$OMNIA_PASSWORD" > $OMNIA_HOME/secrets/password.txt

echo '##################'
echo "INSTALL OMNIA"
echo '##################'
sudo -E \
    $NIX_BIN/install-omnia feed \
        --ssb-external $EXT_IP \
        --from $ETH_FROM \
        --ssb-caps $OMNIA_HOME/secrets/caps.json \
        --keystore $OMNIA_HOME/secrets \
        --password $OMNIA_HOME/secrets/password.txt

sudo chown -R omnia $OMNIA_HOME/.ssb/

echo '##################'
echo "OMNIA CONFIG"
echo '##################'
cat /etc/omnia.conf

echo '##################'
echo "START SSB"
echo '##################'
$NIX_BIN/ssb-server start &

sleep 40

echo '##################'
echo "ACCEPT INVITE"
echo '##################'
$NIX_BIN/ssb-server invite.accept $SSB_INVITE

echo '##################'
echo "START OMNIA"
echo '##################'
sudo -E -u omnia $NIX_BIN/omnia
