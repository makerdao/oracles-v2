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
