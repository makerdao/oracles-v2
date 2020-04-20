#!/bin/bash

# Copyright 2020 Christopher Fredén
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

trap "trap - 1 2 3 15; end" EXIT
trap "trap - ERR; err" ERR
trap "trap - INT; int" INT
trap "trap - HUP; timeup" HUP

set -eo pipefail

wdir=$(mktemp -d "${TMPDIR:-/tmp}"/tapsh.XXXXXXXX)

log() { cat >> $wdir/log; }
note() { sed 's/^/# /'; }
run() {
  ( set -x
    "$@"
    { set +x; } >/dev/null 2>&1
  ) 2>&1 </dev/null | log
}
cleanup() { rm -rf $wdir; clear_timeout; }
end() {
  if command -v after >/dev/null 2>&1; then
    ( set -x
      after || true
      { set +x; } >/dev/null 2>&1
    ) 2>&1 </dev/null | log
  fi
  if [[ ! $plan ]]; then
    plan $test_count
  fi
  if [[ $failed_tests != 0 ]]; then
    echo "# Failed $failed_tests out of $test_count tests"
    exit_code=${exit_code:-1}
  fi
  if [[ $test_count != $plan ]]; then
    echo "# Plan failed, ran $test_count tests, plan was $plan"
    exit_code=${exit_code:-2}
  fi
  if [[ $exit_code ]]; then
    {
      echo
      echo "STDOUT trace:"
      cat $wdir/log
    } | note
  else
    echo "# Success, ran $test_count tests!"
    exit_code=${exit_code:-0}
  fi
  cleanup
  exit $exit_code
}
int() {
  echo "# Test interrupted, test did NOT finish correctly"
  exit_code=3
  exit
}
err() {
  msg="${@+": $@"}"
  echo "# Unexpected error, test did NOT run correctly$msg"
  exit_code=4
  exit
}
timeup() {
  timeoutpid=""
  echo "# Timeout reached, test took too long"
  exit_code=5
  exit
}

clear_timeout() {
  if [ "$timeoutpid" ]; then
    pkill -PIPE -P $timeoutpid
    timeoutpid=""
  fi
}
timeout() {
  if [ "$timeoutpid" ]; then
    echo "# Warning: timeout called more than once! Ignoring"
  else
    ( sleep $1
      kill -HUP 0
    ) & timeoutpid=$!
  fi
}

test_count=0
failed_tests=0
exit_code=""
timeoutpid=""

plan() {
  plan=$1
  echo 1..$plan
}

assert() {
  ((test_count+=1))
  local desc="${1:+$1 }"; shift
  local ecode=0
  local res
  res="$("$@")" || { ecode=$?; true; }
  [[ $ecode == 0 && ! $res ]] \
    && echo "ok $test_count - $desc> $@" \
    || { ((failed_tests+=1)); echo "not ok $test_count - $desc> $@"; if [[ $res ]]; then cat <<EOF
  ---
$(sed 's/^/  /g' <<<"$res")
  ...
EOF
      fi
    }
}

output(){
  jq 2>&1 -S "${*-.}" < $wdir/output
}
json() {
  jq 2>&1 -S . > $wdir/expect-$test_count.json
  output "${*-.}" > $wdir/got-$test_count.json
  local res="$(diff -u $wdir/expect-$test_count.json $wdir/got-$test_count.json)"
  [[ ! $res ]] || { cat <<EOF
diff: |
$(sed 's/^/  /g' <<<"$res")
EOF
  }
}

match() {
  local input="$(cat)"
  local m="$(grep -o "$1" <<<"$input")"
  [[ $m ]] || { cat <<EOF
got: |
$(sed 's/^/  /' <<<"$input")
expect: $1
EOF
  }
}
no_match() {
  local input="$(cat)"
  local m="$(grep -o "$1" <<<"$input")"
  [[ ! $m ]] || { cat <<EOF
got: |
$(sed 's/^/  /' <<<"$input")
expect: $1
EOF
  }
}
status() { match "^< HTTP/.* $1 " < $wdir/headers; }
status_error() { status '[4-5][0-9][0-9]'; }

http() {
  local url="$BASE_URL"
  local method=$(test x$1 == xpost && echo "-d @-")
  local path="$2"
  shift 2
  while [ "$1" ]; do case "$1" in
    --url) url="$2"; shift 2;;
    --) shift; local flags="$@"; break;;
    *) shift;;
  esac; done
  curl \
    $method \
    $flags \
    -v --silent \
    -b $wdir/cookiefile -c $wdir/cookiefile \
    -H Content-Type:\ application/json \
    -H Accept:\ application/json \
    -o $wdir/output-$test_count \
    $url/$path 2> $wdir/headers-$test_count || (
      touch $wdir/output-$test_count
      cat <<EOF
message: |
$(sed 's/^/  /' < $wdir/headers-$test_count)
EOF
    )
  ln -sf $wdir/output-$test_count $wdir/output
  ln -sf $wdir/headers-$test_count $wdir/headers
}
get() { http get $@; }
post() { http post $@; }

touch $wdir/output
touch $wdir/headers

echo TAP version 13

if command -v before >/dev/null 2>&1; then
  { set -x
    before
    { set +x; } >/dev/null 2>&1
  } 2>&1 | log
fi
