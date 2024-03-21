#!/bin/bash
# SCRIPT METADATA
binary_path="$HOME/.local/bin"
client_atsign=""
device_atsign=""
host_atsign=""
devices=(device1 device2 device3)
additional_args=()
# END METADATA

unset d
select d in "${devices[@]}"; do
	break
done

if [ -z "$d" ]; then
	echo "No device selected"
	exit 1
fi

"$binary_path"/sshnp -f "$client_atsign" -t "$device_atsign" -h "$host_atsign" -d "$d" "${additional_args[@]}" "$@"
