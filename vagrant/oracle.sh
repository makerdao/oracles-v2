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
fi

if [[ "$1" == "configure" ]]; then
	install-omnia feed \
	--ssb-caps "/vagrant/.local/ssb-caps.json" \
	--ssb-external "$(curl -s ifconfig.me)" \
	--keystore "/vagrant/.local/eth-keystore" \
	--password "/vagrant/.local/eth-keystore-password.txt"
fi

if [[ "$1" == "configure-gofer" ]]; then
	install-omnia feed \
	--ssb-caps "/vagrant/.local/ssb-caps.json" \
	--ssb-external "$(curl -s ifconfig.me)" \
	--no-source \
	--add-source "gofer" \
	--keystore "/vagrant/.local/eth-keystore" \
	--password "/vagrant/.local/eth-keystore-password.txt"
fi

if [[ "$1" == "configure-spire" ]]; then
	install-omnia feed \
	--ssb-caps "/vagrant/.local/ssb-caps.json" \
	--ssb-external "$(curl -s ifconfig.me)" \
	--no-transport \
	--add-transport "transport-spire" \
	--keystore "/vagrant/.local/eth-keystore" \
	--password "/vagrant/.local/eth-keystore-password.txt"
fi

if [[ "$1" == "enable" ]]; then
	sudo systemctl daemon-reload
	sudo systemctl enable --now ssb-server
	sudo systemctl enable --now omnia
	sudo systemctl enable --now gofer-agent
	sudo systemctl enable --now spire-agent

	oracle status
fi

if [[ "$1" == "restart" ]]; then
	sudo systemctl daemon-reload
	sudo systemctl restart ssb-server
	sudo systemctl restart omnia
	sudo systemctl restart gofer-agent
	sudo systemctl restart spire-agent

	oracle status
fi

if [[ "$1" == "connect" ]]; then
	while IFS= read -r line; do
		ssb-server invite.accept "$line"
	done < /vagrant/.local/ssb-invites.txt
fi

if [[ "$1" == "status" ]]; then
	systemctl status ssb-server omnia gofer-agent spire-agent --no-pager
fi

if [[ "$1" == "log" ]]; then
	journalctl -q -u ssb-server -u omnia -u gofer-agent -u gofer-agent -f
fi

if [[ "$1" == "state" ]]; then
	watch du -h "$HOME/.ssb/flume/log.offset"
fi
