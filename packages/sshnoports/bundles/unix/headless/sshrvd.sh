#!/bin/bash
# v2.0.0
# allow machine to bring up network
sleep 10
USER=$(whoami)
export USER
ATSIGN="$1"
IPADDRESS="$2"
while true; do
  "$HOME"/.local/bin/sshrvd -a "$ATSIGN" -i "$IPADDRESS"
  sleep 10
done
