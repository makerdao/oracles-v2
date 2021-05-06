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

sudo cp /vagrant/tests/resources/mitmproxy/mitmproxy-ca-cert.pem /usr/local/share/ca-certificates/mitmproxy.crt
sudo chmod 0644 /usr/local/share/ca-certificates/mitmproxy.crt
sudo update-ca-certificates
ls -la /etc/ssl/certs | grep mitm

cat <<EOD
For a basic installation of the 'local' version of Omnia, run:
  vagrant ssh -c "oracle install && oracle configure && oracle enable"
EOD
