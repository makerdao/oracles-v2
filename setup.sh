#!/bin/bash

HOME=/home/omnia

mkdir -p $HOME/secrets
[[ -z "$OMNIA_CAPS" ]] && echo "$OMNIA_CAPS not set" || printenv OMNIA_CAPS > $HOME/secrets/caps.json
[[ -z "$OMNIA_KEYSTORE" ]] && echo "$OMNIA_KEYSTORE not set" || printenv OMNIA_KEYSTORE > $HOME/secrets/keystore.json
[[ -z "$OMNIA_PASSWORD" ]] && echo "$OMNIA_PASSWORD not set" || printenv OMNIA_PASSWORD > $HOME/secrets/password.txt

sudo -E \
    $HOME/.nix-profile/bin/install-omnia feed \
        --ssb-external $EXT_IP \
        --from $ETH_FROM \
        --ssb-caps $HOME/secrets/caps.json \
        --keystore $HOME/secrets \
        --password $HOME/secrets/password.txt

sudo chown -R omnia $HOME/.ssb/
cat /etc/omnia.conf
