#!/bin/bash

# Sometimes while testing it's handy to execute this script rather than executing the srv directly

binDir="$(dirname -- "$0")"

mkdir -p /tmp/noports

"${binDir}/srv" "$@" 2>&1 | tee -a /tmp/noports/srv.sh.$$.log
