#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONTAINER_NAME="${1:-ve_npe2e}"
VE_IMAGE="atsigncompany/virtualenv:vip"
PKAM_LOAD_TIMEOUT=120

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

echo "Waiting for supervisor to be ready..."
for i in $(seq 1 30); do
  if docker exec "$CONTAINER_NAME" supervisorctl status >/dev/null 2>&1; then
    echo "Supervisor ready after ${i}s"
    break
  fi
  sleep 1
done

echo "Starting pkamLoad..."
docker exec "$CONTAINER_NAME" supervisorctl start pkamLoad 2>/dev/null || true

echo "Waiting for pkamLoad to complete..."

elapsed=0
while [ "$elapsed" -lt "$PKAM_LOAD_TIMEOUT" ]; do
  status=$(docker exec "$CONTAINER_NAME" supervisorctl status pkamLoad 2>/dev/null | awk '{print $2}')
  if [ "$status" = "EXITED" ] || [ "$status" = "RUNNING" ]; then
    echo "pkamLoad status: $status (${elapsed}s)"
    break
  fi
  sleep 2
  elapsed=$((elapsed + 2))
done
if [ "$elapsed" -ge "$PKAM_LOAD_TIMEOUT" ]; then
  echo "WARNING: pkamLoad did not complete within ${PKAM_LOAD_TIMEOUT}s"
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

echo ""
echo "=== VE Setup Complete ==="
echo "Root domain: vip.ve.atsign.zone"
echo "Container:   $CONTAINER_NAME"
echo "atKeys:      $ATKEYS_DIR"
