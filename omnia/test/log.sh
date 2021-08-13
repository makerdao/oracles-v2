#!/bin/bash
test_path=$(cd "${BASH_SOURCE[0]%/*}"; pwd)
root_path=$(cd "$test_path/.."; pwd)
lib_path="$root_path/lib"

source "$lib_path/log.sh"
source "$root_path/tap.sh" 2>/dev/null || . "$root_path/../tests/lib/tap.sh"

assert "logger requires log level" match "^\[[^]]+\] \[E\] missing log level$" < <(_log 2>&1)
assert "logger allows only defined levels" match "^\[[^]]+\] \[E\] allowed log levels: error|warning|info|verbose|debug$" < <(_log "test" 2>&1)
assert "logger allows error level & requires log message" match "^\[[^]]+\] \[E\] missing log message$" < <(_log "error" 2>&1)
assert "logger allows warning level" match "^\[[^]]+\] \[W\] test message$" < <(_log "warning" "test message" 2>&1)
assert "logger allows info level" match "^\[[^]]+\] \[I\] test message$" < <(_log "info" "test message" 2>&1)
assert "logger allows verbose level" match "^\[[^]]+\] \[V\] test message$" < <(_log "verbose" "test message" 2>&1)
assert "logger allows debug level" match "^\[[^]]+\] \[D\] test message$" < <(_log "debug" "test message" 2>&1)
assert "logger includes rest of the arguments" match "^\[[^]]+\] \[D\] test message alpha beta gamma delta$" < <(_log "debug" "test message" "alpha" "beta" "gamma" "delta" 2>&1)

OMNIA_LOG_FORMAT="json"

assert "logger creates valid json" run_json _log "debug" "test message" "alpha=1" "beta=x" "gamma=true" "delta"
assert "json output has all keys" json 'keys' <<< '["level","msg","params","time"]'
assert "json output has all subkeys" json '.params|keys' <<< '["alpha","beta","delta","gamma"]'
assert "log level is set properly" json '.level' <<< '"debug"'
assert "log message is set properly" json '.msg' <<< '"test message"'
assert "property is set properly" json '.params.alpha' <<< '"1"'
assert "property is set properly" json '.params.beta' <<< '"x"'
assert "property is set properly" json '.params.gamma' <<< '"true"'
assert "property is set properly" json '.params.delta' <<< '"delta"'

assert "logger creates valid json" run_json _log "info" --list "test message" "alpha=1" "beta=x" "gamma=true" "delta"
assert "json output has all keys" json 'keys' <<< '["level","msg","params","time"]'
assert "json output has all keys" json '.params|length' <<< '4'

unset OMNIA_LOG_FORMAT

assert "verbose does not output without OMNIA_VERBOSE env var set" match "^--$" <<< "-$(verbose "test message" 2>&1)-"
OMNIA_VERBOSE="yes"
assert "verbose does not output without OMNIA_VERBOSE env var set explicitly to 'true'" match "^--$" <<< "-$(verbose "test message" 2>&1)-"
OMNIA_VERBOSE="true"
assert "verbose outputs OMNIA_VERBOSE env var set explicitly to 'true'" match "^\[[^]]+\] \[V\] test message$" <<< "$(verbose "test message" 2>&1)"

OMNIA_LOG_FORMAT="json"
verbose "verbose message" 2> "$wdir/output"
assert "log level is set properly" json '.level' <<< '"verbose"'
assert "log message is set properly" json '.msg' <<< '"verbose message"'

unset OMNIA_LOG_FORMAT

assert "debug does not output without OMNIA_DEBUG env var set" match "^--$" <<< "-$(debug "test message" 2>&1)-"
OMNIA_DEBUG=0
assert "debug does not output when OMNIA_DEBUG env var set to 0" match "^--$" <<< "-$(debug "test message" 2>&1)-"
OMNIA_DEBUG="false"
assert "debug does not output when OMNIA_DEBUG env var set to false" match "^--$" <<< "-$(debug "test message" 2>&1)-"

OMNIA_DEBUG=1
assert "debug outputs OMNIA_DEBUG env var set to 1" match "^\[[^]]+\] \[D\] test message$" <<< "$(debug "test message" 2>&1)"
OMNIA_DEBUG="true"
assert "debug outputs OMNIA_DEBUG env var set to true" match "^\[[^]]+\] \[D\] test message$" <<< "$(debug "test message" 2>&1)"

OMNIA_LOG_FORMAT="json"
debug "debug message" 2> "$wdir/output"
assert "log level is set properly" json '.level' <<< '"debug"'
assert "log message is set properly" json '.msg' <<< '"debug message"'
