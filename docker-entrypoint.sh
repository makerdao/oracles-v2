#!/usr/bin/env bash

set -o errexit

HOME=/home/omnia

mkdir -p $HOME/secrets
# Convert required env vars to files for install-omnia
[[ -z "$OMNIA_CAPS" ]] && echo "OMNIA_CAPS not set" || echo "$OMNIA_CAPS" > $HOME/secrets/caps.json
[[ -z "$OMNIA_KEYSTORE" ]] && echo "OMNIA_KEYSTORE not set" || echo "$OMNIA_KEYSTORE" > $HOME/secrets/keystore.json
[[ -z "$OMNIA_PASSWORD" ]] && echo "OMNIA_PASSWORD not set" || echo "$OMNIA_PASSWORD" > $HOME/secrets/password.txt

echo '##################'
echo "INSTALL OMNIA"
echo '##################'
sudo -E \
    $HOME/.nix-profile/bin/install-omnia feed \
        --ssb-external $EXT_IP \
        --from $ETH_FROM \
        --ssb-caps $HOME/secrets/caps.json \
        --keystore $HOME/secrets \
        --password $HOME/secrets/password.txt

sudo chown -R omnia $HOME/.ssb/

echo '##################'
echo "OMNIA CONFIG"
echo '##################'
cat /etc/omnia.conf

echo '##################'
echo "START SSB"
echo '##################'
/home/omnia/.nix-profile/bin/ssb-server start &

sleep infinity

echo '##################'
echo "ACCEPT INVITE"
echo '##################'
/home/omnia/.nix-profile/bin/ssb-server invite.accept $SSB_INVITE

echo '##################'
echo "START OMNIA"
echo '##################'
sudo -E -iu omnia omnia
