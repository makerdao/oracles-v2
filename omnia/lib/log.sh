#log console output with timestamp
function log() {
	_log "info" "$@" >&2
}

#log verbose console output with timestamp
function verbose() {
	if  [[ $OMNIA_VERBOSE == "true" ]]; then
		_log "verbose" "$@" >&2
	fi
}

#log error console output with timestamp
function error() {
	_log "error" "$@" >&2
}

function warning() {
	_log "warning" "$@" >&2
}

#log debug information after error
function debug() {
	if  [[ -n $OMNIA_DEBUG ]] && [[ $OMNIA_DEBUG != "false" ]] && [[ $OMNIA_DEBUG != "0" ]]; then
		_log "debug" "$@" >&2
	fi
}

# _log LEVEL MESSAGE [KEY=VAL [KEY=VAL]...]
function _log() {
	local _level="${1,,}"
	if [[ -z $_level ]]; then
		_log "error" "missing log level"
		return 1
	fi
	if ! [[ $_level =~ ^(error|warning|info|verbose|debug)$ ]]; then
		_log "error" "allowed log levels: error|warning|info|verbose|debug"
		return 1
	fi

	local _argType
	if [[ "${2,,}" == "--list" ]]; then
		_argType="list"
		shift
	fi

	local _msg="${2}"
	if [[ -z $_msg ]]; then
		_log "error" "missing log message"
		return 1
	fi

	shift 2

	local _logEntry

	if [[ $OMNIA_LOG_FORMAT == "json" ]]; then
		if [[ $# -eq 0 ]]; then
			_logEntry="$(_jsonArgs "level=$_level" "msg=$_msg" "time#=$(date "+%s")")"
		else
			if [[ $_argType == "list" ]]; then
				_logEntry="$(_jsonArgs "level=$_level" "msg=$_msg" "time#=$(date "+%s")" "#=$(_jsonList "$@")")"
			else
				_logEntry="$(_jsonArgs "level=$_level" "msg=$_msg" "time#=$(date "+%s")" "#=$(_jsonArgs "$@")")"
			fi
		fi
	else
		_level="${_level:0:1}"
		_level="${_level^^}"

		if [[ $# -eq 0 ]]; then
			_logEntry="[$(date "+%D %T")] [$_level] $_msg"
		else
			_logEntry="[$(date "+%D %T")] [$_level] $_msg $*"
		fi
	fi

	echo "$_logEntry"
}

function _jsonArgs() {
	local _args=""

	local _key
	local _value
	for ARGUMENT in "$@"; do
		_key="$(echo "$ARGUMENT" | cut -f1 -d=)"
		_value="$(echo "$ARGUMENT" | cut -f2- -d=)"

		if [[ -n "$_args" ]]; then
			_args="${_args},"
		fi

		if [[ $_key == "#" ]]; then
			_args="${_args}\"params\":${_value}"
		elif [[ $_key =~ [a-z0-9]+#$ ]]; then
			_args="${_args}\"${_key%#}\":${_value}"
		else
			_args="${_args}\"${_key}\":\"${_value}\""
		fi
	done

	echo -n "{${_args}}"
}

function _jsonList() {
	local _args=""
	local arg

	for arg in "$@"; do
		if [[ -n "$_args" ]]; then
			_args="${_args},"
		fi
		_args="${_args}\"${arg}\""
	done

	echo -n "[${_args}]"
}
