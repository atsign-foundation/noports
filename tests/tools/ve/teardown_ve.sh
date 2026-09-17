#!/bin/bash
set -euo pipefail

CONTAINER_NAME="${1:-ve_npe2e}"

echo "=== VE Teardown: $CONTAINER_NAME ==="

if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
  docker rm -f "$CONTAINER_NAME"
  echo "Removed container '$CONTAINER_NAME'."
else
  echo "Container '$CONTAINER_NAME' does not exist."
fi
