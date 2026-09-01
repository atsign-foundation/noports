#!/bin/bash
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: $0 <relay_atsign> <root_domain>"
  exit 1
fi

RELAY_ATSIGN="$1"
ROOT_DOMAIN="$2"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$SCRIPT_DIR/../../../.."
SRVD_DIR="/tmp/ve_srvd"
mkdir -p "$SRVD_DIR"

KEYS="$HOME/.atsign/keys/@${RELAY_ATSIGN#@}_key.atKeys"
if [ ! -f "$KEYS" ]; then
  echo "ERROR: atKeys not found at $KEYS"
  exit 1
fi

cd "$REPO_ROOT"

if [ ! -f "$SRVD_DIR/srvd" ]; then
  echo "Compiling srvd..."
  cd packages/dart/sshnoports
  dart pub get
  dart compile exe bin/srvd.dart -o "$SRVD_DIR/srvd"
  cd "$REPO_ROOT"
fi

RELAY_IP="${ROOT_DOMAIN%%:*}"
LOG="$SRVD_DIR/srvd.log"

echo "Starting srvd for $RELAY_ATSIGN..."
"$SRVD_DIR/srvd" -a "$RELAY_ATSIGN" -k "$KEYS" --root-domain "$ROOT_DOMAIN" --ip "$RELAY_IP" -v >> "$LOG" 2>&1 &
SRVD_PID=$!
echo "$SRVD_PID" > "$SRVD_DIR/srvd.pid"

for i in $(seq 1 30); do
  if grep -q "monitor started" "$LOG" 2>/dev/null; then
    echo "srvd relay started (PID $SRVD_PID) after ${i}s"
    exit 0
  fi
  sleep 1
done

echo "ERROR: srvd did not start within 30s"
cat "$LOG"
kill "$SRVD_PID" 2>/dev/null || true
exit 1
