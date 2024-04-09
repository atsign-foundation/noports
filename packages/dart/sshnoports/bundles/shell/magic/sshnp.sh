#!/bin/bash
# SCRIPT METADATA
binary_path="$HOME/.local/bin"
client_atsign=""
device_atsign=""
host_atsign=""
devices=()
additional_args=()
# END METADATA

unset d
echo "Select a device (enter the number):"
select d in "${devices[@]}"; do
	break
done

if [ -z "$d" ]; then
	echo "No device selected"
	exit 1
fi

echo "Executing $binary_path"/sshnp -f "$client_atsign" -t "$device_atsign" -h "$host_atsign" -d "$d" "${additional_args[@]}" "$@"
"$binary_path"/sshnp -f "$client_atsign" -t "$device_atsign" -h "$host_atsign" -d "$d" "${additional_args[@]}" "$@"
