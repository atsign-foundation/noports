#!/bin/sh

# SYSTEM GIVENS #
is_root() {
  [ "$(id -u)" -eq 0 ]
}

define_env() {
  script_dir="$(dirname -- "$( readlink -f -- "$0"; )")"
  bin_dir="/usr/local/bin"
  systemd_dir="/etc/systemd/system"
  if is_root; then
    user="$SUDO_USER"
    if [ -z "$user" ]; then
      user="root"
    fi
  else
    user="$USER"
  fi
  user_home=$(sudo -u "$user" sh -c 'echo $HOME')
  user_bin_dir="$user_home/.local/bin"
  user_sshnpd_dir="$user_home/.sshnpd"
  user_log_dir="$user_sshnpd_dir/logs"
  user_ssh_dir="$user_home/.ssh"
}

is_darwin() {
  [ "$(uname)" = 'Darwin' ]
}

no_mac() {
  if is_darwin; then
    echo "Error: this operation is only supported on linux"
    exit 1
  fi
}

root_only() {
  if ! is_root; then
    echo "Error: this operation requires root privileges"
    exit 1
  fi
}

# USAGE #

usage() {
  if [ -z "$arg_zero" ]; then
    arg_zero='install.sh'
  fi
  echo "$arg_zero [command]"
  echo "Available commands:"
  echo "at_activate     - install at_activate"
  echo "sshnp           - install sshnp"
  echo "sshnpd          - install sshnpd"
  echo "sshrv           - install sshrv"
  echo "sshrvd          - install sshrvd"
  echo "binaries        - install all base binaries"
  echo ""
  echo "debug_sshrvd    - install sshrvd with debugging enabled"
  echo "debug           - install all debug binaries"
  echo ""
  echo "all             - install all binaries (base and debug)"
  echo ""
  echo "systemd <unit>  - install a systemd unit"
  echo "                  available units: [sshnpd, sshrvd]"
  echo ""
  echo "headless <job>  - install a headless cron job"
  echo "                  available jobs: [sshnpd, sshrvd]"
  echo ""
  echo "tmux <service>  - install a service in a tmux session"
  echo "                  available services: [sshnpd, sshrvd]"
}

# SETUP AUTHORIZED KEYS #

setup_authorized_keys() {
  mkdir -p "$user_ssh_dir"
  touch "$user_ssh_dir/authorized_keys"
  chmod 644 "$user_ssh_dir/authorized_keys"
}

# INSTALL BINARIES #

install_single_binary() {
  if is_root; then
    dest="$bin_dir"
  else
    dest="$user_bin_dir"
  fi
  mkdir -p "$dest"
  cp "$script_dir/$1" "$dest/$1"
  echo "Installed $1 to $dest"
  if is_root & ! [ -f "$user_bin_dir/$1" ] ; then
    mkdir -p "$user_bin_dir"
    ln -sf "$dest/$1" "$user_bin_dir/$1"
    echo "Linked $user_bin_dir/$1 to $dest"
  fi
}

install_base_binaries() {
  install_single_binary "at_activate"
  install_single_binary "sshnp"
  install_single_binary "sshnpd"
  install_single_binary "sshrv"
  install_single_binary "sshrvd"
}

install_debug_binary() {
  if is_root; then
    dest="$bin_dir"
  else
    dest="$user_bin_dir"
  fi
  mkdir -p "$dest"
  cp "$script_dir/debug/$1" "$bin_dir/debug_$1"
  echo "Installed debug_$1 to $dest"
}

install_debug_binaries() {
  install_debug_binary "sshrvd"
}

install_all_binaries() {
  install_base_binaries
  install_debug_binaries
}

# SYSTEMD #

post_systemd_message() {
  echo "Systemd unit installed, make sure to configure the unit by editing $dest"
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
  no_mac
  mkdir -p "$systemd_dir"
  dest="$systemd_dir/$unit_name"
  cp "$script_dir/systemd/$unit_name" "$dest"
  post_systemd_message
}

install_systemd_sshnpd() {
  root_only
  install_single_binary "sshnpd"
  install_single_binary "sshrv"
  install_systemd_unit "sshnpd.service"
}

install_systemd_sshrvd() {
  root_only
  install_single_binary "sshrvd"
  install_systemd_unit "sshrvd.service"
}

systemd() {
  case "$1" in
    --help) usage; exit 0;;
    sshnpd) install_systemd_sshnpd;;
    sshrvd) install_systemd_sshrvd;;
    *)
      echo "Unknown systemd unit: $1";
      usage;
      exit 1;
  esac
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

install_headless_job() {
  job_name=$1
  mkdir -p "$user_bin_dir"
  mkdir -p "$user_log_dir"
  if is_root; then
    dest="$user_bin_dir/root_$job_name.sh"
  else
  dest="$user_bin_dir/$job_name.sh"
  fi
  if ! [ -f "$dest" ]; then
    cp "$script_dir/headless/$job_name.sh" "$dest"
  fi

  log_file="$user_sshnpd_dir/logs/$job_name.log"
  err_file="$user_sshnpd_dir/logs/$job_name.err"

  command="nohup $dest > $log_file 2> $err_file"
  cron_entry="@reboot $command"
  crontab_contents=$(crontab -l 2>/dev/null)

  if echo "$crontab_contents" | grep -Fxq "$cron_entry"; then
    echo "cron job already installed, killing any old $job_name.sh processes"
    pids=$(pgrep "$command")
    if [ -n "$pids" ]; then
     echo "$pids" | xargs kill
    fi
  else
     echo "Installing cron job: $cron_entry"
    (echo "$crontab_contents"; echo "$cron_entry") | crontab -;
  fi

  echo ""
  post_headless_message
}

install_headless_sshnpd() {
  install_single_binary "sshnpd"
  install_single_binary "sshrv"
  install_headless_job "sshnpd"
}

install_headless_sshrvd() {
  install_single_binary "sshrvd"
  install_headless_job "sshrvd"
}

headless() {
  case "$1" in
    --help|'') usage; exit 0;;
    sshnpd) install_headless_sshnpd;;
    sshrvd) install_headless_sshrvd;;
    *)
      echo "Unknown headless job: $1";
      usage;
      exit 1;
  esac
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
  if is_root; then
    dest="$user_bin_dir/root_$service_name.sh"
  else
  dest="$user_bin_dir/$service_name.sh"
  fi

  if ! [ -f "$dest" ]; then
    cp "$script_dir/headless/$service_name.sh" "$dest"
  fi

  command="tmux new-session -d -s $service_name && tmux send-keys -t $service_name $dest C-m"
  cron_entry="@reboot $command"
  crontab_contents=$(crontab -l 2>/dev/null)

  if echo "$crontab_contents" | grep -Fxq "$cron_entry"; then
    echo "cron job already installed, killing old tmux session"
    tmux kill-session -t "$service_name"
  else
    echo "Installing cron job: $cron_entry"
    (echo "$crontab_contents"; echo "$cron_entry") | crontab -;
  fi

  echo ""
  post_tmux_message
}

install_tmux_sshnpd() {
  install_single_binary "sshnpd"
  install_single_binary "sshrv"
  install_tmux_service "sshnpd"
}

install_tmux_sshrvd() {
  install_single_binary "sshrvd"
  install_tmux_service "sshrvd"
}

tmux() {
  case "$1" in
    --help|'') usage; exit 0;;
    sshnpd) install_tmux_sshnpd;;
    sshrvd) install_tmux_sshrvd;;
    *)
      echo "Unknown tmux service: $1";
      usage;
      exit 1;
  esac
  setup_authorized_keys
}

# MAIN #

main() {
  arg_zero=$0

  define_env

  case "$1" in
    --help|'') usage; exit 0;;
    at_activate|sshnp|sshnpd|sshrv|sshrvd) install_single_binary "$1";;
    binaries) install_base_binaries;;
    debug_sshrvd) install_debug_sshrvd;;
    debug) install_debug_binaries;;
    all) install_all_binaries;;
    systemd|headless|tmux)
      command=$1;
      shift 1;
      $command "$@";
    ;;
    *)
      echo "Unknown command: $1";
      usage;
      exit 1;
  esac
}

main "$@"