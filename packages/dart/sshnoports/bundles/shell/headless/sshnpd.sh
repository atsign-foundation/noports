#!/bin/sh
# disable "var is referenced but not assigned" warning for template
# shellcheck disable=SC2154
# SCRIPT METADATA
binary_path="$HOME/.local/bin"
manager_atsign="@example_client" # MANDATORY: Manager/client address/Comma separated addresses (atSign/s)
device_atsign="@example_device"  # MANDATORY: Device address (atSign)
device_name="default"            # Device name
user="$(whoami)"                 # MANDATORY: Username
v="-v"                           # Comment to disable verbose logging
s="-s"                           # Comment to disable sending public keys
u="-u"                           # Comment to disable sending user information
delegate_policy=""
# END METADATA

sleep 10 # allow machine to bring up network
export USER="$user"
while true; do
	# The line below runs the sshnpd service, with the options set above.
	# You can edit this line to further customize the service to your needs.
	"$binary_path"/sshnpd -a "$device_atsign" -m "$manager_atsign" -d "$device_name" $delegate_policy "$s" "$u" "$v"
	sleep 10
done
