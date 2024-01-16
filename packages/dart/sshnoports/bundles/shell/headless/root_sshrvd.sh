#!/bin/sh
# disable "var is referenced but not assigned" warning for template
# shellcheck disable=SC2154

# Uncomment the following lines to specify your own values, or modify them inline below
# atsign="@my_rvd"
# internet_address="127.0.0.1"

sleep 10; # allow machine to bring up network
export USER="$user"
while true; do
  /usr/local/bin/sshrvd -a "$atsign" -i "$internet_address"
  sleep 10
done
