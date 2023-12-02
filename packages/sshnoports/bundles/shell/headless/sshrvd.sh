#!/bin/sh
sleep 10; # allow machine to bring up network
while true; do
  # disable "var is referenced but not assigned" warning for template
  # shellcheck disable=SC2154
  "$HOME"/.local/bin/sshrvd -a "$atsign" -i "$internet_address"
  sleep 10
done
