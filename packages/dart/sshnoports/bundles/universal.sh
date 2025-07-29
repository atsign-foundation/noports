#!/bin/sh

# SCRIPT METADATA
# DO NOT MODIFY/DELETE THIS BLOCK
script_version="4.0.0"
sshnp_version="5.11.2"
repo_url="https://github.com/atsign-foundation/noports"
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
unset platform_name
unset system_arch
unset archive_ext
unset time_stamp
unset archive_path
unset as_root
unset bin_path
unset user
unset user_home

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
unset tmp_path
unset download_url
local_archive=""

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
  if [ -d "$1" ]; then
    echo "$1 was created by this installer, ensuring that it is owned by $user"
    chown -R "$user:$user" "$1" 2>/dev/null || chown -R "$user" "$1" 2>/dev/null
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
  echo "      --local          <path>    Install from a local archive"
  echo "  -q, --quiet                    Disables any printing to the terminal from the script. Ensure you are including options."
  echo
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
  bin_path="/usr/local/bin"
  is_root && user="$SUDO_USER" || user="$USER"

  check_ssh_localhost

  [ -d "$user_home/.ssh/" ] && is_dotssh_created=true || is_dotssh_created=false
  [ -d "$user_home/.sshnp/" ] && is_dotsshnp_created=true || is_dotsshnp_created=false
  [ -d "$user_home/.atsign/" ] && is_dotatsign_created=true || is_dotatsign_created=false
  [ -d "$user_home/.atsign/keys/" ] && is_dotatsignkeys_created=true || is_dotatsignkeys_created=false
  [ -f "$systemd_config_path" ] && is_overrideconf_created=true || is_overrideconf_created=false
}

is_valid_source_mode() {
  [ "$1" = "download" ] || [ "$1" = "local" ] || [ "$1" = "build" ]
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    -v | --verbose)
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
    --local)
      shift
      if [ -f "$1" ]; then
        local_archive="$1"
      else
        >&2 echo "Local archive not found: $1"
        exit 1
      fi
      ;;
    *)
      >&2 echo "Unexpected option: $1"
      exit 1
      ;;
    esac
    shift
  done
}

print_env() {
  cat <<EOF
Environment:
  Platform name: $platform_name
  System arch: $system_arch
  Temp path: $tmp_path
  Binary path: $bin_path
  User: $user
  User home: $user_home
  Ssh status: $ssh_localhost_status
  Did file/dir exist (prior to install):
  -         .ssh/ : $is_dotssh_created
  -       .sshnp/ : $is_dotsshnp_created
  -      .atsign/ : $is_dotatsign_created
  - .atsign/keys/ : $is_dotatsignkeys_created
  - override.conf : $is_overrideconf_created
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

  if is_root; then
    chown_dir "$user_home/.ssh/"
    chown_dir "$user_home/.sshnp/"
    chown_dir "$user_home/.atsign/"
    chown_dir "$user_home/.atsign/keys/"
  fi
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
}

install_macos_config() {
  launchd_dir="$user_home/Library/LaunchAgents"
  unit="com.atsign.sshnpd.plist"
  mkdir -p "$launchd_dir"
  dest="$launchd_dir/$unit"
  [ -f "$dest" ] || {
    cp "$extract_path/sshnp/launchd/$unit" "$dest"
    echo Installed launchd config at "$dest".
    echo First configure the file by running:
    echo
    echo xcode "$dest"
    echo
    echo Then start the service from the "Login Items" menu in System Settings
  }
}

install_systemd_config() {
  systemd_dir="/etc/systemd/system"
  for unit in sshnpd srvd; do
    systemd_unit="$systemd_dir/$unit.service"
    systemd_config="$systemd_dir/$unit.service.d/override.conf"

    if ! [ -d "$systemd_unit.d" ]; then
      mkdir -p "$systemd_unit.d"
    fi
    if [ -f "$systemd_unit" ]; then
      # migrate old config from systemd unit file to override.conf
      touch "$systemd_config"
      if [ ! -s "$systemd_config" ]; then
        echo "[Service]" >>"$systemd_config"
      fi
      temp_file="$systemd_unit.tmp"
      while IFS= read -r line; do
        case "$line" in
        Environment=*)
          # Comment out the line in the original file
          echo "# config migrated to $systemd_config" >>"$temp_file"
          echo "# $line" >>"$temp_file"
          # Extract the environment variable and write it to the override file
          echo "# config migrated from $systemd_unit" >>"$systemd_config"
          echo "$line" >>"$systemd_config"
          ;;
        User=*)
          # Comment out the line in the original file
          echo "# config migrated to $systemd_config" >>"$temp_file"
          echo "# $line" >>"$temp_file"
          # Extract the user variable and write it to the override file
          echo "# config migrated from $systemd_unit" >>"$systemd_config"
          echo "$line" >>"$systemd_config"
          ;;
        *)
          echo "$line" >>"$temp_file"
          ;;
        esac
      done <"$systemd_unit"
      # Overwrite the original file with the modified content
      mv "$temp_file" "$systemd_unit"
      echo "sshnpd configuration migrated to $systemd_config"
    else
      cp "$extract_path/sshnp/systemd/$unit.service" "$systemd_unit"
    fi

    # Create override.conf if it's missing
    [ -f "$systemd_config" ] || {
      cp "$extract_path/sshnp/systemd/$unit.service.d/override.conf" "$systemd_config"
      echo "$unit config installed at $systemd_config"
      echo "This file must be edited before you can start the systemd service"
      echo
    }
    sedi "s|<username>|$user|g" "$systemd_config"
  done
}

install_service_file() {
  if is_darwin; then
    install_macos_config
  elif is_systemd_available; then
    install_systemd_config
  else
    echo "Unable to detect your service manager."
    echo "If you want to run sshnpd, you will have to set up the service manually."
  fi
}

install_binaries() {
  for bin in at_activate srv npt sshnp sshnpd srvd npp_atserver npp_file npa_file np_admin; do
    asset="$extract_path/sshnp/$bin"
    if [ -f "$asset" ]; then
      cp "$asset" "$bin_path/"
      chmod 555 "$bin_path/$bin"
    fi
  done
}

run_self_as_root() {
  echo Running this as root...
  echo "Executing: \"sudo $0 $*\""
  exec sudo "$0" "$@"
  exit $?
}

main() {
  is_root || run_self_as_root "$@"

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

  install_binaries
  install_service_file
}

main "$@"
