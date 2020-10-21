#!/usr/bin/env bash

# set -o errexit

OMNIA_HOME=/home/omnia
NIX_BIN=$OMNIA_HOME/.nix-profile/bin

mkdir -p $OMNIA_HOME/secrets
# Convert required env vars to files for install-omnia
[[ -z "$OMNIA_CAPS" ]] && echo "OMNIA_CAPS not set" || echo "$OMNIA_CAPS" > $OMNIA_HOME/secrets/caps.json
[[ -z "$OMNIA_KEYSTORE" ]] && echo "OMNIA_KEYSTORE not set" || echo "$OMNIA_KEYSTORE" > $OMNIA_HOME/secrets/keystore.json
[[ -z "$OMNIA_PASSWORD" ]] && echo "OMNIA_PASSWORD not set" || echo "$OMNIA_PASSWORD" > $OMNIA_HOME/secrets/password.txt

echo "INSTALL OMNIA"
sudo -E \
    $NIX_BIN/install-omnia feed \
        --ssb-external $EXT_IP \
        --from $ETH_FROM \
        --ssb-caps $OMNIA_HOME/secrets/caps.json \
        --keystore $OMNIA_HOME/secrets \
        --password $OMNIA_HOME/secrets/password.txt

sudo chown -R omnia $OMNIA_HOME/.ssb/

echo "OMNIA CONFIG"
cat /etc/omnia.conf

# Todo run with `tini` and output logs to stdout
# or better yet separate into its own container
echo "START SSB"
$NIX_BIN/ssb-server start &

echo "ACCEPT INVITE"
$NIX_BIN/ssb-server invite.accept $SSB_INVITE

sleep 10

# SSB server becomes unresponsive after accepting an invite
# As it spends all its single thread resources to index new data.
# Wait for SSB server to index data only then move on.
until $NIX_BIN/ssb-server whoami &> /dev/null; do echo "Waiting for SSB server index to finish...";sleep 30; done

echo "START OMNIA"
sudo -u omnia $NIX_BIN/omnia
