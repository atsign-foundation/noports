#!/bin/sh
# disable "var is referenced but not assigned" warning for template
# shellcheck disable=SC2154
# SCRIPT METADATA
binary_path="$HOME/.local/bin"
atsign="@my_rvd"    # MANDATORY: Srvd atSign
internet_address="" # MANDATORY: Public FQDN or IP address of the machine running the srvd
v="-v"              # Comment to disable verbose logging
# END METADATA

sleep 10 # allow machine to bring up network
export USER="$user"
while true; do
	"$binary_path"/srvd -a "$atsign" -i "$internet_address" "$v"
	sleep 10
done
