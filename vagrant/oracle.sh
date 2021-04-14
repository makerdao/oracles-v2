#!/usr/bin/env bash

set -eu

_command="${1:-""}"

if [[ -z "$_command" ]]; then
	cat <<EOD
Usage: oracle COMMAND
Commands:
  * install - install stable version
    * install VERSION
    * install commit COMMIT_HASH
  * configure
  * enable
  * upgrade
  * restart
  * connect - accept invites included in .local/ssb-invites.txt (one per line)
  * log
EOD
	exit 1
fi

if [[ "$1" == "install" ]]; then
	_version=${2:-"stable"}
	if [[ $_version == "commit" ]]; then
		nix-env --install -f "https://github.com/makerdao/oracles-v2/archive/${3}.tar.gz"
	else
		if [[ "$_version" == "current" ]]; then
			_version=$(cat /vagrant/omnia/lib/version)
		fi

		nix-env --install -f "https://github.com/makerdao/oracles-v2/tarball/$_version"
	fi

	install-omnia feed --ssb-caps "/vagrant/.local/ssb-caps.json" --ssb-external "$(curl ifconfig.me)"
fi

if [[ "$1" == "configure" ]]; then
	sudo sed -i "/\"from\"/c\\\"from\": \"0x$(jq -c -r '.address' "/vagrant/.local/eth-keystore/1.json")\"," /etc/omnia.conf
	sudo sed -i "/\"keystore\"/c\\\"keystore\": \"/vagrant/.local/eth-keystore\"," /etc/omnia.conf
	sudo sed -i "/\"password\"/c\\\"password\": \"/vagrant/.local/eth-keystore-password.txt\"" /etc/omnia.conf

	grep -E 'from|keystore|password' /etc/omnia.conf
fi

if [[ "$1" == "enable" ]]; then
	sudo systemctl daemon-reload
	sudo systemctl enable --now ssb-server
	sudo systemctl enable --now omnia

	systemctl status ssb-server omnia --no-pager
fi

if [[ "$1" == "upgrade" ]]; then
	_version="$2"
	nix-env --install -f "https://github.com/makerdao/oracles-v2/tarball/$_version"

	install-omnia feed --ssb-caps "/vagrant/.local/ssb-caps.json" --ssb-external "$(curl ifconfig.me)"
fi

if [[ "$1" == "restart" ]]; then
	sudo systemctl daemon-reload
	sudo systemctl restart ssb-server
	sudo systemctl restart omnia

	systemctl status ssb-server omnia
fi

if [[ "$1" == "connect" ]]; then
	while IFS= read -r line; do
		ssb-server invite.accept "$line"
	done < /vagrant/.local/ssb-invites.txt
fi

if [[ "$1" == "log" ]]; then
	systemctl status ssb-server omnia --no-pager
	journalctl -q -u ssb-server
	watch du -h "$HOME/.ssb/flume/log.offset"
fi
