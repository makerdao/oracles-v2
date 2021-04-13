#!/usr/bin/env bash

set -eu

curl --silent --location https://nixos.org/nix/install | sh
source /home/vagrant/.nix-profile/etc/profile.d/nix.sh

nix-env -iA cachix -f https://cachix.org/api/v1/install
cachix use maker
cachix use dapp

nix-env -iA nixpkgs.jq

mkdir -p /home/vagrant/bin
ln -sf /vagrant/vagrant/oracle.sh /home/vagrant/bin/oracle

msg=$(cat <<EOD)
For a basic installation of the 'stable' version of Omnia, run:
  vagrant ssh -c "oracle install && oracle configure && oracle enable"
EOD
cat "$msg"
