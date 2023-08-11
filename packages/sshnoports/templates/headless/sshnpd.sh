#!/bin/bash
#v1.0.0
# allow machine to bring up network
sleep 10
USER=$(whoami)
export USER
DEVICE="$1"
CLIENT="$2"
NAME="$3"
while true; do
  # -a = device atSign
  # -m = client atSign
  # -d = device name
  "$HOME"/.local/bin/sshnpd -a "$DEVICE" -m "$CLIENT"  -u  -d "$NAME" -v -s "$@"
  sleep 10
done