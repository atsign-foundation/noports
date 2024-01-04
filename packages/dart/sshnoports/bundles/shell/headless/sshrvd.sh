#!/bin/sh
# disable "var is referenced but not assigned" warning for template
# shellcheck disable=SC2154

sleep 10; # allow machine to bring up network
export USER="$user"
while true; do
  "$HOME"/.local/bin/sshrvd -a "$atsign" -i "$internet_address"
  sleep 10
done
