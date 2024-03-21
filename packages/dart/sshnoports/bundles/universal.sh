#!/bin/sh

# SCRIPT METADATA
# DO NOT MODIFY/DELETE THIS BLOCK
script_version="3.0.0"
sshnp_version="5.1.0"
repo_url="https://github.com/atsign-foundation/sshnoports"
# END METADATA

# N.B. Other than the variable definitions, and the call to the main function,
# nothing else should be writen outside the main function to avoid side effects

### Environment based variables
arg_zero="$0"
unset script_dir
unset platform_name
unset system_arch
unset archive_ext
unset time_stamp
unset archive_path
unset as_root
unset bin_path
unset user

### Input Variables
verbose=false
unset tmp_path
install_type=""
unset download_url
local_archive=""

### Client/ Device Install Variables
client_atsign=""
device_atsign=""

### Client Install Variables
unset magic_script
unset host_atsign
unset devices

### Device Install Variables
device_name=""

norm_atsign() {
	# Prepend an @ to the front of the atsign if missing
	atsign="@$(echo "$1" | sed -e 's/"//g' -e 's/^@//g')"
	echo "$atsign"
}

norm_version() {
	# Ensure the version is in the format "tags/vX.Y.Z" (github version tag)
	version="tags/v$(echo "$1" | sed -e 's/"//g' -e 's/^tags\///g' -e 's/^v//g')"
	echo "$version"
}

is_root() {
	[ "$(id -u)" -eq 0 ]
}

is_darwin() {
	[ "$(uname)" = 'Darwin' ]
}

sedi() {
	if is_darwin; then
		sed -i '' "$@"
	else
		sed -i "$@"
	fi
}

version() {
	echo "Version: $script_version (Target: $sshnp_version)"
}

usage() {
	if [ -z "$arg_zero" ]; then
		arg_zero='install.sh'
	fi
	version
	echo "Usage: $arg_zero [options]"
	echo "  -h, --help              Display help"
	echo "  -v, --verbose           Verbose tracing"
	echo "      --version           Display version"
	echo "      --temp-path <path>  Set the temporary path for downloads"
	echo "  -t, --type      <type>  Set the install type (device, client, both)"
	echo "      --local     <path>  Install from a local archive"
}

parse_env() {
	case "$(uname)" in
	Darwin) platform_name='macos' ;;
	Linux) platform_name='linux' ;;
	*)
		echo "Detected an unsupported platform: $(uname)"
		echo "Please open an issue at: $repo_url"
		echo "and provide the following information: $(uname -a)" exit 1
		;;
	esac

	case "$platform_name" in
	macos) archive_ext="zip" ;;
	linux) archive_ext="tgz" ;;
	esac

	case "$(uname -m)" in
	x86_64 | amd64 | x64)
		system_arch="x64"
		;;
	arm64 | aarch64)
		system_arch="arm64"
		;;
	arm | armv7l)
		system_arch="armv7"
		;;
	riscv64)
		system_arch="riscv64"
		;;
	*)
		echo "Detected an unsupported architecture: $(uname -m)"
		echo "Please open an issue at: $repo_url"
		echo "and provide the following information: $(uname -a)"
		exit 1
		;;
	esac

	time_stamp=$(date +%s)

	tmp_path="/tmp"
	extract_path="$tmp_path/sshnp-$time_stamp"
	archive_path="$extract_path.$archive_ext"

	if is_root; then
		as_root=true
		bin_path="/usr/local/bin"
		user=$(logname)
	else
		as_root=false
		bin_path="$HOME/.local/bin"
		user="$USER"
	fi
}

is_valid_source_mode() {
	[ "$1" = "download" ] || [ "$1" = "local" ] || [ "$1" = "build" ]
}

is_valid_install_type() {
	[ "$1" = "device" ] || [ "$1" = "client" ] || [ "$1" = "both" ]
}

norm_install_type() {
	case "$1" in
	d*)
		echo "device"
		;;
	c*)
		echo "client"
		;;
	*)
		echo ""
		;;
	esac
}

parse_args() {
	while [ $# -gt 0 ]; do
		case "$1" in
		-h | --help)
			usage
			exit 0
			;;
		-v | --verbose)
			verbose=true
			set -x
			;;
		--version)
			version
			exit 0
			;;
		--temp-path)
			shift
			mkdir -p "$1"
			tmp_path="$1"
			;;
		-t | --type)
			shift
			if is_valid_install_type "$1"; then
				install_type="$1"
			else
				echo "Invalid install type: $1"
				echo "Valid options are: device, client" exit 1
			fi
			;;
		--local)
			shift
			if [ -f "$1" ]; then
				local_archive="$1"
			else
				echo "Local archive not found: $1"
				exit 1
			fi
			;;
		*)
			echo "Unexpected option: $1"
			exit 1
			;;
		esac
		shift
	done
}

get_user_inputs() {
	if [ -z "$install_type" ]; then
		unset install_type_input
		while [ -z "$install_type" ]; do
			echo "Install type (device, client, both): " 1>&2
			read -r install_type_input
			install_type=$(norm_install_type "$install_type_input")
		done
	fi
}

print_env() {
	echo "Environment:"
	echo "Platform Name: $platform_name"
	echo "System Arch: $system_arch"
	echo "Temporary Path: $tmp_path"
	echo "As Root: $as_root"
	echo "Binary Path: $bin_path"
	echo "User: $user"
}

get_download_url() {
	unset download_urls
	download_urls=$(
		curl -fsSL "https://api.github.com/repos/atsign-foundation/noports/releases/$(norm_version $sshnp_version)" |
			grep browser_download_url |
			cut -d\" -f4
	)

	if [ -z "$download_urls" ]; then
		echo "Failed to get download url for sshnoports"
		exit 1
	fi

	echo "$download_urls" |
		grep "$platform_name" | grep "$system_arch" |
		cut -d\" -f4
}

download_archive() {
	read -r download_url
	echo "Downloading archive from $download_url"
	curl -sL "$download_url" -o "$archive_path"
	if [ ! -f "$archive_path" ]; then
		echo "Failed to download archive"
		exit 1
	fi
}

unpack_archive() {
	case "$archive_ext" in
	zip)
		unzip -qo "$archive_path" -d "$extract_path"
		;;
	tgz | tar.gz)
		tar -zxf "$archive_path" -C "$extract_path"
		;;
	esac
}

cleanup() {
	# These should be in the tmp directory, attempt to remove them anyway
	rm -f "$archive_path"
	rm -rf "$extract_path"
}

write_metadata() {
	start_line="# SCRIPT METADATA"
	end_line="# END METADATA"
	file=$1
	variable=$2
	value=$3
	sedi "/$start_line/,/$end_line/s|$variable=\".*\"|$variable=\"$value\"|g " "$file"
}

write_metadata_array() {
	# Takes a comma separated list and writes it into a bash array in the metadata of the script
	start_line="# SCRIPT METADATA"
	end_line="# END METADATA"
	file=$1
	variable=$2
	value=$(echo "$3" | tr ',' ' ')
	sedi "/$start_line/,/$end_line/s|$variable=(.*)|$variable=($value)|g" "$file"
}

write_program_arguments_plist() {
	# Takes a comma separated list and writes it into a string array in the plist document
	start_line="<key>ProgramArguments</key>"
	second_line="<array>"
	end_line="</array>"
	file=$1
	shift
	string_array=""
	while [ $# -gt 0 ]; do
		string_array="$string_array\\
    <string>$1</string>"
		shift
	done
	sedi "/<key>ProgramArguments<\\/key>/,/<\\/array>/c\\
  $start_line\\
  $second_line$string_array\\
  $end_line" "$file"
}

write_systemd_environment() {
	file=$1
	variable=$2
	value=$3
	sedi "s|Environment=$variable=\".*\"|Environment=$variable=\"$value\"|g" "$file"
}

get_client_device_atsigns() {
	while [ -z "$client_atsign" ]; do
		echo "Enter client atSign:"
		read -r client_atsign
	done

	while [ -z "$device_atsign" ]; do
		echo "Enter device atSign:"
		read -r device_atsign
	done
}

# CLIENT INSTALLATION #
client() {
	magic_script="$bin_path"/@sshnp
	# install the magic sshnp script
	cp "$extract_path"/sshnp/magic/sshnp.sh "$magic_script"
	chmod +x "$magic_script"

	get_client_device_atsigns
	if [ -z "$host_atsign" ]; then
		echo Pick your default region:
		echo "  am   : Americas"
		echo "  ap   : Asia Pacific"
		echo "  eu   : Europe"
		echo "  @___ : Specify a custom region atSign"
		echo "> "
		read -r host_atsign
	fi

	while ! echo "$host_atsign" | grep -Eq "@.*"; do
		case "$host_atsign" in
		[Aa][Mm]*)
			host_atsign="@rv_am"
			;;
		[Ee][Uu]*)
			host_atsign="@rv_eu"
			;;
		[Aa][Pp]*)
			host_atsign="@rv_ap"
			;;
		@*)
			# Do nothing for custom region
			;;
		*)
			echo "Invalid region: $host_atsign"
			echo "region: "
			read -r host_atsign
			;;
		esac
	done

	done_input=false

	echo "Enter the device names you would like to include in the magic script"
	echo "/done to finish"
	while [ "$done_input" = false ]; do
		echo "device: "
		read -r device_name
		if [ "$device_name" = "/done" ]; then
			done_input=true
		else
			devices="$devices,$device_name"
		fi
	done

	write_metadata "$magic_script" "client_atsign" "$(norm_atsign "$client_atsign")"
	write_metadata "$magic_script" "device_atsign" "$(norm_atsign "$device_atsign")"
	write_metadata "$magic_script" "host_atsign" "$(norm_atsign "$host_atsign")"
	write_metadata_array "$magic_script" "devices" "$devices"
}

# DEVICE INSTALLATION #
device() {
	unset device_install_type
	if is_darwin; then
		device_install_type="launchd"
	elif is_root; then
		device_install_type="systemd"
	elif command -v tmux >/dev/null 2>&1; then
		device_install_type="tmux"
	else
		device_install_type="headless"
	fi

	get_client_device_atsigns

	while [ -z "$device_name" ]; do
		echo "Enter device name:"
		read -r device_name
	done

	install_output=$("$extract_path"/sshnp/install.sh -b "$bin_path" -u "$user" "$device_install_type" sshnpd)
	case "$device_install_type" in
	launchd)
		launchd_plist="$HOME/Library/LaunchAgents/com.atsign.sshnpd.plist"
		write_program_arguments_plist "$launchd_plist" "$bin_path/sshnpd" "-f" "$(norm_atsign "$client_atsign")" "-t" "$(norm_atsign "$device_atsign")" "-d" "$device_name" "-su"
		launchctl load "$launchd_plist"
		launchctl start "$launchd_plist"
		;;
	systemd)
		systemd_service="/etc/systemd/system/sshnpd.service"
		write_systemd_environment "$systemd_service" "manager_atsign" "$(norm_atsign "$client_atsign")"
		write_systemd_environment "$systemd_service" "device_atsign" "$(norm_atsign "$device_atsign")"
		write_systemd_environment "$systemd_service" "device_name" "$device_name"
		systemctl enable sshnpd
		systemctl start sshnpd
		;;
	tmux | headless)
		shell_script="$bin_path"/sshnpd.sh
		metadata_write "$shell_script" "manager_atsign" "$(norm_atsign "$client_atsign")"
		metadata_write "$shell_script" "device_atsign" "$(norm_atsign "$device_atsign")"
		metadata_write "$shell_script" "device_name" "$device_name"
		# split install output by lines, then grab the output after the line that says "To start immediately"
		eval "$(echo "$install_output" | grep -A1 "To start .* immediately:" | tail -n1)"
		;;
	esac
}

main() {
	trap cleanup EXIT
	set -eu
	parse_env
	parse_args "$@"

	if [ $verbose = true ]; then print_env; fi

	if [ -n "$local_archive" ]; then
		echo "Using local archive: $local_archive"
		cp "$local_archive" "$archive_path"
	else
		download_url=$(get_download_url)
		echo "Downloading archive from $download_url"
		echo "$download_url" | download_archive
	fi

	unpack_archive

	get_user_inputs
	case "$install_type" in
	client) client ;;
	device) device ;;
	esac
}

main "$@"
