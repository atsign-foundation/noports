#!/bin/sh

# SCRIPT METADATA
# DO NOT MODIFY/DELETE THIS BLOCK
script_version="3.2.0"
sshnp_version="5.15.0"
repo_url="https://github.com/atsign-foundation/sshnoports"
# END METADATA

# N.B. Other than the variable definitions, and the call to the main function,
# nothing else should be writen outside the main function to avoid side effects
### Environment config

# GREP_COLOR not used directly so ignore the shellcheck warning for it
# shellcheck disable=SC2034
GREP_COLOR=never
unset GREP_OPTIONS

### Constants
systemd_config_path="/etc/systemd/system/sshnpd.service.d/override.conf"

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

### Pre-installation validation
unset ssh_localhost_status
unset is_dotlocal_created
unset is_dotlocalbin_created
unset is_dotssh_created
unset is_dotsshnp_created
unset is_dotatsign_created
unset is_dotatsignkeys_created
unset is_overrideconf_created

### Input Variables
verbose=false
unset tmp_path
install_type=""
unset download_url
local_archive=""
no_sudo=false
quiet=false
used_package_manager=false

### Client/ Device Install Variables
client_atsign=""
device_atsign=""
policy_atsign=""

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

check_quiet() {
  for arg in "$@"; do
    if [ "$arg" = "-q" ] || [ "$arg" = "--quiet" ]; then
      exec >/dev/null
      break
    fi
  done
}

check_cmd() {
  set +e
  command -v "$1" >/dev/null 2>&1
  exitcode=$?
  set -e
  return $exitcode
}

sedi() {
  if is_darwin; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

chown_dir() {
  if [ -d $1 ]; then
    echo "$1 was created by this installer, ensuring that it is owned by $user"
    chown -R $user:$user "$1" 2>/dev/null || chown -R $user "$1" 2>/dev/null
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
  echo "  -t, --type           <type>    Set the install type (device, client)"
  echo "      --local          <path>    Install from a local archive"
  echo "  -q, --quiet                    Disables any printing to the terminal from the script. Ensure you are including options."
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
  echo "  -c,   --client-atsign  <atsign>  Set the client atSign"
  echo "  -d,   --device-atsign  <atsign>  Set the device atSign"
  echo "  -p,   --policy-atsign  <atsign>  Set the access policy atSign"
  echo "  -n,   --device-name    <name>    Set the device name"
  echo "  --dt, --device-type    <type>    Set the device type (launchd, systemd, tmux, headless)"
  echo "        --no-sudo                  Deliberately install without sudo privileges"

}

check_ssh_localhost() {
  # ssh_localhost_status
  if check_cmd sshd; then
    ssh_localhost_status='sshd not found'
  elif check_cmd ssh; then
    ssh_localhost_status='sshd found, but ssh not found'
  elif ssh localhost -o IdentitiesOnly true >/dev/null; then
    ssh_localhost_status='Able to ssh to localhost'
  else
    ssh_localhost_status='sshd & ssh both found, but failed to ssh to localhost'
  fi
}

parse_env() {
  case "$(uname)" in
  Darwin) platform_name='macos' ;;
  Linux) platform_name='linux' ;;
  *)
    >&2 echo "Detected an unsupported platform: $(uname)"
    >&2 echo "Please open an issue at: $repo_url"
    >&2 echo "and provide the following information: $(uname -a)" exit 1
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
    system_arch="arm"
    ;;
  riscv64)
    system_arch="riscv64"
    ;;
  *)
    >&2 echo "Detected an unsupported architecture: $(uname -m)"
    >&2 echo "Please open an issue at: $repo_url"
    >&2 echo "and provide the following information: $(uname -a)"
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
    bin_path="/usr/bin"
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
  user_bin_dir=$user_home/.local/bin

  check_ssh_localhost

  [ -d $user_home/.local/ ] && is_dotlocal_created=true || is_dotlocal_created=false
  [ -d $user_home/.local/bin ] && is_dotlocalbin_created=true || is_dotlocalbin_created=false
  [ -d $user_home/.ssh/ ] && is_dotssh_created=true || is_dotssh_created=false
  [ -d $user_home/.sshnp/ ] && is_dotsshnp_created=true || is_dotsshnp_created=false
  [ -d $user_home/.atsign/ ] && is_dotatsign_created=true || is_dotatsign_created=false
  [ -d $user_home/.atsign/keys/ ] && is_dotatsignkeys_created=true || is_dotatsignkeys_created=false
  [ -f "$systemd_config_path" ] && is_overrideconf_created=true || is_overrideconf_created=false
}

is_valid_source_mode() {
  [ "$1" = "download" ] || [ "$1" = "local" ] || [ "$1" = "build" ]
}

is_valid_install_type() {
  [ "$1" = "device" ] || [ "$1" = "client" ]
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
        >&2 echo "Invalid install type: $install_type_input"
        >&2 echo "Valid options are: (device, client)" exit 1
      fi
      ;;
    --local)
      shift
      if [ -f "$1" ]; then
        local_archive="$1"
      else
        >&2 echo "Local archive not found: $1"
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
    -p | --policy-atsign)
      shift
      policy_atsign="$1"
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
        >&2 echo "Invalid device type: $device_type_input"
        >&2 echo "Valid options are: (launchd, systemd, tmux, headless)" exit 1
      fi
      ;;
    --no-sudo)
      no_sudo=true
      ;;
    -q | --quiet)
      quiet=true
      ;;
    *)
      >&2 echo "Unexpected option: $1"
      exit 1
      ;;
    esac
    shift
  done
  if [ $quiet = true ]; then
    if [ "$install_type" = "device" ]; then
      if [ -z "$client_atsign" ] || [ -z "$device_atsign" ] || [ -z "$device_name" ]; then
        >&2 echo "Error: Missing required information for device installation. (-c, -d, -n)"
        exit 1
      fi
      if [ -z "$policy_atsign" ]; then
        >&2 echo "Info: No policy atSign provided; continuing."
      fi
    elif [ "$install_type" = "client" ]; then
      if [ -z "$client_atsign" ] || [ -z "$device_atsign" ] || [ -z "$host_atsign" ]; then
        >&2 echo "Error: Missing required information for client installation. (-c, -d, -r)"
        exit 1
      fi
    else
      >&2 echo "Specify -t, (device or client) and its required parameters."
      exit 1
    fi
  fi
}

get_user_inputs() {
  if [ -z "$install_type" ]; then
    unset install_type_input
    while [ -z "$install_type" ]; do
      printf "Install type (device, client):  "
      read -r install_type_input
      install_type=$(norm_install_type "$install_type_input")
    done
  fi
}

print_env() {
  cat <<EOF
Environment:
  Platform name: $platform_name
  System arch: $system_arch
  Temp path: $tmp_path
  As root: $as_root
  Binary path: $bin_path
  User: $user
  User home: $user_home
  Ssh status: $ssh_localhost_status
  Did directories exist (prior to install):
  -       .local/ : $is_dotlocal_created
  -   .local/bin/ : $is_dotlocalbin_created
  -         .ssh/ : $is_dotssh_created
  -       .sshnp/ : $is_dotssh_created
  -      .atsign/ : $is_dotatsign_created
  - .atsign/keys/ : $is_dotatsignkeys_created
EOF
}

downloader() {
  if check_cmd curl; then
    curl -sSfL "$1" -o "$2"
  elif check_cmd wget; then
    wget "$1" -q -O "$2"
  else
    >&2 echo
    >&2 echo "Couldn't find curl or wget to download package"
    >&2 echo "Please install one of them"
    >&2 echo "Also how did you download this script???"
    >&2 echo
    exit 1
  fi
}

get_download_url() {
  unset download_urls
  release_prefix="https://api.github.com/repos/atsign-foundation/noports/releases/"
  release_info=$(downloader "$release_prefix$(norm_version $sshnp_version)" -)
  exitcode=$?
  if [ $exitcode != 0 ]; then exit $exitcode; fi
  download_urls=$(echo "$release_info" | grep browser_download_url | cut -d\" -f4)

  if [ -z "$download_urls" ]; then
    >&2 echo "Failed to get download url for sshnoports"
    exit 1
  fi

  echo "$download_urls" | grep "$platform_name" |
    grep "$system_arch." | cut -d\" -f4
}

download_archive() {
  read -r download_url
  echo "Downloading archive from $download_url"
  downloader "$download_url" "$archive_path"
  if [ ! -f "$archive_path" ]; then
    echo "Failed to download archive"
    exit 1
  fi
}

unpack_archive() {
  case "$archive_ext" in
  zip)
    if ! check_cmd unzip; then
      >&2 echo "ERROR: unzip not found"
      >&2 echo "Please install unzip and make it available on the PATH"
      exit 1
    fi
    unzip -qo "$archive_path" -d "$extract_path"
    ;;
  tgz | tar.gz)
    if ! check_cmd tar; then
      >&2 echo "ERROR: tar not available"
      >&2 echo "Please install tar and make it available on the PATH"
      exit 1
    fi
    mkdir -p "$extract_path"
    tar -zxf "$archive_path" -C "$extract_path"
    ;;
  esac
}

cleanup() {
  # These should be in the tmp directory, attempt to remove them anyway
  rm -f "$archive_path"
  rm -rf "$extract_path"

  if $as_root; then
    $is_dotlocal_created || chown_dir $user_home/.local
    $is_dotlocalbin_created || chown_dir $user_home/.local/bin
    $is_dotssh_created || chown_dir $user_home/.ssh/
    $is_dotsshnp_created || chown_dir $user_home/.sshnp/
    $is_dotatsign_created || chown_dir $user_home/.atsign/
    $is_dotatsignkeys_created || chown_dir $user_home/.atsign/keys/
  fi
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
  if grep -q "Environment=$variable=" <"$file"; then
    sedi "s|Environment=$variable=\".*\"|Environment=$variable=\"$value\"|g" "$file"
  else
    echo "Environment=$variable=\"$value\"" >"$file"
  fi
}

get_atsign_manually() {
  selectedatsign=""
  if [ $# -gt 0 ]; then
    clientOrDevice="$1"
  fi
  while [ -z "$selectedatsign" ]; do
    printf "Enter %s atSign: " "$clientOrDevice"
    read -r selectedatsign
  done
}

get_atsign_manually_once() {
  selectedatsign=""
  if [ $# -gt 0 ]; then
    clientOrDevice="$1"
  fi
  printf "Enter %s atSign (leave blank to skip): " "$clientOrDevice"
  read -r selectedatsign
}

get_atsign() {
  clientOrDevice="$1"
  atkeycount=0
  atkeys=""
  selectedatsign=""
  echo
  echo "Setting up $clientOrDevice atSign"
  if [ -d "${user_home}/.atsign/keys" ]; then
    # Disable unsafe find looping (will break if atkey file name contains a space, which it shouldn't)
    # shellcheck disable=SC2044
    for file in $(find "$user_home"/.atsign/keys/*.atKeys -type f); do
      atkeys="$atkeys $(echo "$file" | sed s/^.*@// | sed s/_key.atKeys//)"
      atkeycount=$((atkeycount + 1))
    done
    atkeys="$(echo "$atkeys" | sed s/\ \ /\ / | sed s/^\ //)" # remove double & leading space since it will interfere with cut
    if [ $atkeycount -eq 0 ]; then
      echo "$HOME/.atsign/keys directory found but there are no keys there yet, please enter the $clientOrDevice atSign manually"
      get_atsign_manually
    elif [ $atkeycount -eq 1 ]; then
      atkey=$(echo "$atkeys" | sed "s/\ //g")
      echo "1 atKeys file found: ${atkey}"
      printf "Would you like to use @%s? " "$atkey"
      read -r use_atkey
      case $use_atkey in
      [Yy]*)
        selectedatsign=$atkey
        ;;
      esac
    else
      echo "0) None"
      for i in $(seq 1 $atkeycount); do
        echo "$i) @$(echo "$atkeys" | cut -d' ' -f"$i")"
      done
      echo
      printf "Found .atKeys for %s atSigns." "$atkeycount"
      echo
      printf 'Choose %s atSign (input the number): $ ' "$clientOrDevice"
      read -r selectedinput

      selectedindex=$((selectedinput))
      if [ "$selectedindex" -gt 0 ]; then
        selectedatsign="$(echo "$atkeys" | cut -d' ' -f"$selectedindex")"
        echo "Selected: @$selectedatsign"
      else
        echo "No existing atkeys were selected, please enter the $clientOrDevice atSign manually."
        get_atsign_manually
      fi
    fi
  else
    mkdir -p "$user_home"/.atsign/keys
    chown_dir "$user_home"/.atsign
    echo "$HOME/.atsign/keys directory created"
    echo "Since we did not detect any atkeys on this machine, please enter the $clientOrDevice atSign manually."
    get_atsign_manually
  fi
}

suggest_sudo() {
  if ! check_cmd sudo; then
    echo
    echo "This script requires root privileges to continue, but sudo is not installed."
    echo "Please run this script as root."
    exit 1
  fi
  echo
  if is_systemd_available; then
    echo "Systemd is present but this script is not running with sudo"
    echo "We recommend that you install to systemd, which requires root"
    echo "privileges to write the unit file"
    echo
    echo "Use --no-sudo to install without systemd integration (NOT RECOMMENDED)"
    echo
  else
    echo "This script requires root privileges to continue."
  fi
  echo "Please re-run this script with sudo"
  exit 1
}

check_ssh_keys() {
  set +eu
  ssh_dir=$(ls -1 "$user_home"/.ssh) 2>/dev/null
  ssh_dir_exit=$?
  set -eu
  if [ "$ssh_dir_exit" -ne 0 ]; then
    echo
    echo "No .ssh directory found. You may want to create one and then add a key to it"
    echo "with ssh-keygen."
    echo
    return
  fi
  if [ "$ssh_dir" = "" ]; then
    echo
    echo "Found an empty .ssh directory."
    echo "You may wish to add a key with ssh-keygen."
    echo
    return
  fi
  if [ "$ssh_dir" = "authorized_keys" ]; then
    echo
    echo "Just found an authorized_keys file in the .ssh directory."
    echo "You may wish to add a key with ssh-keygen."
    echo
    return
  fi
  # TODO we could have a more sophisticated check for other files to see if they're keys
}

validate_activation() {
  device_output=$(echo "$(at_activate status -a $device_atsign 2>&1)")
  device_status=$(echo $device_output | grep -oE 'returning [0-9]+' | grep -oE '[0-9]+')

  client_output=$(echo "$(at_activate status -a $client_atsign 2>&1)")
  client_status=$(echo $client_output | grep -oE 'returning [0-9]+' | grep -oE '[0-9]+')

  if [ -z "$policy_atsign" ]; then
    policy_status=0
  else
    policy_output=$(echo "$(at_activate status -a $policy_atsign 2>&1)")
    policy_status=$(echo $policy_output | grep -oE 'returning [0-9]+' | grep -oE '[0-9]+')
  fi

  if [ "$device_status" -ne 0 ]; then
    echo
    echo "Activating $device_atsign..."
    if [ "$device_status" -eq 3 ]; then
      echo $device_output
    fi
    at_activate onboard -a $device_atsign -k "${user_home}/.atsign/keys/${device_atsign}_key.atKeys"
  fi

  if [ "$client_status" -ne 0 ]; then
    echo
    echo "Activating $client_atsign.."
    if [ "$client_status" -eq 3 ]; then
      echo $client_output
    fi
    at_activate onboard -a $client_atsign -k "${user_home}/.atsign/keys/${client_atsign}_key.atKeys"
  fi

  if [ "$policy_status" -ne 0 ]; then
    echo
    echo "Activating $policy_atsign.."
    if [ "$policy_status" -eq 3 ]; then
      echo "$policy_output"
    fi
    at_activate onboard -a "$policy_atsign" -k "${user_home}/.atsign/keys/${policy_atsign}_key.atKeys"
  fi
}

# CLIENT INSTALLATION #
client() {
  if [ "$used_package_manager" = false ]; then
    mkdir -p "$bin_path"

    # install the binaries
    "$extract_path"/sshnp/install.sh -b "$bin_path" -u "$user" sshnp
    "$extract_path"/sshnp/install.sh -b "$bin_path" -u "$user" npt
    "$extract_path"/sshnp/install.sh -b "$bin_path" -u "$user" srv
    "$extract_path"/sshnp/install.sh -b "$bin_path" -u "$user" at_activate
  fi

  # set PATH so it includes user's private bin if it exists
  if [ -d "$user_home/.local/bin" ] ; then
    PATH="$user_home/.local/bin:$PATH"
  fi

  # check that there are some ssh keys
  check_ssh_keys

  echo "Please enter atSigns you would like activated"
  # get the inputs for client & device atsign to do activation
  if [ -z "$client_atsign" ]; then
    get_atsign_manually_once "client"
    client_atsign="$selectedatsign"
  fi
  if [ -z "$device_atsign" ]; then
    get_atsign_manually_once "device"
    device_atsign="$selectedatsign"
  fi
  if [ -n "$device_atsign" ] || [ -n "$client_atsign" ]; then
    echo "Ensuring your atSigns are activated..."
    validate_activation
  fi
}

# DEVICE INSTALLATION #
device() {
  unset device_install_type
  if [ -z "$device_type" ]; then
    if is_darwin; then
      device_install_type="launchd"
    elif is_root && is_systemd_available; then
      device_install_type="systemd"
    else
      if ! $no_sudo && is_systemd_available; then
        suggest_sudo
      fi
      if check_cmd tmux; then
        device_install_type="tmux"
      else
        if ! check_cmd cron; then
          >&2 echo "ERROR: crontab not available"
          >&2 echo "Please install cron and make it available on the PATH"
          exit 1
        fi
        if ! check_cmd nohup; then
          >&2 echo "ERROR: nohup not available"
          >&2 echo "Please install nohup and make it available on the PATH"
          exit 1
        fi
        device_install_type="headless"
      fi
    fi
  else
    # override the device type if it is set
    device_install_type=$device_type
  fi

  if [ "$used_package_manager" = false ]; then
    if [ "$device_install_type" = "systemd" ] && [ "$as_root" = true ]; then
      cleanup_old_installation
    fi

    # install at_activate binary
    "$extract_path"/sshnp/install.sh -b "$bin_path" -u "$user" at_activate

    # install sshnpd binary and capture the installer output
    # If systemd, we want to use the new style
    if [ "$device_install_type" = "systemd" ] && [ "$as_root" = true ]; then
      install_output=$("$extract_path"/sshnp/install.sh -b "$bin_path" -u "$user" sshnpd)
      # Manually install the nfpm style systemd unit
      mkdir -p /lib/systemd/system
      cp "$extract_path/sshnp/bundles/shell/systemd.nfpm/sshnpd.service" /lib/systemd/system/sshnpd.service
      
      # Install the override file and customize the User
      mkdir -p /etc/systemd/system/sshnpd.service.d
      cp "$extract_path/sshnp/bundles/shell/systemd.nfpm/sshnpd.service.d/override.conf" /etc/systemd/system/sshnpd.service.d/override.conf
      customize_systemd_user

      # If we are root, we should also ensure /etc/noports exists and has the config
      mkdir -p /etc/noports
      if [ ! -f /etc/noports/sshnpd.yaml ]; then
        cp "$extract_path/sshnp/bundles/core/config/sshnpd.yaml" /etc/noports/sshnpd.yaml
      fi
      migrate_systemd_config_to_yaml
    else
      install_output=$("$extract_path"/sshnp/install.sh -b "$bin_path" -u "$user" "$device_install_type" sshnpd)
    fi

    if [ "$verbose" = true ]; then
      echo "$install_output"
    fi
  else
    install_output=""
  fi

  # upgrade an existing installation if we find one
  case "$device_install_type" in
  launchd)
    launchd_plist="$HOME/Library/LaunchAgents/com.atsign.sshnpd.plist"
    if [ -f "$launchd_plist" ]; then
      echo "launchd config already in place"
      echo "To update your config, edit $launchd_plist"
      return
    fi
    ;;
  systemd)
    if [ "$as_root" = true ]; then
       # For systemd nfpm style, we check if it's already enabled/running
       if systemctl is-enabled sshnpd >/dev/null 2>&1; then
         echo "sshnpd systemd service is already enabled"
         if [ "$used_package_manager" = false ]; then
           systemctl daemon-reload
           systemctl restart sshnpd
           print_systemd_summary restart
           return
         fi
       fi
    else
      if [ "$is_overrideconf_created" = true ]; then
        echo "systemd config for sshnpd service already in place"
        echo "sshnpd systemd upgraded and restarted. To see logs use:"
        echo "  journalctl -u sshnpd -f"
        systemctl restart sshnpd
        return
      fi
    fi
    ;;
  tmux | headless)
    # Not recommended, we don't offer any help
    ;;
  esac

  # Get atSigns for fresh install
  # We only need to prompt if the config isn't already populated
  if [ "$device_install_type" = "systemd" ] && [ "$as_root" = true ] && [ -f /etc/noports/sshnpd.yaml ]; then
     if grep -E "^[[:space:]]+atsign:[[:space:]]*[^[:space:]#]" /etc/noports/sshnpd.yaml >/dev/null; then
        echo "Configuration already populated in /etc/noports/sshnpd.yaml"
        # We still might need to ensure activation if it's a new install but config was migrated
        # Actually validation happens later if client/device_atsign are set.
        # Let's extract them from YAML if they aren't set
        [ -z "$device_atsign" ] && device_atsign=$(grep -E "^[[:space:]]+atsign:[[:space:]]*" /etc/noports/sshnpd.yaml | head -n 1 | cut -d: -f2 | sed -e "s/['\"]//g" -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        [ -z "$client_atsign" ] && client_atsign=$(grep -A 5 "managers:" /etc/noports/sshnpd.yaml | grep "-" | head -n 1 | sed -e "s/['\"]//g" -e 's/^[[:space:]]*-//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
     fi
  fi

  if [ -z "$client_atsign" ]; then
    get_atsign_manually "client"
    client_atsign="$selectedatsign"
  fi

  if [ -z "$device_atsign" ]; then
    get_atsign "device"
    device_atsign="$selectedatsign"
  fi

  # Note: policy_atsign is not mandatory so, if none was supplied,
  #       we will not prompt for it

  # For systemd nfpm style, we might already have the name in YAML
  if [ "$device_install_type" = "systemd" ] && [ "$as_root" = true ] && [ -f /etc/noports/sshnpd.yaml ]; then
     [ -z "$device_name" ] && device_name=$(grep -E "^[[:space:]]*name:[[:space:]]*" /etc/noports/sshnpd.yaml | head -n 1 | cut -d: -f2 | sed -e "s/['\"]//g" -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  fi

  while [ -z "$device_name" ]; do
    printf "Enter device name: "
    read -r device_name
    # capitals are allowed here, sshnpd will convert to lowercase
    if ! echo "$device_name" | grep -Eq '^[A-Za-z0-9_][A-Za-z0-9_-]{0,35}$'; then
      echo "Device name must only contain alphanumeric characters, '-', or '_' and may not start with '-'."
      echo "Device name may have a maximum length of 36 characters"
      device_name=""
    fi
  done

  # configure service for fresh install
  case "$device_install_type" in
  launchd)
    if [ -n "$policy_atsign" ]; then
      policy_option="-p"
      policy_atsign="$(norm_atsign "$client_atsign")"
    else
      policy_option=""
    fi
    launchd_plist="$HOME/Library/LaunchAgents/com.atsign.sshnpd.plist"
    write_program_arguments_plist "$launchd_plist" "$bin_path/sshnpd" \
      "-m" "$(norm_atsign "$client_atsign")" \
      "-a" "$(norm_atsign "$device_atsign")" \
      "-d" "$device_name" "-su" \
      "$policy_option" "$policy_atsign"

    launchctl unload "$launchd_plist"
    launchctl load "$launchd_plist"
    echo "sshnpd installed with launchd"
    ;;
  systemd)
    if [ "$as_root" = true ]; then
      # Update YAML if we got new inputs
      yaml_file="/etc/noports/sshnpd.yaml"
      sedi "s|^\([[:space:]]\{2\}atsign:\)[[:space:]]*.*$|\1 '$(norm_atsign "$device_atsign")'|" "$yaml_file"
      if [ -n "$client_atsign" ]; then
        # This is a bit simplistic for managers list, but if it was empty it works
        if ! grep -A 5 "managers:" "$yaml_file" | grep -q "$(norm_atsign "$client_atsign")"; then
           sedi "s|^[[:space:]]*#[[:space:]]*- your_atsign_here$|    - '$(norm_atsign "$client_atsign")'|" "$yaml_file"
        fi
      fi
      if [ -n "$policy_atsign" ]; then
        sedi "s|^\([[:space:]]\{2\}policy:\)[[:space:]]*.*$|\1 '$(norm_atsign "$policy_atsign")'|" "$yaml_file"
      fi
      sedi "/^device:/,/^ssh:/s|^\([[:space:]]*name:\)[[:space:]]*.*$|\1 '$device_name'|" "$yaml_file"

      systemctl daemon-reload
      systemctl enable sshnpd
      systemctl start sshnpd
    else
      write_systemd_user "$systemd_config_path" "$user"
      write_systemd_environment "$systemd_config_path" "manager_atsign" "$(norm_atsign "$client_atsign")"
      write_systemd_environment "$systemd_config_path" "device_atsign" "$(norm_atsign "$device_atsign")"
      if [ -n "$policy_atsign" ]; then
        write_systemd_environment "$systemd_config_path" "delegate_policy" "-p $(norm_atsign "$policy_atsign")"
      fi
      write_systemd_environment "$systemd_config_path" "device_name" "$device_name"

      systemctl enable sshnpd
      systemctl start sshnpd
    fi

    print_systemd_summary
    ;;
  tmux | headless)
    shell_script="$bin_path"/sshnpd.sh
    write_metadata "$shell_script" "manager_atsign" "$(norm_atsign "$client_atsign")"
    write_metadata "$shell_script" "device_atsign" "$(norm_atsign "$device_atsign")"
    write_metadata "$shell_script" "device_name" "$device_name"
    if [ -n "$policy_atsign" ]; then
      write_metadata "$shell_script" "delegate_policy" "-p $(norm_atsign "$policy_atsign")"
    fi
    # split install output by lines, then grab the output after the line that says "To start immediately"
    eval "$(echo "$install_output" | grep -A1 "To start .* immediately:" | tail -n1)"
    ;;
  esac
  if ! check_cmd sshd; then
    >&2 echo "sshd not found. Please install sshd and ensure it is running."
  fi
}

is_debian_like() {
  if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    case "$ID" in
    debian | ubuntu | mint | kali | raspbian) return 0 ;;
    esac
    case "${ID_LIKE:-}" in
    *debian* | *ubuntu*) return 0 ;;
    esac
  elif [ -f /etc/debian_version ]; then
    return 0
  fi
  return 1
}

is_redhat_like() {
  if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    case "$ID" in
    fedora | rhel | centos | amzn | rocky | almalinux) return 0 ;;
    esac
    case "${ID_LIKE:-}" in
    *fedora* | *rhel* | *centos*) return 0 ;;
    esac
  elif [ -f /etc/redhat-release ]; then
    return 0
  fi
  return 1
}

cleanup_old_installation() {
  if [ "$as_root" = false ]; then
    return
  fi
  echo "Cleaning up old noports installation..."
  # List of binaries and scripts to remove from non-package locations
  binaries="sshnp sshnpd npt srv srvd at_activate noports np_admin npp_atserver npp_file"
  # We check /usr/local/bin
  # Note: New install is to /usr/bin, so those are safe.
  for dir in "/usr/local/bin"; do
    for bin in $binaries; do
      if [ -f "$dir/$bin" ]; then
        echo "Removing old binary: $dir/$bin"
        rm -f "$dir/$bin"
      fi
    done
    # Also remove the wrapper script if it exists
    if [ -f "$dir/sshnpd.sh" ]; then
      echo "Removing old script: $dir/sshnpd.sh"
      rm -f "$dir/sshnpd.sh"
    fi
  done

  # Check for local installation in user's home
  if [ "$user" != "root" ]; then
    local_bin_dir="$user_home/.local/bin"
    found_local=false
    for bin in $binaries; do
      if [ -f "$local_bin_dir/$bin" ]; then
        found_local=true
        break
      fi
    done

    if [ "$found_local" = true ]; then
      if [ "$quiet" = true ]; then
        echo "Removing local installation from $local_bin_dir..."
        for bin in $binaries; do
          rm -f "$local_bin_dir/$bin"
        done
        rm -f "$local_bin_dir/sshnpd.sh"
      else
        echo "WARNING: A local installation of NoPorts was found in $local_bin_dir"
        echo "This may conflict with the system-wide installation."
        printf "Would you like to remove the local installation? [Y/n] "
        read -r remove_local
        case $remove_local in
        [Nn]*) ;;
        *)
          echo "Removing local installation..."
          for bin in $binaries; do
            rm -f "$local_bin_dir/$bin"
          done
          rm -f "$local_bin_dir/sshnpd.sh"
          ;;
        esac
      fi
    fi
  fi

  # If we have an old systemd unit in /etc/systemd/system, it will override the package unit in /lib/systemd/system
  # Or if we are doing a manual install, we want to move to /lib/systemd/system/ (nfpm style)
  if [ -f "/etc/systemd/system/sshnpd.service" ]; then
    echo "Disabling and removing old systemd unit /etc/systemd/system/sshnpd.service"
    systemctl stop sshnpd 2>/dev/null || true
    systemctl disable sshnpd 2>/dev/null || true
    mv "/etc/systemd/system/sshnpd.service" "/etc/systemd/system/sshnpd.service.old"
    # We do NOT move the .service.d directory as it's still needed for User= and other overrides
    systemctl daemon-reload
  fi
}

migrate_systemd_config_to_yaml() {
  yaml_file="/etc/noports/sshnpd.yaml"
  # If the YAML doesn't exist, we might be in a manual install flow where it's not yet copied.
  # But for nfpm style, it should be there.
  if [ ! -f "$yaml_file" ]; then
    echo "Warning: $yaml_file not found. Creating from template if available."
    mkdir -p /etc/noports
    if [ -f "$extract_path/sshnp/bundles/core/config/sshnpd.yaml" ]; then
      cp "$extract_path/sshnp/bundles/core/config/sshnpd.yaml" "$yaml_file"
    else
      # Fallback to minimal if template not found in expected extract path
      cat <<EOF > "$yaml_file"
atsign:
  atsign: 
access:
  policy: 
  managers:
    - 
device:
  name: 
ssh:
  add-publickeys: true
  ssh-client: openssh
  sshd-port: 22
runtime:
  verbose: true
EOF
    fi
  fi

  # Check if atsign is already set
  if grep -E "^[[:space:]]+atsign:[[:space:]]*[^[:space:]#]" "$yaml_file" >/dev/null; then
    echo "YAML config $yaml_file appears to be already populated, skipping migration."
    return
  fi

  echo "Migrating existing systemd configuration to $yaml_file..."

  # Extract values from systemd unit and override files
  # Check /etc/systemd/system/sshnpd.service.old if we just moved it
  unit_file="/etc/systemd/system/sshnpd.service"
  [ ! -f "$unit_file" ] && [ -f "${unit_file}.old" ] && unit_file="${unit_file}.old"
  override_file="/etc/systemd/system/sshnpd.service.d/override.conf"
  [ ! -d "$(dirname "$override_file")" ] && [ -d "$(dirname "$override_file").old" ] && override_file="$(dirname "$override_file").old/override.conf"

  m_atsign=""
  d_atsign=""
  d_name=""
  p_atsign=""

  extract_val() {
    val=$(grep -h "^Environment=$1=" "$override_file" "$unit_file" 2>/dev/null | tail -n 1 | cut -d= -f3- | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
    echo "$val"
  }

  m_atsign=$(extract_val "manager_atsign")
  d_atsign=$(extract_val "device_atsign")
  d_name=$(extract_val "device_name")
  delegate_policy=$(extract_val "delegate_policy")
  if [ -n "$delegate_policy" ]; then
    p_atsign=$(echo "$delegate_policy" | sed 's/-p //')
  fi

  [ -z "$d_name" ] && d_name="default"

  # Update the template file using sedi
  if [ -n "$d_atsign" ]; then
    sedi "s|^\([[:space:]]\{2\}atsign:\)[[:space:]]*$|\1 '$(norm_atsign "$d_atsign")'|" "$yaml_file"
  fi
  if [ -n "$p_atsign" ]; then
    sedi "s|^\([[:space:]]\{2\}policy:\)[[:space:]]*$|\1 '$(norm_atsign "$p_atsign")'|" "$yaml_file"
  fi
  if [ -n "$m_atsign" ]; then
    sedi "s|^[[:space:]]*#[[:space:]]*- your_atsign_here$|    - '$(norm_atsign "$m_atsign")'|" "$yaml_file"
  fi
  if [ -n "$d_name" ]; then
    sedi "/^device:/,/^ssh:/s|^\([[:space:]]*name:\)[[:space:]]*$|\1 '$d_name'|" "$yaml_file"
  fi

  # Comment out the old Environment variables in the override file if they were migrated
  if [ -f "$override_file" ]; then
    if grep -q "^Environment=" "$override_file"; then
      echo "Cleaning up migrated Environment variables from $override_file..."
      # Add a header note to the [Service] section
      sedi "s/^\[Service\]/\[Service\]\\
# NOTE: Environment variables have been commented out below because\\
# config has been migrated to $yaml_file/" "$override_file"

      # Comment out any active Environment= lines
      sedi "s/^\(Environment=.*\)/# \1/" "$override_file"
    fi
  fi

  echo "Migration complete."
}

customize_systemd_user() {
  # This covers both sshnpd and srvd as they both have overrides in nfpm
  for service in "sshnpd" "srvd"; do
    override_file="/etc/systemd/system/${service}.service.d/override.conf"
    if [ -f "$override_file" ]; then
      echo "Customizing systemd user for ${service} in $override_file..."
      sedi "s/^User=1000$/User=$user/" "$override_file"
    fi
  done
}

print_systemd_summary() {
  verb="installed with"
  [ "${1:-}" = "restart" ] && verb="restarted. The service is"
  echo "sshnpd $verb systemd."
  echo "The service is configured to run as user: $user"
  echo "If you wish to change this, run:"
  echo "  sudo systemctl edit sshnpd"
  echo "To see logs use:"
  echo "  journalctl -u sshnpd -f"
}

install_via_rpm() {
  echo "Installing noports via rpm..."
  if ! (check_cmd dnf || check_cmd yum); then
    >&2 echo "Error: dnf or yum is required for rpm installation"
    exit 1
  fi

  if ! is_root; then
    suggest_sudo
  fi

  # Create the repository file
  tee /etc/yum.repos.d/noports.repo <<EOF
[noports]
name=NoPorts Repository
baseurl=https://rpm.noports.com/\$basearch/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://rpm.noports.com/noports.pub.asc
EOF

  if check_cmd dnf; then
    dnf install -y noports
  else
    yum install -y noports
  fi

  if [ -f "/etc/systemd/system/sshnpd.service" ]; then
    migrate_systemd_config_to_yaml
  fi
  customize_systemd_user
  cleanup_old_installation
  print_systemd_summary restart
  used_package_manager=true
}

install_via_brew() {
  echo "Installing noports via brew..."
  if ! check_cmd brew; then
    >&2 echo "Error: brew is required for brew installation"
    exit 1
  fi

  brew tap atsign-foundation/homebrew-tap

  # Trust the tap if Homebrew version is 6 or later
  brew_version=$(brew --version 2>/dev/null | head -n 1 | cut -d' ' -f2 | cut -d'.' -f1 || true)
  if [ -n "$brew_version" ] && [ "$brew_version" -ge 6 ] 2>/dev/null; then
    echo "Brew version 6 or later detected ($brew_version). Trusting tap atsign-foundation/homebrew-tap..."
    brew trust atsign-foundation/homebrew-tap
  fi

  brew install noports
  used_package_manager=true
}

install_via_apt() {
  echo "Installing noports via apt..."
  if ! check_cmd apt; then
    >&2 echo "Error: apt is required for apt installation"
    exit 1
  fi

  if ! is_root; then
    suggest_sudo
  fi

  if ! check_cmd curl; then
    echo "curl not found, installing curl..."
    apt update && apt install -y curl
  fi

  if ! check_cmd gpg; then
    echo "gpg not found, installing gnupg..."
    apt update && apt install -y gnupg
  fi

  mkdir -p /usr/share/keyrings
  curl -fsSL https://apt.noports.com/noports.pub.asc | gpg --dearmor -o /usr/share/keyrings/noports-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/noports-archive-keyring.gpg] https://apt.noports.com/ stable main" | tee /etc/apt/sources.list.d/noports.list
  apt update
  apt install -y noports

  if [ -f "/etc/systemd/system/sshnpd.service" ]; then
    migrate_systemd_config_to_yaml
  fi
  customize_systemd_user
  cleanup_old_installation
  print_systemd_summary restart
  used_package_manager=true
}

main() {
  trap cleanup EXIT
  set -eu
  check_quiet "$@"
  parse_env
  print_env
  parse_args "$@"

  if $as_root && $no_sudo; then
    >&2 echo "Error: --no-sudo cannot be used when running as root/sudo"
    exit 1
  fi

  if [ -n "$local_archive" ]; then
    echo "Using local archive: $local_archive"
    cp "$local_archive" "$archive_path"
    unpack_archive
  elif ! $no_sudo && [ "$platform_name" = "linux" ] && is_debian_like && (check_cmd apt || check_cmd apt-get); then
    install_via_apt
  elif ! $no_sudo && [ "$platform_name" = "linux" ] && is_redhat_like && (check_cmd dnf || check_cmd yum); then
    install_via_rpm
  elif [ "$platform_name" = "macos" ] && check_cmd brew; then
    if [ "$quiet" = true ]; then
      install_via_brew
    else
      echo "Homebrew detected."
      printf "Would you like to install noports via Homebrew? [Y/n] "
      read -r use_brew
      case $use_brew in
      [Nn]*)
        download_url=$(get_download_url)
        echo "$download_url" | download_archive
        unpack_archive
        ;;
      *)
        install_via_brew
        ;;
      esac
    fi
  else
    download_url=$(get_download_url)
    echo "$download_url" | download_archive
    unpack_archive
  fi

  get_user_inputs
  case "$install_type" in
  client) client ;;
  device) device ;;
  esac
}

main "$@"
