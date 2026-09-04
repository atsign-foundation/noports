#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONTAINER_NAME="${1:-ve_npe2e}"
VE_IMAGE="atsigncompany/virtualenv:vip"
SECONDARY_READY_TIMEOUT=600
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

# pkamLoad never exits: its script is 'sleep 25; install_PKAM_Keys; sleep
# infinity', so RUNNING is its only healthy steady state and there is nothing
# to wait for here. Key-load completion is verified per-atSign below via the
# public 'pkaminstalled' marker that install_PKAM_Keys writes as it finishes
# each atSign.
status=$(docker exec "$CONTAINER_NAME" supervisorctl status pkamLoad 2>/dev/null | awk '{print $2}' || true)
if [ "$status" = "FATAL" ] || [ "$status" = "BACKOFF" ]; then
  echo "ERROR: pkamLoad is in $status state"
  docker exec "$CONTAINER_NAME" supervisorctl tail pkamLoad 2>/dev/null || true
  exit 1
fi
echo "pkamLoad status: ${status:-unknown} (loads keys in the background; completion is checked per-atSign below)"

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

# Gate on every atSign the tests use being fully ready: the root server
# resolves it, its atServer accepts TLS, and install_PKAM_Keys has landed its
# keys (it writes 'public:pkaminstalled<atsign> yes' per atSign as it
# completes). The VE provisions ~40 atSigns; we only wait for ours.
# This is what eliminates "secondary server is not running" flakes at test start.
secondary_ready() {
  local atsign="$1" hostport="$2" resp
  # Response arrives glued to the '@' prompt, e.g. '@data:yes'.
  resp=$({ printf 'lookup:pkaminstalled@%s\n' "$atsign"; sleep 2; } |
    timeout 6 openssl s_client -connect "$hostport" -quiet -no_ign_eof 2>/dev/null || true)
  [[ "$resp" == *"data:yes"* ]]
}

lookup_secondary() {
  # Root protocol: send the atSign name (no @), response is '@host:port' or 'null'.
  # The '|| true' guards against pipefail tripping on openssl's SIGPIPE when
  # head closes the pipe after the first line.
  { echo "$1" | timeout 5 openssl s_client -connect "$ROOT_HOST:$ROOT_PORT" -quiet 2>/dev/null || true; } |
    head -1 | tr -d '@[:space:]'
}

echo ""
echo "Waiting for the ${#VE_ATSIGNS[@]} test atSigns to be ready (resolvable + PKAM keys installed, timeout ${SECONDARY_READY_TIMEOUT}s)..."
deadline=$((SECONDS + SECONDARY_READY_TIMEOUT))
last_note=$SECONDS
for atsign in "${VE_ATSIGNS[@]}"; do
  while true; do
    addr=$(lookup_secondary "$atsign")
    if [[ "$addr" == *:* ]] && secondary_ready "$atsign" "$addr"; then
      echo "  @${atsign}: ready at $addr (pkam keys installed)"
      break
    fi
    if ((SECONDS - last_note >= 20)); then
      echo "  still waiting for @${atsign}... (root lookup: '${addr:-<none>}')"
      last_note=$SECONDS
    fi
    if ((SECONDS >= deadline)); then
      echo "ERROR: @${atsign} not ready within ${SECONDARY_READY_TIMEOUT}s (last root lookup: '${addr:-<none>}')"
      echo "--- pkamLoad output tail ---"
      docker exec "$CONTAINER_NAME" supervisorctl tail pkamLoad 2>/dev/null || true
      echo "--- supervisorctl status ---"
      docker exec "$CONTAINER_NAME" supervisorctl status || true
      exit 1
    fi
    sleep 2
  done
done
echo "All ${#VE_ATSIGNS[@]} test atSigns are ready."

echo ""
echo "=== VE Setup Complete ==="
echo "Root domain: vip.ve.atsign.zone"
echo "Container:   $CONTAINER_NAME"
echo "atKeys:      $ATKEYS_DIR"
