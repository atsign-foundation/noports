#!/bin/bash
# v2.0.0
# allow machine to bring up network
sleep 10
USER=$(whoami)
export USER
DEVICE="$1"
CLIENT="$2"
NAME="$3"
ARGS="$*"
while true; do
  # Ignore the shell check warning for the following line
  # We actually want array expansion here in order to parse the arguments correctly
  # shellcheck disable=SC2086
  "$HOME"/.local/bin/sshnpd -a "$DEVICE" -m "$CLIENT" -d "$NAME" $ARGS
  sleep 10
done
