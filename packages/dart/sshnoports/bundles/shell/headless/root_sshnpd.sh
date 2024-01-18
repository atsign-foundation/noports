#!/bin/sh
# disable "var is referenced but not assigned" warning for template
# shellcheck disable=SC2154

# Uncomment the following lines to specify your own values, or modify them inline below
# device_atsign="@example_device"
# manager_atsign="@example_client"
# device_name="default"

sleep 10; # allow machine to bring up network
export USER="$user"
while true; do
  /usr/local/bin/sshnpd -a "$device_atsign" -m "$manager_atsign" -d "$device_name" -v
  sleep 10
done
