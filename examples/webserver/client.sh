#!/bin/bash
# Usage: $(client.sh)
# Then visit http://localhost:8080
# If you see the default apache page, then consider it a success!

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Load environment variables
# shellcheck source=/dev/null
source "$DIR"/../.env

sshnp \
-f "$FROM" \
-t "$TO" \
-d "$DEVICE" \
-h "$HOST" \
-s "$SSH_PUBLIC_KEY" \
-v \
-o '-L 127.0.01:8080:127.0.0.1:80'
