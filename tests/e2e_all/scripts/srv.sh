#!/bin/bash

# Sometimes while testing it's handy to execute this script rather than executing the srv directly

binDir="$(dirname -- "$0")"

mkdir -p /tmp/noports

"${binDir}/srv" "$@" 2>&1 | tee -a /tmp/noports/srv.sh.$$.log
# "${binDir}/srv" "$@" >> /tmp/noports/srv.sh.$$.log 2>&1
echo "Exit code was $? " >> /tmp/noports/srv.sh.$$.log
