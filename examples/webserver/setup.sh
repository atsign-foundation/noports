#!/bin/bash
# get the current script path
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Build the webserver image
docker build "$DIR/../.." -f "$DIR/server/Dockerfile" -t sshnpd_webserver:local