#!/bin/sh
# disable "var is referenced but not assigned" warning for template
# shellcheck disable=SC2154

# Configuration of sshnpd service
# This script is a template for the sshnpd background service.
# You can configure the service by editing the variables below.
# This service file covers the common configuration options for sshnpd.
# To see all available options, run `sshnpd` with no arguments.

manager_atsign="@example_client" # MANDATORY: Manager/client address (atSign)
device_atsign="@example_device"  # MANDATORY: Device address (atSign)
device_name="default"            # Device name
user="$(whoami)"                 # MANDATORY: Username
# s="-s" # Uncomment if you wish the daemon to update authorized_keys to include public keys sent by authorized manager atSigns
# u="-u" # Uncomment if you wish to have the daemon make various information visible to the manager atsign - e.g. username, version, etc - without the manager atSign needing to know this daemon's device name
v="-v" # Uncomment to enable verbose logging

sleep 10 # allow machine to bring up network
export USER="$user"
while true; do
	# The line below runs the sshnpd service, with the options set above.
	# You can edit this line to further customize the service to your needs.
	"$HOME"/.local/bin/sshnpd -a "$device_atsign" -m "$manager_atsign" -d "$device_name" "$s" "$u" "$v"
	sleep 10
done
