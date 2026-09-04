#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONTAINER_NAME="${1:-ve_npe2e}"
VE_IMAGE="atsigncompany/virtualenv:vip"
PKAM_LOAD_TIMEOUT=300
SECONDARY_READY_TIMEOUT=300
ROOT_HOST="vip.ve.atsign.zone"
ROOT_PORT=64

ATKEYS_DIR="$HOME/.atsign/keys"

VE_ATSIGNS=(
  colin barbara chris curtly denise don gareth gary jeremy xavier
  relay1 relay2 policy2 cloudvm1
)

usage() {
  echo "Usage: $0 [container_name]"
  echo ""
  echo "Starts an atPlatform virtual environment and downloads demo atKeys."
  echo "  container_name  Docker container name (default: ve_npe2e)"
  echo ""
  echo "Prerequisites: 127.0.0.1 vip.ve.atsign.zone in /etc/hosts"
  exit 1
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
fi

if ! grep -q 'vip.ve.atsign.zone' /etc/hosts 2>/dev/null; then
  echo "ERROR: /etc/hosts must contain: 127.0.0.1 vip.ve.atsign.zone"
  echo "Run: echo '127.0.0.1 vip.ve.atsign.zone' | sudo tee -a /etc/hosts"
  exit 1
fi

echo "=== VE Setup: $CONTAINER_NAME ==="

if docker ps --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
  echo "VE container '$CONTAINER_NAME' is already running."
else
  docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
  echo "Starting VE container '$CONTAINER_NAME'..."
  docker run -d \
    --name "$CONTAINER_NAME" \
    -p 64:64 \
    -p 25000-25039:25000-25039 \
    --add-host "vip.ve.atsign.zone:127.0.0.1" \
    "$VE_IMAGE"
  echo "VE container started."
fi

# Note: 'supervisorctl status' exits 3 if any program is not RUNNING, so use
# 'supervisorctl pid' (exit 0 as soon as supervisord answers) for readiness.
echo "Waiting for supervisor to be ready..."
for i in $(seq 1 30); do
  if docker exec "$CONTAINER_NAME" supervisorctl pid >/dev/null 2>&1; then
    echo "Supervisor ready after ${i}s"
    break
  fi
  sleep 1
done

echo "Starting pkamLoad..."
docker exec "$CONTAINER_NAME" supervisorctl start pkamLoad 2>/dev/null || true

echo "Waiting for pkamLoad to complete..."

# RUNNING means pkamLoad is still loading keys — only EXITED means done.
elapsed=0
pkam_done=false
while [ "$elapsed" -lt "$PKAM_LOAD_TIMEOUT" ]; do
  status=$(docker exec "$CONTAINER_NAME" supervisorctl status pkamLoad 2>/dev/null | awk '{print $2}' || true)
  if [ "$status" = "EXITED" ]; then
    echo "pkamLoad completed after ${elapsed}s"
    pkam_done=true
    break
  fi
  if [ "$status" = "FATAL" ]; then
    echo "ERROR: pkamLoad entered FATAL state"
    docker exec "$CONTAINER_NAME" supervisorctl status || true
    exit 1
  fi
  if ((elapsed % 20 == 0)); then
    echo "  pkamLoad status: ${status:-unknown} (${elapsed}s / ${PKAM_LOAD_TIMEOUT}s)"
  fi
  sleep 2
  elapsed=$((elapsed + 2))
done
if [ "$pkam_done" != "true" ]; then
  echo "ERROR: pkamLoad did not complete within ${PKAM_LOAD_TIMEOUT}s (last status: ${status:-unknown})"
  docker exec "$CONTAINER_NAME" supervisorctl status || true
  echo "--- pkamLoad output tail ---"
  docker exec "$CONTAINER_NAME" supervisorctl tail pkamLoad 2>/dev/null || true
  exit 1
fi

mkdir -p "$ATKEYS_DIR"
echo "Downloading VE atKeys to $ATKEYS_DIR..."
for atsign in "${VE_ATSIGNS[@]}"; do
  dest="$ATKEYS_DIR/@${atsign}_key.atKeys"
  if [ -f "$dest" ]; then
    echo "  @${atsign}: already exists, skipping"
    continue
  fi
  url="https://raw.githubusercontent.com/atsign-foundation/at_demos/trunk/packages/at_demo_data/lib/assets/atkeys/%40${atsign}.atKeys"
  if curl -sSfL -o "$dest" "$url" 2>/dev/null; then
    echo "  @${atsign}: downloaded"
  else
    echo "  @${atsign}: FAILED to download from $url"
  fi
done

# Gate on every secondary being reachable the same way at_auth checks them:
# ask the root server for the secondary's address, then probe the TCP port.
# This is what eliminates "secondary server is not running" flakes at test start.
probe_tcp() {
  local host="$1" port="$2"
  if command -v nc >/dev/null 2>&1; then
    nc -z -w 3 "$host" "$port" >/dev/null 2>&1
  else
    timeout 3 bash -c "exec 3<>/dev/tcp/$host/$port" 2>/dev/null
  fi
}

lookup_secondary() {
  # Root protocol: send the atSign name (no @), response is '@host:port' or 'null'.
  # The '|| true' guards against pipefail tripping on openssl's SIGPIPE when
  # head closes the pipe after the first line.
  { echo "$1" | timeout 5 openssl s_client -connect "$ROOT_HOST:$ROOT_PORT" -quiet 2>/dev/null || true; } |
    head -1 | tr -d '@[:space:]'
}

echo ""
echo "Waiting for all ${#VE_ATSIGNS[@]} secondaries to be reachable (timeout ${SECONDARY_READY_TIMEOUT}s)..."
deadline=$((SECONDS + SECONDARY_READY_TIMEOUT))
last_note=$SECONDS
for atsign in "${VE_ATSIGNS[@]}"; do
  while true; do
    addr=$(lookup_secondary "$atsign")
    if [[ "$addr" == *:* ]] && probe_tcp "${addr%:*}" "${addr##*:}"; then
      echo "  @${atsign}: ready at $addr"
      break
    fi
    if ((SECONDS - last_note >= 20)); then
      echo "  still waiting for @${atsign}... (last root response: '${addr:-<none>}')"
      last_note=$SECONDS
    fi
    if ((SECONDS >= deadline)); then
      echo "ERROR: @${atsign} secondary not reachable within ${SECONDARY_READY_TIMEOUT}s (last root response: '${addr:-<none>}')"
      echo "supervisorctl status:"
      docker exec "$CONTAINER_NAME" supervisorctl status || true
      exit 1
    fi
    sleep 2
  done
done
echo "All ${#VE_ATSIGNS[@]} secondaries are reachable."

echo ""
echo "=== VE Setup Complete ==="
echo "Root domain: vip.ve.atsign.zone"
echo "Container:   $CONTAINER_NAME"
echo "atKeys:      $ATKEYS_DIR"
