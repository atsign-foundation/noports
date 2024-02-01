#!/bin/sh
# disable "var is referenced but not assigned" warning for template
# shellcheck disable=SC2154

# Configuration of srvd service
# This unit script is a template for the srvd background service.
# You can configure the service by editing the variables below.
# This service file covers the common configuration options for srvd.
# To see all available options, run `srvd` with no arguments.

atsign="@my_rvd"    # MANDATORY: Srvd atSign
internet_address="" # MANDATORY: Public FQDN or IP address of the machine running the srvd
v="-v"              # Comment to disable verbose logging

sleep 10 # allow machine to bring up network
export USER="$user"
while true; do
	"$HOME"/.local/bin/srvd -a "$atsign" -i "$internet_address" "$v"
	sleep 10
done
