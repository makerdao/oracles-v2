#!/usr/bin/env bash
timestamp=$(date "+%m-%d-%y+%H:%M:%S")
if [ -f "$HOME"/logs/scuttlebot.log ]; then
    echo "Archiving Scuttlebot logs"
    mkdir -p "$HOME"/logs/archives/"$timestamp"
    cp "$HOME"/logs/scuttlebot.log "$HOME"/logs/archives/"$timestamp"/scuttlebot.log
fi
PID_SCUT=$(ps aux | grep scuttlebot | grep -v grep | awk '{print $2}')
if ! [[ -z $PID_SCUT ]]; then
    echo "Scuttlebot is still running, killing existing instance"
    kill "$PID_SCUT"
    sleep 3
fi
echo "Launching Scuttlebot Server..."
nohup "$HOME"/scuttlebot/bin.js server >"$HOME"/logs/scuttlebot.log &

sleep 2
if [ -f "$HOME"/logs/omnia.log ]; then
    echo "Archiving Omnia logs"
    mkdir -p "$HOME"/logs/archives/"$timestamp"
    cp "$HOME"/logs/omnia.log "$HOME"/logs/archives/"$timestamp"/omnia.log
fi
PIDS_OMNIA=$(ps aux | grep omnia | grep -v grep | awk '{print $2}')
if ! [[ -z $PIDS_OMNIA ]]; then
    echo "Omnia is still running, killing existing instance"
    for PID in "${PIDS_OMNIA[@]}"; do
	kill $PID
    done
    sleep 3
fi
echo "Launching Omnia..."
nohup "$HOME"/oracles-v2/omnia/omnia.sh >"$HOME"/logs/omnia.log &
