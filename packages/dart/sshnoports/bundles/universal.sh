#!/bin/sh

# SCRIPT METADATA
# DO NOT MODIFY/DELETE THIS BLOCK
script_version="3.0.0"
sshnp_version="5.5.0"
repo_url="https://github.com/atsign-foundation/sshnoports"
# END METADATA

# N.B. Other than the variable definitions, and the call to the main function,
# nothing else should be writen outside the main function to avoid side effects
### Environment config

# GREP_COLOR not used directly so ignore the shellcheck warning for it
# shellcheck disable=SC2034
GREP_COLOR=never
unset GREP_OPTIONS

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

### Input Variables
verbose=false
unset tmp_path
install_type=""
unset download_url
local_archive=""
no_sudo=false
quiet=false

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
  echo "  -n,   --device-name    <name>    Set the device name"
  echo "  --dt, --device-type    <type>    Set the device type (launchd, systemd, tmux, headless)"
  echo "        --no-sudo                  Deliberately install without sudo priveleges"

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
      system_arch="armv7"
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
  user_bin_dir=$user_home/.local/bin

  check_ssh_localhost

  [ -d $user_home/.local/ ] && is_dotlocal_created=true || is_dotlocal_created=false
  [ -d $user_home/.local/bin ] && is_dotlocalbin_created=true || is_dotlocalbin_created=false
  [ -d $user_home/.ssh/ ] && is_dotssh_created=true || is_dotssh_created=false
  [ -d $user_home/.sshnp/ ] && is_dotsshnp_created=true || is_dotsshnp_created=false
  [ -d $user_home/.atsign/ ] && is_dotatsign_created=true || is_dotatsign_created=false
  [ -d $user_home/.atsign/keys/ ] && is_dotatsignkeys_created=true || is_dotatsignkeys_created=false
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
    grep "$system_arch" | cut -d\" -f4
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
  sedi "s|Environment=$variable=\".*\"|Environment=$variable=\"$value\"|g" "$file"
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
  echo
  echo "Systemd is present but this script is not running with sudo"
  echo "We recommend that you install to systemd (requires root privileges to write the unit file)"
  echo
  echo "sudo sh universal.sh"
  echo
  echo "If you'd rather proceed with a non systemd installation (not recommended):"
  echo
  echo "sh universal.sh --no-sudo"
  echo
  exit 0
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

validate_activation(){
  device_output=$(echo "$(at_activate status -a $device_atsign 2>&1)")
  device_status=$(echo $device_output | grep -oE 'returning [0-9]+' | grep -oE '[0-9]+')
  client_output=$(echo "$(at_activate status -a $client_atsign 2>&1)")
  client_status=$(echo $client_output | grep -oE 'returning [0-9]+' | grep -oE '[0-9]+')
    if [ "$device_status" -ne 0 ]; then
      echo "Activiating your device atsign"
      if [ "$device_status" -eq 3 ]; then
        echo $device_output
      fi
      at_activate onboard -a $device_atsign
    fi
    if [ "$client_status" -ne 0 ]; then
          echo "Activiating your client atsign"
      if [ "$client_status" -eq 3 ]; then
        echo $client_output
      fi
      at_activate onboard -a $client_atsign
    fi
}

# CLIENT INSTALLATION #
client() {
  mkdir -p "$bin_path"

  # install the binaries
  "$extract_path"/sshnp/install.sh -b "$bin_path" -u "$user" sshnp
  "$extract_path"/sshnp/install.sh -b "$bin_path" -u "$user" npt
  "$extract_path"/sshnp/install.sh -b "$bin_path" -u "$user" srv
  "$extract_path"/sshnp/install.sh -b "$bin_path" -u "$user" at_activate

  # check that there are some ssh keys
  check_ssh_keys

  # install the magic sshnp script
  magic_script="$bin_path"/np.sh
  cp "$extract_path"/sshnp/magic/sshnp.sh "$magic_script"
  chmod +x "$magic_script"
  if is_root && [ -f "$bin_path"/np.sh ]; then
    ln -sf "$bin_path"/np.sh "$user_bin_dir"/np.sh
    if [ $verbose = true ]; then
      echo "=> Linked $user_bin_dir/np.sh to $bin_path/np.sh"
    fi
  fi

  # get the inputs for the magic script
  if [ -z "$client_atsign" ]; then
    get_atsign "client"
    client_atsign="$selectedatsign"
  fi

  if [ -z "$device_atsign" ]; then
    get_atsign_manually "device"
    device_atsign="$selectedatsign"
  fi

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
        printf "Invalid region: %s: " "$host_atsign"
        read -r host_atsign
        ;;
    esac
  done

  if [ -z "$devices" ]; then
    if [ "$quiet" = false ]; then
      done_input=false
      echo "Installing a quick picker script to make it easy to connect to devices..."
      echo "Type a device name and press enter to submit it."
      echo "Press enter once more to finish."
      while [ "$done_input" = false ]; do
        printf "Device name: "
        read -r device_name
        if [ -z "$device_name" ]; then
          done_input=true
        else
          if ! echo "$device_name" | grep -Eq '^[a-z][a-z0-9_]{0,14}$'; then
            echo "Device name must be in snake case and max 15 characters"
            device_name=""
          else
            devices="$devices,$device_name"
          fi
        fi
      done
    fi
  fi
  validate_activation
  # write the metadata to the magic script
  write_metadata "$magic_script" "client_atsign" "$(norm_atsign "$client_atsign")"
  write_metadata "$magic_script" "device_atsign" "$(norm_atsign "$device_atsign")"
  write_metadata "$magic_script" "host_atsign" "$(norm_atsign "$host_atsign")"
  write_metadata_array "$magic_script" "devices" "$devices"

  echo "Run ${bin_path}/np.sh to get your quick pick of devices to connect to."
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

  if [ -z "$client_atsign" ]; then
    get_atsign_manually "client"
    client_atsign="$selectedatsign"
  fi

  if [ -z "$device_atsign" ]; then
    get_atsign "device"
    device_atsign="$selectedatsign"
  fi

  while [ -z "$device_name" ]; do
    printf "Enter device name: "
    read -r device_name
    if ! echo "$device_name" | grep -Eq '^[a-z][a-z0-9_]{0,14}$'; then
      echo "Device name must be in snake case and max 15 characters"
      device_name=""
    fi
  done

  "$extract_path"/sshnp/install.sh -b "$bin_path" -u "$user" at_activate

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
  if ! check_cmd sshd; then
    >&2 echo "sshd not found. Please install sshd and ensure it is running."
  fi
}

main() {
  trap cleanup EXIT
  set -eu
  check_quiet "$@"
  parse_env
  print_env
  parse_args "$@"

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
  esac
}

main "$@"
