#!/usr/bin/env bash

# set -o errexit

HOME_DIR=/home/omnia

mkdir -p $HOME_DIR/secrets
# Convert required env vars to files for install-omnia
[[ -z "$OMNIA_CAPS" ]] && echo "OMNIA_CAPS not set" || echo "$OMNIA_CAPS" > $HOME_DIR/secrets/caps.json
[[ -z "$OMNIA_KEYSTORE" ]] && echo "OMNIA_KEYSTORE not set" || echo "$OMNIA_KEYSTORE" > $HOME_DIR/secrets/keystore.json
[[ -z "$OMNIA_PASSWORD" ]] && echo "OMNIA_PASSWORD not set" || echo "$OMNIA_PASSWORD" > $HOME_DIR/secrets/password.txt

echo '##################'
echo "INSTALL OMNIA"
echo '##################'
sudo -E \
    $HOME_DIR/.nix-profile/bin/install-omnia feed \
        --ssb-external $EXT_IP \
        --from $ETH_FROM \
        --ssb-caps $HOME_DIR/secrets/caps.json \
        --keystore $HOME_DIR/secrets \
        --password $HOME_DIR/secrets/password.txt

sudo chown -R omnia $HOME_DIR/.ssb/

echo '##################'
echo "OMNIA CONFIG"
echo '##################'
cat /etc/omnia.conf

echo '##################'
echo "START SSB"
echo '##################'
/home/omnia/.nix-profile/bin/ssb-server start &

sleep 40

echo '##################'
echo "ACCEPT INVITE"
echo '##################'
/home/omnia/.nix-profile/bin/ssb-server invite.accept $SSB_INVITE

echo '##################'
echo "START OMNIA"
echo '##################'
sudo -u omnia omnia
