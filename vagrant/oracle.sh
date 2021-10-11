#!/usr/bin/env bash

set -eu

_command="${1:-""}"

if [[ -z "$_command" ]]; then
	cat <<EOD
Usage: oracle COMMAND
Commands:
  * install - install omnia
    * install VERSION
      - default: local
      - stable, current
    * install commit COMMIT_HASH
  * configure OPTIONS
    - default: --feed
    - --relay
    - --gofer - only gofer
    - --spire - only spire
  * enable
  * restart
  * connect - accept invites included in .local/ssb-invites.txt (one per line)
  * status
  * log
  * log-all
  * state
EOD
	exit 1
fi

if [[ "$1" == "install" ]]; then
	_version=${2:-"local"}
	if [[ $_version == "local" ]]; then
		_file="/vagrant"
	elif [[ $_version == "commit" ]]; then
		_file="https://github.com/makerdao/oracles-v2/archive/${3}.tar.gz"
	else
		if [[ "$_version" == "current" ]]; then
			_version="v$(head /vagrant/omnia/lib/version | tr -d '\n')"
		fi
		_file="https://github.com/makerdao/oracles-v2/tarball/$_version"
	fi
  echo "Uninstalling old Omnia"
	nix-env --uninstall omnia || echo >&2 "No cleanup needed"
  echo "Installing from: $_file"
	nix-env --install --file "$_file"
fi

if [[ "$1" == "configure" ]]; then
  opts=()

	opts+=(--ssb-caps "/vagrant/tests/resources/caps.json")
	opts+=(--override-origin "openexchangerates" "apiKey" "xxx")
	opts+=(--ssb-external "$(curl -s ifconfig.me)")
	opts+=(--keystore "/vagrant/tests/resources/keys")
	opts+=(--password "/vagrant/tests/resources/password")
	opts+=(--from "0x$(jq -c -r '.address' "/vagrant/tests/resources/keys/UTC--2020-04-20T06-52-55.157141634Z--1f8fbe73820765677e68eb6e933dcb3c94c9b708")")
	opts+=(--eth-rpc "http://127.0.0.1:8888")
	opts+=(--eth-rpc "http://127.0.0.1:8889")

	_mode="feed"
	_restart=""
	_log=""
	while [[ -n "${2-}" ]]; do
		case "$2" in
			--relay)
				_mode="relay"
				;;
			--gofer)
				opts+=(--no-source --add-source "gofer")
				;;
			--spire)
				opts+=(--no-transport --add-transport "transport-spire")
				;;
			--restart)
				_restart="true"
				;;
			--log)
				_log="true"
				;;
			--debug)
				export ORACLE_DEBUG="true"
				;;
			*)
				echo >&2 "\"$2\" is not a valid option"
				;;
		esac
		shift
	done

	cmd=("install-omnia" "$_mode")
	cmd+=("${opts[@]}")

	echo -e "\n\n${cmd[*]}\n\n"

	"${cmd[@]}"
	[[ -z "$_restart" ]] || oracle restart
	[[ -z "$_log" ]] || oracle log
fi

if [[ "$1" == "enable" ]]; then
	sudo systemctl daemon-reload
	sudo systemctl enable --now ssb-server
	sudo systemctl enable --now omnia
	sudo systemctl enable --now gofer-agent
	sudo systemctl enable --now spire-agent
	sudo systemctl enable --now splitter-agent

	oracle status
fi

if [[ "$1" == "restart" ]]; then
	sudo systemctl daemon-reload
	sudo systemctl restart ssb-server
	sudo systemctl restart omnia
	sudo systemctl restart gofer-agent
	sudo systemctl restart spire-agent
	sudo systemctl restart splitter-agent

	oracle status
fi

if [[ "$1" == "stop" ]]; then
	sudo systemctl stop ssb-server
	sudo systemctl stop omnia
	sudo systemctl stop gofer-agent
	sudo systemctl stop spire-agent
	sudo systemctl stop splitter-agent

	oracle status
fi

if [[ "$1" == "connect" ]]; then
	while IFS= read -r line; do
		ssb-server invite.accept "$line"
	done < /vagrant/.local/ssb-invites.txt
fi

if [[ "$1" == "status" ]]; then
	systemctl status ssb-server omnia gofer-agent spire-agent splitter-agent --no-pager --lines=0
fi

if [[ "$1" == "log-all" ]]; then
	journalctl -q -f -u omnia -u ssb-server -u gofer-agent -u spire-agent -u splitter-agent
fi

if [[ "$1" == "log" ]]; then
	journalctl -q -f -u omnia
fi

if [[ "$1" == "state" ]]; then
	watch du -h "$HOME/.ssb/flume/log.offset"
fi

if [[ "$1" == "smoke" ]]; then
	nix-shell /vagrant/tests --run testSmoke
fi

if [[ "$1" == "test" ]]; then
	nix-shell /vagrant/tests --run testE2E
fi

if [[ "$1" == "rec" ]]; then
	nix-shell /vagrant/tests --run recordE2E
fi