#!/usr/bin/env bash
# Stops an ephemeral environment that setup_ee.sh started, and deletes the
# keyfiles it onboarded for the given atSigns, which no other EE can use.
#
# Usage: teardown_ee.sh <container_name> <atsign>...
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <container_name> <atsign>..." >&2
  exit 1
fi
NAME="$1"
shift

docker rm -f "$NAME" > /dev/null 2>&1 || true
for a in "$@"; do
  rm -f "$HOME/.atsign/keys/@${a}_key.atKeys"
done
echo "EE $NAME removed"
