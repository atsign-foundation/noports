#!/bin/bash
#v2.0.0
# allow machine to bring up network
sleep 10
USER=$(whoami) 
export USER
ATSIGN="$1"
ADDRESS="$2"
while true; do
  # -a = atSign
  # -i = FQDN/IP
  "$HOME"/.local/bin/sshrvd -a "$ATSIGN" -i "$ADDRESS"
  sleep 10
done