#!/bin/bash
SRVD_DIR="/tmp/ve_srvd"
if [ -f "$SRVD_DIR/srvd.pid" ]; then
  kill "$(cat "$SRVD_DIR/srvd.pid")" 2>/dev/null || true
  echo "srvd stopped"
fi
