#!/bin/sh

# SYSTEM GIVENS #
is_root() {
  [ "$(id -u)" -eq 0 ]
}

is_darwin() {
  [ "$(uname)" = 'Darwin' ]
}

unset binary_dir
user_home=$HOME
define_env() {
  script_dir="$(dirname -- "$(readlink -f -- "$0")")"
  bin_dir="/usr/local/bin"
  systemd_dir="/etc/systemd/system"
  if is_root; then
    if is_darwin; then
      echo "Installing as root is not available on MacOS"
      exit 1
    fi
    user="$SUDO_USER"
    if [ -z "$user" ]; then
      user="root"
    else
      # we are root, but via sudo
      # so get home directory of SUDO_USER
      user_home=$(sudo -H -u "$user" sh -c 'echo $HOME')
    fi
  else
    user="$USER"
  fi
  define_user_paths
}

# Sets the paths in $user_home, the home directory of $user.
define_user_paths() {
  launchd_dir="$user_home/Library/LaunchAgents"
  user_bin_dir="$user_home/.local/bin"
  user_sshnpd_dir="$user_home/.sshnpd"
  user_log_dir="$user_sshnpd_dir/logs"
  user_ssh_dir="$user_home/.ssh"
}

sedi() {
  if is_darwin; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

no_mac() {
  if is_darwin; then
    echo "Error: this operation is only supported on linux"
    exit 1
  fi
}

mac_only() {
  if ! is_darwin; then
    echo "Error: this operation is only supported on macos"
    exit 1
  fi
}

root_only() {
  if ! is_root; then
    echo "Error: this operation requires root privileges"
    exit 1
  fi
}

# Refuses the job $1 when root would install it for another account.
no_root_for_others() {
  if is_root && [ "$user" != root ]; then
    echo "Error: run install.sh $1 without sudo, as the user who will run the daemon"
    exit 1
  fi
}

# Prints each of the paths given that exists and is not owned by the account
# running install.sh.
not_owned() {
  for entry in "$@"; do
    if [ -e "$entry" ] && ! [ -O "$entry" ]; then
      echo "  $entry"
    fi
  done
}

# Stops before the $1 job $2 is installed when a path in the home that it
# writes to is not owned by the account running install.sh.
check_job_paths() {
  if is_root; then
    return
  fi
  script="$user_bin_dir/$2.sh"
  in_local=$(not_owned "$user_home/.local" "$user_bin_dir" "$script")
  in_sshnpd=''
  if [ "$1" = headless ]; then
    in_sshnpd=$(not_owned "$user_sshnpd_dir" "$user_log_dir")
  fi
  if [ -z "$in_local$in_sshnpd" ]; then
    return
  fi
  dirs=''
  echo "Error: install.sh $1 $2 writes to these, which $user does not own:"
  if [ -n "$in_local" ]; then
    echo "$in_local"
    dirs=" $(quote "$user_home/.local")"
  fi
  if [ -n "$in_sshnpd" ]; then
    echo "$in_sshnpd"
    dirs="$dirs $(quote "$user_sshnpd_dir")"
  fi
  echo "To clean up an earlier install as root, run:"
  echo "  sudo sh -c 'crontab -l | grep -v -F -- \"\$1\" | crontab -' sh $(quote "$script")"
  echo "  sudo chown -R -h $(quote "$user")$dirs"
  if [ -e "$script" ]; then
    echo "then copy any settings you need from $script and remove it with:"
    echo "  rm -f $(quote "$script")"
  fi
  echo "and run install.sh again."
  exit 1
}

# USAGE #

usage() {
  if [ -z "$arg_zero" ]; then
    arg_zero='install.sh'
  fi
  echo "$arg_zero [...options] [command]"
  echo "Available commands:"
  echo "atsc            - install atsc, which the commands below run"
  echo "at_activate     - install at_activate"
  echo "npt             - install npt"
  echo "sshnp           - install sshnp"
  echo "sshnpd          - install sshnpd"
  echo "srv             - install srv"
  echo "srvd            - install srvd"
  echo "binaries        - install all base binaries (everything above)"
  echo ""
  echo "debug_srvd      - install srvd with debugging enabled, as debug_srvd"
  echo "debug           - install all debug binaries"
  echo ""
  echo "all             - install all binaries (everything above)"
  if ! is_darwin; then
    echo ""
    echo "systemd <unit>  - install a systemd unit"
    echo "                  available units: [sshnpd, srvd]"
  fi
  if is_darwin; then
    echo ""
    echo "launchd <unit>  - install a launchd unit"
    echo "                  available units: [sshnpd]"
  fi
  echo ""
  echo "headless <job>  - install a headless cron job"
  echo "                  available jobs: [sshnpd, srvd]"
  echo ""
  echo "tmux <service>  - install a service in a tmux session"
  echo "                  available services: [sshnpd, srvd]"
  echo ""
  echo "Options:"
  echo "-b <dir>        - override the directory in which the binaries are written to"
  echo "-u <username>   - override the user to install the binaries for"
}

# SETUP AUTHORIZED KEYS #

# Prints $1 quoted for the shell.
quote() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

setup_authorized_keys() {
  if is_root && [ "$user" != root ]; then
    # NOTE steps in another account's home run as that account
    if ! sudo -H -u "$user" sh -c 'umask "$1" && mkdir -p "$HOME/.ssh" && touch "$HOME/.ssh/authorized_keys" && chmod 644 "$HOME/.ssh/authorized_keys"' sh "$(umask)"; then
      echo "Error: could not set up ~/.ssh/authorized_keys as $user"
      echo "Make $user the owner of its ~/.ssh with:"
      echo "  sudo chown -h $(quote "$user") $(quote "$user_home/.ssh")"
      echo "then, if $user does not own the authorized_keys in it, replace that file with a copy $user owns:"
      echo "  sudo -H -u $(quote "$user") sh -c 'cd ~/.ssh && cp authorized_keys authorized_keys.new && mv authorized_keys.new authorized_keys'"
      echo "and run install.sh again."
      exit 1
    fi
    return
  fi
  if ! { mkdir -p "$user_ssh_dir" && touch "$user_ssh_dir/authorized_keys" && chmod 644 "$user_ssh_dir/authorized_keys"; }; then
    echo "Error: could not set up $user_ssh_dir/authorized_keys"
    exit 1
  fi
}

# INSTALL BINARIES #

# The directory that programs are installed into.
install_dir() {
  if [ -n "$binary_dir" ]; then
    printf '%s\n' "$binary_dir"
  elif is_root; then
    printf '%s\n' "$bin_dir"
  else
    printf '%s\n' "$user_bin_dir"
  fi
}

# Whether the files $1 and $2 both exist with the same contents.
same_contents() {
  if ! [ -f "$1" ] || ! [ -f "$2" ]; then
    return 1
  fi
  if command -v cmp >/dev/null 2>&1; then
    cmp -s "$1" "$2"
  else
    [ "$(cksum <"$1")" = "$(cksum <"$2")" ]
  fi
}

# Installs $2 (default $1) from this bundle as $1.
install_single_binary() {
  src="$script_dir/${2:-$1}"
  dest=$(install_dir)
  mkdir -p "$dest"
  if ! [ -L "$dest/$1" ] && same_contents "$src" "$dest/$1"; then
    if ! chmod 755 "$dest/$1"; then
      echo "Failed to make $dest/$1 readable and executable by all - aborting"
      exit 1
    fi
    echo "=> $dest/$1 is already up to date"
  else
    replace_binary "$1"
  fi
  if is_root; then
    chown -h root:wheel "$dest/$1" 2>/dev/null || chown -h root:root "$dest/$1" 2>/dev/null || chown -h root "$dest/$1" 2>/dev/null
  fi
}

# Installs $src as $dest/$1 by copying it into $dest and renaming the copy
# over $dest/$1, after keeping a copy of the file it replaces as $1.old. A
# link it replaces points into another installation, so it keeps no copy.
replace_binary() {
  new="$dest/.$1.new.$$"
  if ! cp -f "$src" "$new" || ! chmod 755 "$new"; then
    rm -f "$new"
    echo "Failed to copy $src to $dest - aborting, $dest/$1 is unchanged"
    exit 1
  fi
  if [ -f "$dest/$1" ] && ! [ -L "$dest/$1" ]; then
    if ! rm -f "$dest/$1.old" || ! cp -p "$dest/$1" "$dest/$1.old"; then
      rm -f "$new"
      echo "Failed to copy $dest/$1 to $dest/$1.old - aborting, $dest/$1 is unchanged"
      exit 1
    fi
    echo "=> Copied existing binary $dest/$1 to $dest/$1.old"
  fi
  if ! mv -f "$new" "$dest/$1"; then
    rm -f "$new"
    echo "Failed to rename $new to $dest/$1 - aborting, $dest/$1 is unchanged"
    exit 1
  fi
  echo "=> Installed $1 to $dest"
}

# Installs the program $1, with the atsc it runs and, if it needs one, srv.
install_program() {
  install_single_binary "atsc"
  case "$1" in
  sshnp | sshnpd | npt) install_single_binary "srv" ;;
  esac
  install_single_binary "$1"
}

install_base_binaries() {
  install_program "at_activate"
  install_program "sshnp"
  install_program "sshnpd"
  install_program "srvd"
  install_program "npt"
}

# Installs the debug build of the program $1 as debug_$1, with debug_atsc.
install_debug_binary() {
  install_single_binary "debug_atsc" "debug/atsc"
  install_single_binary "debug_$1" "debug/$1"
}

install_debug_binaries() {
  install_debug_binary "srvd"
}

install_all_binaries() {
  install_base_binaries
  install_debug_binaries
}

# SYSTEMD #

post_systemd_message() {
  echo "Systemd unit installed, make sure to configure the unit by editing"
  echo "the override.conf using:"
  echo "  sudo systemctl edit $unit_name"
  echo ""
  echo "Learn more in $script_dir/systemd/README.md"
  echo ""
  echo "To enable the service on next boot:"
  echo "  sudo systemctl enable $unit_name"
  echo ""
  echo "To start the service immediately:"
  echo "  sudo systemctl start $unit_name"
}

install_systemd_unit() {
  unit_name="$1"
  systemd_unit="$systemd_dir/$unit_name"
  systemd_config="$systemd_unit.d/override.conf"
  if ! [ -d "$systemd_unit.d" ]; then
    mkdir -p "$systemd_unit.d"
  fi
  no_mac
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
    echo "sshnpd configuration migrated to override.conf"
  else
    cp "$script_dir/systemd/$unit_name" "$systemd_unit"
  fi
  if [ -f "$systemd_config" ]; then
    echo "systemd config already in place"
  else
    cp "$script_dir/systemd/$unit_name.d/override.conf" "$systemd_config"
  fi
  systemctl daemon-reload
  post_systemd_message
}

systemd() {
  if is_darwin; then
    echo "systemd is not supported on MacOS"
    usage
    exit 1
  fi
  case "$1" in
  --help)
    usage
    exit 0
    ;;
  sshnpd | srvd) root_only ;;
  *)
    echo "Unknown systemd unit: $1"
    usage
    exit 1
    ;;
  esac
  if $checking; then
    return
  fi
  install_program "$1"
  install_systemd_unit "$1.service"
  setup_authorized_keys
}

# LAUNCHD SERVICES #
post_launchd_message() {
  echo "Launchd unit installed, make sure to configure the unit by editing $dest"
  echo ""
  echo "To enable the service see \"Login Items\" in settings"
}

install_launchd_unit() {
  unit_name="$1"
  mac_only
  mkdir -p "$launchd_dir"
  dest="$launchd_dir/$unit_name"
  if [ -f "$dest" ]; then
    echo "launchd config already in place"
  else
    cp "$script_dir/launchd/$unit_name" "$dest"
  fi
  post_launchd_message
}

launchd() {
  if ! is_darwin; then
    echo "Unknown command: launchd"
    usage
    exit 1
  fi
  case "$1" in
  --help)
    usage
    exit 0
    ;;
  sshnpd) ;;
  *)
    echo "Unknown launchd unit: $1"
    usage
    exit 1
    ;;
  esac
  if $checking; then
    return
  fi
  install_program "sshnpd"
  install_launchd_unit "com.atsign.sshnpd.plist"
  setup_authorized_keys
}

# HEADLESS SERVICES #

post_headless_message() {
  echo "Headless job installed, make sure to configure the job by editing $dest"
  echo "Learn more in $script_dir/headless/README.md"
  echo ""
  echo "The job will start upon next system boot"
  echo "To start the job immediately:"
  echo "  $command &"
  echo ""
  echo "Warning: logs stored at $log_file and $err_file have unlimited potential size"
  echo "In a production environment, it's recommended that you install via systemd"
  echo "or use a cron job to call logrotate on these log files if systemd is not available"
}

# Points the job script $1 at the directory the programs were installed into.
set_binary_path() {
  dir=$(CDPATH='' cd -- "$(install_dir)" && pwd | sed 's/[\\&|]/\\&/g')
  sedi "s|^binary_path=\".*\"$|binary_path=\"$dir\"|g" "$1"
}

install_headless_job() {
  job_name=$1
  mkdir -p "$user_bin_dir"
  mkdir -p "$user_log_dir"

  dest="$user_bin_dir/$job_name.sh"
  if ! [ -f "$dest" ]; then
    cp "$script_dir/headless/$job_name.sh" "$dest"
  fi
  set_binary_path "$dest"

  log_file="$user_sshnpd_dir/logs/$job_name.log"
  err_file="$user_sshnpd_dir/logs/$job_name.err"

  command="nohup $dest > $log_file 2> $err_file"
  cron_entry="@reboot $command"
  crontab_contents=$(crontab -l 2>/dev/null)

  if echo "$crontab_contents" | grep -Fxq "$cron_entry"; then
    echo "=> cron job already installed, killing any old $job_name.sh processes"
    pids=$(pgrep "$command")
    if [ -n "$pids" ]; then
      echo "$pids" | xargs kill
    fi
  else
    echo "=> Installing cron job: $cron_entry"
    (
      echo "$crontab_contents"
      echo "$cron_entry"
    ) | crontab -
  fi

  echo ""
  post_headless_message
}

headless() {
  case "$1" in
  --help | '')
    usage
    exit 0
    ;;
  sshnpd | srvd)
    no_root_for_others "headless $1"
    check_job_paths headless "$1"
    ;;
  *)
    echo "Error: Unknown headless job: $1"
    usage
    exit 1
    ;;
  esac
  if $checking; then
    return
  fi
  install_program "$1"
  install_headless_job "$1"
  setup_authorized_keys
}

# TMUX SESSION #

post_tmux_message() {
  # Explain what needs to be edited
  # Provide initial startup command
  echo "tmux service installed, make sure to configure the service by editing $dest"
  echo "Learn more in $script_dir/headless/README.md"
  echo ""
  echo "To start the service immediately:"
  echo "  $command &"
  echo ""
  echo "Warning: sometimes tmux is not set to linger which will kill the tmux session on logout"
  echo "Make sure your system is configured so that tmux sessions can linger, or disown the tmux process before logging out"
}

install_tmux_service() {
  service_name=$1
  mkdir -p "$user_bin_dir"

  dest="$user_bin_dir/$service_name.sh"

  # Only copy the "$service_name".sh script if it's not already there
  if ! [ -f "$dest" ]; then
    cp "$script_dir/headless/$service_name.sh" "$dest"
  fi
  set_binary_path "$dest"

  command="tmux new-session -d -s $service_name && tmux send-keys -t $service_name $dest C-m"
  cron_entry="@reboot $command"
  crontab_contents=$(crontab -l 2>/dev/null)

  if echo "$crontab_contents" | grep -Fxq "$cron_entry"; then
    echo "=> Cron job already installed, will not re-install"
  else
    echo "=> Installing cron job: $cron_entry"
    (
      echo "$crontab_contents"
      echo "$cron_entry"
    ) | crontab -
  fi

  if (command tmux has-session -t "$service_name" 2>/dev/null); then
    echo "=> Found existing tmux session for $service_name - will kill and restart it"
    command tmux kill-session -t "$service_name"
    command tmux new-session -d -s "$service_name" && command tmux send-keys -t "$service_name" "$dest" C-m
  fi

  echo ""
  post_tmux_message
}

tmux() {
  case "$1" in
  --help | '')
    usage
    exit 0
    ;;
  sshnpd | srvd)
    no_root_for_others "tmux $1"
    check_job_paths tmux "$1"
    ;;
  *)
    echo "Unknown tmux service: $1"
    usage
    exit 1
    ;;
  esac
  if $checking; then
    return
  fi
  install_program "$1"
  install_tmux_service "$1"
  setup_authorized_keys
}

add_home_local_bin_to_path() {
  if is_root || [ "$(install_dir)" != "$user_bin_dir" ]; then
    return 0
  fi
  if [ -f "$user_home/.profile" ] &&
    grep 'PATH=' <"$user_home/.profile" | grep -q -e "$user_home/.local/bin" -e '$HOME/.local/bin'; then
    return 0
  fi

  if ! [ -f "$user_home/.profile" ]; then
    touch "$user_home/.profile"
    chown $user:$user "$user_home/.profile" 2>/dev/null || chown $user "$user_home/.profile" 2>/dev/null
  fi

  echo 'Adding $HOME/.local/bin/ to the PATH in ~/.profile'
  echo 'PATH="$PATH:$HOME/.local/bin"' >>"$user_home/.profile"
}

# MAIN #

# Installs the programs that the command $1 names.
install_binaries() {
  case "$1" in
  atsc | srv) install_single_binary "$1" ;;
  at_activate | npt | sshnp | sshnpd | srvd) install_program "$1" ;;
  binaries) install_base_binaries ;;
  debug_srvd) install_debug_binary "srvd" ;;
  debug) install_debug_binaries ;;
  all) install_all_binaries ;;
  esac
}

# Runs the options and commands in the arguments in order. While $checking it
# applies the options and refuses any command that cannot run, installing
# nothing.
run_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
    -h)
      usage
      exit 0
      ;;
    -b)
      binary_dir="$2"
      shift
      ;;
    -u)
      if [ "$2" != "$user" ]; then
        user="$2"
        user_home=$(sudo -H -u "$user" sh -c 'echo $HOME')
        if [ -z "$user_home" ]; then
          echo "Error: could not find the home directory of $user"
          exit 1
        fi
        define_user_paths
      fi
      shift
      ;;
    atsc | srv | at_activate | npt | sshnp | sshnpd | srvd | binaries | debug_srvd | debug | all)
      if ! $checking; then
        install_binaries "$1"
        add_home_local_bin_to_path
      fi
      ;;
    systemd | launchd | headless | tmux)
      command=$1
      shift 1
      $command "$@"
      ;;
    *)
      echo "Unknown command: $1"
      usage
      exit 1
      ;;
    esac
    shift
  done
}

main() {
  arg_zero=$0
  define_env
  checking=true
  run_args "$@"
  checking=false
  run_args "$@"
}

main "$@"
