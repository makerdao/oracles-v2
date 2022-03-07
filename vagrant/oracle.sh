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
	opts+=(--ssb-port "8008")
	opts+=(--ssb-host "localhost")
	opts+=(--override-origin "openexchangerates" "apiKey" "xxx")
	opts+=(--ssb-external "$(curl -s ifconfig.me)")
	opts+=(--keystore "/vagrant/tests/resources/keys")
	opts+=(--password "/vagrant/tests/resources/password")
	opts+=(--from "0x$(jq -c -r '.address' "/vagrant/tests/resources/keys/UTC--2020-04-20T06-52-55.157141634Z--1f8fbe73820765677e68eb6e933dcb3c94c9b708")")
	opts+=(--eth-rpc "http://127.0.0.1:8888")
#	opts+=(--eth-rpc "http://127.0.0.1:8889")
	opts+=(--l2-eth-rpc "http://127.0.0.1:8888")
#	opts+=(--l2-eth-rpc "http://127.0.0.1:8889")

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
			--ssb)
				opts+=(--no-transport --add-transport "transport-ssb" --add-transport "transport-ssb-rpc")
				;;
			--ssb-rpc)
				opts+=(--no-transport --add-transport "transport-ssb-rpc")
				;;
			--restart)
				_restart="true"
				;;
			--log)
				_log="true"
				;;
			--debug)
				export ORACLE_DEBUG="true"
				opts+=(--debug)
				;;
			--verbose)
				opts+=(--verbose --logFormat "json")
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

	sudo systemctl daemon-reload

	[[ -z "$_restart" ]] || oracle restart
	[[ -z "$_log" ]] || oracle log
fi

if [[ "$1" == "enable" ]]; then
	sudo systemctl enable --now ssb-server
	sudo systemctl enable --now gofer-agent
	sudo systemctl enable --now spire-agent
	sudo systemctl enable --now splitter-agent
	sudo systemctl enable --now leeloo-agent

	sudo systemctl enable --now omnia

	oracle status
fi

if [[ "$1" == "start" || "$1" == "stop" || "$1" == "restart" ]]; then
	sudo systemctl "$1" omnia

	sudo systemctl "$1" ssb-server
	sudo systemctl "$1" gofer-agent
	sudo systemctl "$1" spire-agent
	sudo systemctl "$1" splitter-agent
	sudo systemctl "$1" leeloo-agent

	oracle status
fi

if [[ "$1" == "connect" ]]; then
	while IFS= read -r line; do
		ssb-server invite.accept "$line"
	done < /vagrant/.local/ssb-invites.txt
fi

if [[ "$1" == "status" ]]; then
	systemctl status ssb-server omnia gofer-agent spire-agent splitter-agent leeloo-agent --no-pager --lines=0
fi

if [[ "$1" == "log-all" ]]; then
	journalctl -q -f -u omnia -u ssb-server -u gofer-agent -u spire-agent -u splitter-agent -u leeloo-agent
fi

if [[ "$1" == "log" ]]; then
	journalctl -q -f -u "${2:-omnia}"
fi

if [[ "$1" == "state" ]]; then
	watch du -h "$HOME/.ssb/flume/log.offset"
fi

if [[ "$1" == "smoke" ]]; then
	nix-shell /vagrant/tests --run testSmoke
fi

if [[ "$1" == "rec" ]]; then
	nix-shell /vagrant/tests --run recordE2E
fi