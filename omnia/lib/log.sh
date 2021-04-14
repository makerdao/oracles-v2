#log console output with timestamp
function log {
 	echo "[$(date "+%D %T")] $1" >&2
}

#log verbose console output with timestamp
function verbose {
 	[[ $OMNIA_VERBOSE == "true" ]] && echo "[$(date "+%D %T")] [V] $1" >&2
 	return 0
}

#log error console output with timestamp
function error {
	echo "[$(date "+%D %T")] [E] $1" >&2
}

#log debug information after error
function debug {
	echo "[$(date "+%D %T")] [D] $1" >&2
}