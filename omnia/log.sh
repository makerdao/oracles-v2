#!/usr/bin/env bash

#log console output with timestamp
function log {
 	echo "[$(date "+%D %T")] $1" >&2
}

#log verbose console output with timestamp
function verbose {
 	[[ $OMNIA_VERBOSE ]] && echo "[$(date "+%D %T")] [V] $1" >&2
}

#log err console output with timestamp
function error {
	echo "[$(date "+%D %T")] [E] $1" >&2
}