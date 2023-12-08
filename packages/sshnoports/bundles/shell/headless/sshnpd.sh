#!/bin/sh
# disable "var is referenced but not assigned" warning for template
# shellcheck disable=SC2154

sleep 10; # allow machine to bring up network
export USER="$user"
while true; do
  "$HOME"/.local/bin/sshnpd -a "$device_atsign" -m "$manager_atsign" -d "$device_name" -v
  sleep 10
done
