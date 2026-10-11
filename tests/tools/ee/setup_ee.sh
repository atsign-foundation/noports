#!/usr/bin/env bash
# Starts an ephemeral environment (EE) - an atDirectory and an atServer for
# each atSign, in one container, with the atSigns created afresh - and
# onboards each atSign into ~/.atsign/keys.
#
# Usage: setup_ee.sh <container_name> <atsign>...
#   atSigns are given without the @, lower case, and should be unique to the
#   run, so concurrent runs never share a keyfile.
#
# The atDirectory listens on $BASE_PORT (default 2500), the atServers on the
# 80 ports after it. Prints ROOT_DOMAIN=vip.ve.atsign.zone:<base> when ready.
#
# Prerequisite: 127.0.0.1 vip.ve.atsign.zone in /etc/hosts
set -euo pipefail

DOMAIN="vip.ve.atsign.zone"
IMAGE="${EE_IMAGE:-atsigncompany/ephemeral:dev_env}"
BASE="${BASE_PORT:-2500}"
KEYS_DIR="$HOME/.atsign/keys"
# Daemon containers reach the EE through Docker's host gateway, which on Linux
# reaches only ports published on every interface
if [[ "$(uname)" == "Linux" ]]; then
  PUBLISH="${EE_PUBLISH_ADDRESS:-0.0.0.0}"
else
  PUBLISH="${EE_PUBLISH_ADDRESS:-127.0.0.1}"
fi

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <container_name> <atsign>..." >&2
  exit 1
fi
NAME="$1"
shift
ATSIGNS=("$@")

for a in "${ATSIGNS[@]}"; do
  if [[ ! "$a" =~ ^[a-z0-9_]+$ ]]; then
    echo "ERROR: '$a' is not an atSign name (lower case letters, digits and _ only, no @)" >&2
    exit 1
  fi
  if [[ -e "$KEYS_DIR/@${a}_key.atKeys" ]]; then
    echo "ERROR: $KEYS_DIR/@${a}_key.atKeys already exists; give this run its own atSign names" >&2
    exit 1
  fi
done

if ! grep -q "$DOMAIN" /etc/hosts; then
  echo "ERROR: /etc/hosts must contain: 127.0.0.1 $DOMAIN" >&2
  exit 1
fi

if docker ps -a --format '{{.Names}}' | grep -qx "$NAME"; then
  echo "ERROR: a container named $NAME already exists; remove it or choose another name" >&2
  exit 1
fi

# NOTE: a port in use belongs to someone else, maybe another run's EE, so
# it is refused, never cleared
python3 - "$BASE" <<'PY'
import socket, sys
base = int(sys.argv[1])
busy = []
for port in range(base, base + 100):
    s = socket.socket()
    try:
        s.bind(("127.0.0.1", port))
    except OSError:
        busy.append(port)
    finally:
        s.close()
if busy:
    sys.exit(f"ERROR: ports in use in {base}..{base + 99}: {busy[:10]}")
PY

ATSIGNS_FILE="$(mktemp)"
trap 'rm -f "$ATSIGNS_FILE"' EXIT
printf '%s\n' "${ATSIGNS[@]}" > "$ATSIGNS_FILE"
chmod 644 "$ATSIGNS_FILE"

echo "=== EE setup: $NAME on $DOMAIN:$BASE ($IMAGE) ==="
docker run -d \
  --name "$NAME" \
  -p "$PUBLISH:$BASE-$((BASE + 99)):$BASE-$((BASE + 99))" \
  --add-host "$DOMAIN:127.0.0.1" \
  -e EPHEMERAL_BASE_PORT="$BASE" \
  -v "$ATSIGNS_FILE:/tmp/setup/atsigns:ro" \
  "$IMAGE" > /dev/null

ready=false
for i in $(seq 1 90); do
  count="$(docker exec "$NAME" sh -c 'grep -c . /tmp/CRAM_Keys 2>/dev/null' || true)"
  if [[ "${count:-0}" -ge "${#ATSIGNS[@]}" ]]; then
    echo "atSigns created after ${i}s"
    ready=true
    break
  fi
  sleep 1
done
if [[ "$ready" != true ]]; then
  echo "ERROR: the EE did not create its atSigns within 90s" >&2
  docker logs --tail 30 "$NAME" >&2
  exit 1
fi

mkdir -p "$KEYS_DIR"
for a in "${ATSIGNS[@]}"; do
  cram="$(docker exec "$NAME" awk -v n="$a" '$1 == n { print $2 }' /tmp/CRAM_Keys)"
  onboarded=false
  for attempt in 1 2 3; do
    if docker exec "$NAME" at_activate onboard -a "@$a" -c "$cram" -r "$DOMAIN:$BASE" > /dev/null 2>&1; then
      onboarded=true
      break
    fi
    echo "Onboarding @$a failed (attempt $attempt), retrying..."
    sleep 2
  done
  if [[ "$onboarded" != true ]]; then
    echo "ERROR: could not onboard @$a" >&2
    exit 1
  fi
  docker cp "$NAME:/root/.atsign/keys/@${a}_key.atKeys" "$KEYS_DIR/@${a}_key.atKeys" > /dev/null
  chmod 600 "$KEYS_DIR/@${a}_key.atKeys"
  echo "Onboarded @$a"
done

echo "ROOT_DOMAIN=$DOMAIN:$BASE"
