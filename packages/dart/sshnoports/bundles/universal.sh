#!/bin/sh

# SCRIPT METADATA
# DO NOT MODIFY/DELETE THIS BLOCK
script_version="3.0.0"
sshnp_version="5.1.0-rc.10"
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
unset user_home
unset user_bin_dir

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
host_atsign=""
devices=""

### Device Install Variables
device_name=""
device_type=""

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

is_systemd_available() {
    # https://superuser.com/questions/1017959/how-to-know-if-i-am-using-systemd-on-linux
    [ -d /run/systemd/system ]
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
    echo "  -h, --help                     Display help"
    echo "  -v, --verbose                  Verbose tracing"
    echo "      --version                  Display version"
    echo "      --temp-path      <path>    Set the temporary path for downloads"
    echo "  -t, --type           <type>    Set the install type (device, client, both)"
    echo "      --local          <path>    Install from a local archive"
    echo
    echo "Client Options:"
    echo "  -c, --client-atsign  <atsign>  Set the client atSign"
    echo "  -d, --device-atsign  <atsign>  Set the device atSign"
    echo "  -r, --region         <region>  Set the default rendezvous region (am, eu, ap)"
    echo "      --rv-atsign      <atsign>  Set the default rendezvous atsign"
    echo "  -l, --device-list    <names>   Set the device names for the quick picker script (comma separated)"
    echo
    echo "Note: only one of --region or --rv-atsign can be used"
    echo
    echo "Device Options:"
    echo "  -c, --client-atsign  <atsign>  Set the client atSign"
    echo "  -d, --device-atsign  <atsign>  Set the device atSign"
    echo "  -n, --device-name    <name>    Set the device name"
    echo "  --dt, --device-type  <type>    Set the device type (launchd, systemd, tmux, headless)"

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
    user_home="$HOME"
    if is_root; then
        user="$SUDO_USER"
        as_root=true
        bin_path="/usr/local/bin"
        if [ -z "$user" ]; then
            user="root"
        else
            # we are root, but via sudo
            # so get home directory of SUDO_USER
            user_home=$(sudo -u "$user" sh -c 'echo $HOME')
        fi
    else
        as_root=false
        bin_path="$HOME/.local/bin"
        user="$USER"
    fi
    user_bin_dir=$user_home/.local/bin/@sshnp
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
    b*)
        echo "both"
        ;;
    *)
        echo ""
        ;;
    esac
}

is_valid_device_type() {
    [ "$1" = "launchd" ] || [ "$1" = "systemd" ] || [ "$1" = "tmux" ] || [ "$1" = "headless" ]
}

norm_device_type() {
    case "$1" in
    l*)
        echo "launchd"
        ;;
    s*)
        echo "systemd"
        ;;
    t*)
        echo "tmux"
        ;;
    h*)
        echo "headless"
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
            install_type_input="$1"
            install_type=$(norm_install_type "$install_type_input")
            if ! is_valid_install_type "$install_type"; then
                echo "Invalid install type: $install_type_input"
                echo "Valid options are: (device, client, both)" exit 1
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
        -c | --client-atsign)
            shift
            client_atsign="$1"
            ;;
        -d | --device-atsign)
            shift
            device_atsign="$1"
            ;;
        -r | --region)
            # notice that --region and --rv-atsign are basically the same under the hood,
            # if region's input starts with an "@" it will be equivalent to using --rv-atsign
            # without an "@", it will try to map to one of the @rv_XX regions
            shift
            host_atsign="$1"
            ;;
        --rv-atsign)
            shift
            host_atsign="$(norm_atsign "$1")"
            ;;
        -l | --device-list)
            shift
            devices="$1"
            ;;
        -n | --device-name)
            shift
            device_name="$1"
            ;;
        --dt | --device-type)
            shift
            device_type_input="$1"
            device_type=$(norm_device_type "$device_type_input")
            if ! is_valid_device_type "$device_type"; then
                echo "Invalid device type: $device_type_input"
                echo "Valid options are: (launchd, systemd, tmux, headless)" exit 1
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
            printf "Install type (device, client, both):  "
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
        mkdir -p "$extract_path"
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
    sedi "s|$end_line|\\
    $end_line\\
    |g" "$file" # make sure </array> is on a new line or we might delete something we shouldn't
    sedi "/<key>ProgramArguments<\\/key>/,/<\\/array>/c\\
  $start_line\\
  $second_line$string_array\\
  $end_line\\
  " "$file"
    sedi '/^[[:space:]]*$/d' "$file" # remove empty lines to keep things clean
}

write_systemd_user() {
    file=$1
    user=$2
    sedi "s|<username>|$user|g" "$file"
}

write_systemd_environment() {
    file=$1
    variable=$2
    value=$3
    sedi "s|Environment=$variable=\".*\"|Environment=$variable=\"$value\"|g" "$file"
}

get_device_atsign() {
    while [ -z "$device_atsign" ]; do
        printf "Enter device atSign: "
        read -r device_atsign
    done
}

get_client_device_atsigns() {
    while [ -z "$client_atsign" ]; do
        printf "Enter client atSign: "
        read -r client_atsign
    done

    while [ -z "$device_atsign" ]; do
        if [ -d "${user_home}/.atsign/keys" ]; then
            atkeys=( $(ls -1 ${user_home}/.atsign/keys | sed s/@// | sed s/_key.atKeys//) )
            if [ ${#atkeys[@]} -eq 0 ]; then
                echo "~/.atsign/keys directory found but there are no keys there yet"
                echo "Which atSign do you plan to use?"
                get_device_atsign
            else
                echo "${#atkeys[@]} atKeys found: ${atkeys[@]}"
                for atkey in "${atkeys[@]}"; do
                    printf "Would you like to use @${atkey} for this device? "
                    read -r use_atkey
                    case $use_atkey in
                    y*|Y*)
                        device_atsign=$atkey
                        break 2
                        ;;
                    esac
                done
                # If we get this far and an atsign hasn't been picked just ask
                get_device_atsign
            fi
        else
            mkdir -p ${user_home}/.atsign/keys
            echo "~/.atsign/keys directory created"
            echo "Which atSign do you plan to use?"
            get_device_atsign
        fi
    done

}

suggest_sudo() {
    echo
    echo "Systemd is present but this script is not running with sudo"
    echo "It is suggested that you exit and rerun:"
    echo
    echo "sudo sh universal.sh"
    echo
    echo "If you'd rather (P)roceed with a non systemd installation"
    echo "then enter p or P, otherwise this script will exit."
    printf "(P)roceed? "
    read -r proceed
    case $proceed in
    p|P)
        return
        ;;
    *)
        exit 0
        ;;
    esac
}

# CLIENT INSTALLATION #
client() {
    mkdir -p "$bin_path"

    # install the binaries
    "$extract_path"/sshnp/install.sh -b "$bin_path" -u "$user" sshnp
    "$extract_path"/sshnp/install.sh -b "$bin_path" -u "$user" npt

    # install the magic sshnp script
    magic_script="$bin_path"/@sshnp
    cp "$extract_path"/sshnp/magic/sshnp.sh "$magic_script"
    chmod +x "$magic_script"
    if is_root && [ -f "$bin_path"/@sshnp ]; then
        ln -sf "$bin_path"/@sshnp "$user_bin_dir"/@sshnp
        if [ $verbose = true ]; then
            echo "=> Linked $user_bin_dir/@sshnp to $bin_path/@sshnp"
        fi
    fi

    # get the inputs for the magic script
    get_client_device_atsigns
    if [ -z "$host_atsign" ]; then
        echo Pick your default region:
        echo "  am   : Americas"
        echo "  ap   : Asia Pacific"
        echo "  eu   : Europe"
        echo "  @___ : Specify a custom region atSign"
        printf "Region: "
        read -r host_atsign
    fi

    while ! echo "$host_atsign" | grep -Eq "@.*"; do
        case "$host_atsign" in
        [Aa][Mm]*)
            host_atsign="@rv_am"
            ;;
        [Ee]*)
            host_atsign="@rv_eu"
            ;;
        [Aa][Pp]*)
            host_atsign="@rv_ap"
            ;;
        @*)
            # Do nothing for custom region
            ;;
        *)
            printf "Invalid region: ${host_atsign}: "
            read -r host_atsign
            ;;
        esac
    done

    if [ -z "$devices" ]; then
        done_input=false
        echo "Installing a quick picker script to make it easy to connect to devices..."
        echo "Enter the device names you would like to include in the quick picker script"
        echo "/done to finish"
        while [ "$done_input" = false ]; do
            printf "Device name: "
            read -r device_name
            if [ "$device_name" = "/done" ]; then
                done_input=true
            else
                devices="$devices,$device_name"
            fi
        done
    fi

    # write the metadata to the magic script
    write_metadata "$magic_script" "client_atsign" "$(norm_atsign "$client_atsign")"
    write_metadata "$magic_script" "device_atsign" "$(norm_atsign "$device_atsign")"
    write_metadata "$magic_script" "host_atsign" "$(norm_atsign "$host_atsign")"
    write_metadata_array "$magic_script" "devices" "$devices"
}

# DEVICE INSTALLATION #
device() {
    unset device_install_type
    if [ -z "$device_type" ]; then
        if is_darwin; then
            device_install_type="launchd"
        elif is_root && is_systemd_available; then
            device_install_type="systemd"
        elif is_systemd_available; then
            suggest_sudo
        elif command -v tmux >/dev/null 2>&1; then
            device_install_type="tmux"
        else
            device_install_type="headless"
        fi
    else
        # override the device type if it is set
        device_install_type=$device_type
    fi

    get_client_device_atsigns

    while [ -z "$device_name" ]; do
        printf "Enter device name: "
        read -r device_name
    done

    # run the device install script and capture the output
    install_output=$("$extract_path"/sshnp/install.sh -b "$bin_path" -u "$user" "$device_install_type" sshnpd)

    if [ "$verbose" = true ]; then
        echo "$install_output"
    fi

    case "$device_install_type" in
    launchd)
        launchd_plist="$HOME/Library/LaunchAgents/com.atsign.sshnpd.plist"
        write_program_arguments_plist "$launchd_plist" "$bin_path/sshnpd" "-m" "$(norm_atsign "$client_atsign")" "-a" "$(norm_atsign "$device_atsign")" "-d" "$device_name" "-su"
        launchctl unload "$launchd_plist"
        launchctl load "$launchd_plist"
        echo "sshnpd installed with launchd"
        ;;
    systemd)
        systemd_service="/etc/systemd/system/sshnpd.service"
        write_systemd_user "$systemd_service" "$user"
        write_systemd_environment "$systemd_service" "manager_atsign" "$(norm_atsign "$client_atsign")"
        write_systemd_environment "$systemd_service" "device_atsign" "$(norm_atsign "$device_atsign")"
        write_systemd_environment "$systemd_service" "device_name" "$device_name"
        systemctl enable sshnpd
        systemctl start sshnpd
        echo "sshnpd installed with systemd. To see logs use:"
        echo "journalctl -u sshnpd.service -f"
        ;;
    tmux | headless)
        shell_script="$bin_path"/sshnpd.sh
        write_metadata "$shell_script" "manager_atsign" "$(norm_atsign "$client_atsign")"
        write_metadata "$shell_script" "device_atsign" "$(norm_atsign "$device_atsign")"
        write_metadata "$shell_script" "device_name" "$device_name"
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
        echo "$download_url" | download_archive
    fi

    unpack_archive

    get_user_inputs
    case "$install_type" in
    client) client ;;
    device) device ;;
    both)
        echo
        echo "Installing device part..."
        device
        echo
        echo "Installing client part..."
        client
        ;;
    esac
}

main "$@"
