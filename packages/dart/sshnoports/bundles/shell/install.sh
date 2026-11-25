#!/bin/sh

# SYSTEM GIVENS #
is_root() {
  [ "$(id -u)" -eq 0 ]
}

is_darwin() {
  [ "$(uname)" = 'Darwin' ]
}

unset binary_dir
homes=''
user_home=$HOME
# NOTE root's home is read from this file, never from the environment
passwd_file=/etc/passwd
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
      define_root_home
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

# Sets user_home to the home directory in the entry for root, with uid 0, in
# $passwd_file, or stops when there is none. As root, it sets HOME to it too.
define_root_home() {
  user_home=$(while IFS=: read -r name _ uid _ _ home _ || [ -n "$name" ]; do
    if [ "$name" = root ] && [ "$uid" = 0 ]; then
      printf '%s\n' "$home"
      break
    fi
  done <"$passwd_file")
  if [ -z "$user_home" ]; then
    echo "Error: could not find root's home directory in $passwd_file"
    exit 1
  fi
  if is_root; then
    export HOME="$user_home"
  fi
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

# Prints the first of the paths given that exists and is not owned by the
# account running install.sh.
first_not_owned() {
  for entry in "$@"; do
    if [ -e "$entry" ] && ! [ -O "$entry" ]; then
      printf '%s\n' "$entry"
      return
    fi
  done
}

# Prints the first of $1.old, $1.old.2, $1.old.3 and so on that does not exist.
free_old_name() {
  old="$1.old"
  n=1
  while [ -e "$old" ] || [ -L "$old" ]; do
    n=$((n + 1))
    old="$1.old.$n"
  done
  printf '%s\n' "$old"
}

# Prints the command that moves $2 aside and copies it back with $1.
print_move_aside() {
  old=$(free_old_name "$2")
  echo "  mv $(quote "$2") $(quote "$old") && $1 $(quote "$old") $(quote "$2")"
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
  account=$(id -un)
  echo "Error: install.sh $1 $2 writes to these, which $account does not own:"
  if [ -n "$in_local" ]; then
    echo "$in_local"
  fi
  if [ -n "$in_sshnpd" ]; then
    echo "$in_sshnpd"
  fi
  echo "To clean up an earlier install, first have an admin remove its root cron job and stop it with:"
  echo "  sudo sh -c 'crontab -l | grep -v -F -- \"\$1\" | crontab -' sh $(quote "$script")"
  printf '%s\n' "  sudo sh -c 'for p in \$(pgrep -u 0 -f -- \"^[^ ]*sh \$1\\\$\"); do pkill -P \"\$p\"; kill \"\$p\"; done' sh $(quote "$(ere "$script")")"
  echo "then move these aside and copy them back, as $account, with:"
  top=$(first_not_owned "$user_home/.local" "$user_bin_dir")
  if [ -n "$top" ]; then
    print_move_aside 'cp -R' "$top"
  elif [ -n "$in_local" ]; then
    print_move_aside cp "$script"
  fi
  if [ -n "$in_sshnpd" ]; then
    print_move_aside 'cp -R' "$(first_not_owned "$user_sshnpd_dir" "$user_log_dir")"
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
  echo "-b <dir>        - override the directory in which the binaries are written to;"
  echo "                  as root, a directory that only root can change"
  echo "-u <username>   - install for <username>: as root, set up its ~/.ssh/authorized_keys"
  echo "                  for the sshnpd systemd unit; otherwise, install into its ~/.local/bin"
  echo ""
  echo "An option applies to the commands after it, and a command must follow it."
}

# SETUP AUTHORIZED KEYS #

# Prints $1 quoted for the shell.
quote() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

# Prints $1 with a backslash before each character that is special in an
# extended regular expression.
ere() {
  printf '%s\n' "$1" | sed 's/[[\.*^$+?(){|]/\\&/g'
}

setup_authorized_keys() {
  if is_root && [ "$user" != root ]; then
    # NOTE steps in another account's home run as that account
    if ! sudo -H -u "$user" sh -c 'umask "$1" && mkdir -p "$HOME/.ssh" && touch "$HOME/.ssh/authorized_keys" && chmod 644 "$HOME/.ssh/authorized_keys"' sh "$(umask)"; then
      if ! sudo -H -u "$user" sh -c '[ -e "$HOME/.ssh" ] || [ -L "$HOME/.ssh" ]'; then
        echo "Error: $user could not create ~/.ssh; check that $user owns its home directory and can write to it"
        exit 1
      fi
      old=$(sudo -H -u "$user" sh -c 'n=1; old=.ssh.old; while [ -e "$HOME/$old" ] || [ -L "$HOME/$old" ]; do n=$((n + 1)); old=.ssh.old.$n; done; echo "$old"')
      echo "Error: could not set up ~/.ssh/authorized_keys as $user"
      echo "Move $user's ~/.ssh aside, as $user, with:"
      echo "  sudo -H -u $(quote "$user") sh -c 'mv ~/.ssh ~/$old'"
      echo "then run install.sh again, and copy back, as $user, anything in ~/$old that is still needed, such as the keys in ~/$old/authorized_keys."
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

# Prints what is wrong, for root to install into the directory $1, with it:
# that root does not own it, or that its group or others can write to it. When
# $2 is true, $1 is a directory above the one installed into, which can be a
# sticky one of root's, as /tmp is.
dir_problem() {
  ls -ldn -- "$1" | {
    read -r mode _ owner _
    if [ "$owner" != 0 ]; then
      echo "is not owned by root"
      return
    fi
    case "$mode" in
    ?????????[tT]*)
      if $2; then
        return
      fi
      ;;
    esac
    case "$mode" in
    ?????w* | ????????w*) echo "can be written by its group or by others" ;;
    esac
  }
}

# As root, sets binary_dir to the physical path of the -b directory $1, and
# refuses it unless only root can change it and the directories above it. A
# part of it that does not exist yet is checked as the first one that does.
check_binary_dir() {
  if ! is_root; then
    return
  fi
  dir=$1
  rest=''
  while ! [ -d "$dir" ]; do
    rest="/$(basename -- "$dir")$rest"
    dir=$(dirname -- "$dir")
  done
  if ! physical=$(CDPATH='' cd -P -- "$dir" && pwd -P); then
    printf '%s\n' "Error: -b $1: cannot find the directory $dir"
    exit 1
  fi
  dir=$physical
  if [ -n "$rest" ]; then
    binary_dir=${dir%/}$rest
  else
    binary_dir=$dir
  fi
  above=false
  while :; do
    problem=$(dir_problem "$dir" "$above")
    if [ -n "$problem" ]; then
      printf '%s\n' "Error: -b $1: $dir $problem"
      echo "As root, install.sh installs only into a directory that only root can change."
      exit 1
    fi
    if [ "$dir" = / ]; then
      return
    fi
    dir=$(dirname -- "$dir")
    above=true
  done
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
  if [ "$1" = sshnpd ]; then
    setup_authorized_keys
  fi
  install_program "$1"
  install_systemd_unit "$1.service"
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
  setup_authorized_keys
  install_program "sshnpd"
  install_launchd_unit "com.atsign.sshnpd.plist"
}

# HEADLESS SERVICES #

# Prints $command, which starts the job, with HOME set to root's home as root.
start_command() {
  if is_root; then
    printf '%s\n' "HOME=$(quote "$user_home") $command"
  else
    printf '%s\n' "$command"
  fi
}

post_headless_message() {
  echo "Headless job installed, make sure to configure the job by editing $dest"
  echo "Learn more in $script_dir/headless/README.md"
  echo ""
  echo "The job will start upon next system boot"
  echo "To start the job immediately:"
  echo "  $(start_command) &"
  echo ""
  echo "Warning: logs stored at $log_file and $err_file have unlimited potential size"
  echo "In a production environment, it's recommended that you install via systemd"
  echo "or use a cron job to call logrotate on these log files if systemd is not available"
}

# Refuses a -b directory that set_binary_path cannot write into a job script.
check_binary_path() {
  case "$binary_dir" in
  '') return ;;
  /*) dir=$binary_dir ;;
  *) dir="$PWD/$binary_dir" ;;
  esac
  case "$dir" in
  *'"'* | *'$'* | *'`'* | *\\* | *'
'*)
    printf '%s\n' "Error: the directory given with -b cannot contain \", \$, \`, \\ or a newline: $dir"
    exit 1
    ;;
  esac
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
    for p in $(pgrep -u "$(id -u)" -f -- "^[^ ]*sh $(ere "$dest")\$"); do
      pkill -P "$p"
      kill "$p"
    done
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
  --help)
    usage
    exit 0
    ;;
  '')
    usage
    exit 1
    ;;
  sshnpd | srvd)
    no_root_for_others "headless $1"
    check_job_paths headless "$1"
    check_binary_path
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
  if [ "$1" = sshnpd ]; then
    setup_authorized_keys
  fi
  install_program "$1"
  install_headless_job "$1"
}

# TMUX SESSION #

post_tmux_message() {
  # Explain what needs to be edited
  # Provide initial startup command
  echo "tmux service installed, make sure to configure the service by editing $dest"
  echo "Learn more in $script_dir/headless/README.md"
  echo ""
  echo "To start the service immediately:"
  echo "  $(start_command) &"
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
  --help)
    usage
    exit 0
    ;;
  '')
    usage
    exit 1
    ;;
  sshnpd | srvd)
    no_root_for_others "tmux $1"
    check_job_paths tmux "$1"
    check_binary_path
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
  if [ "$1" = sshnpd ]; then
    setup_authorized_keys
  fi
  install_program "$1"
  install_tmux_service "$1"
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

# Sets user_home to the home directory of $user. The checking pass looks it up
# and keeps it in $homes, where the install pass finds it.
find_user_home() {
  if ! $checking; then
    user_home=$(printf '%s\n' "$homes" | while IFS=: read -r name home; do
      if [ "$name" = "$user" ]; then
        printf '%s\n' "$home"
        break
      fi
    done)
    return
  fi
  if [ "$user" = root ]; then
    define_root_home
  else
    if ! command -v sudo >/dev/null 2>&1; then
      echo "Error: could not find the home directory of $user: sudo is not installed"
      exit 1
    fi
    user_home=$(sudo -H -u "$user" sh -c 'echo $HOME')
    if [ -z "$user_home" ] || ! [ -d "$user_home" ]; then
      echo "Error: could not find the home directory of $user"
      exit 1
    fi
  fi
  homes=$(printf '%s\n%s:%s' "$homes" "$user" "$user_home")
}

# Runs the options and commands in the arguments in order. While $checking it
# applies the options and refuses any command that cannot run, installing
# nothing. It refuses an option with no value, or that no command follows.
run_args() {
  unfollowed=''
  while [ $# -gt 0 ]; do
    case "$1" in
    -h)
      usage
      exit 0
      ;;
    -b)
      if [ -z "$2" ]; then
        echo "Error: -b needs a directory"
        exit 1
      fi
      binary_dir="$2"
      check_binary_dir "$2"
      unfollowed=${unfollowed:-"-b $2"}
      shift
      ;;
    -u)
      if [ -z "$2" ]; then
        echo "Error: -u needs an account name"
        exit 1
      fi
      if [ "$2" != "$user" ]; then
        user="$2"
        find_user_home
        define_user_paths
      fi
      unfollowed=${unfollowed:-"-u $2"}
      shift
      ;;
    atsc | srv | at_activate | npt | sshnp | sshnpd | srvd | binaries | debug_srvd | debug | all)
      unfollowed=''
      if ! $checking; then
        install_binaries "$1"
        add_home_local_bin_to_path
      fi
      ;;
    systemd | launchd | headless | tmux)
      unfollowed=''
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
  if [ -n "$unfollowed" ]; then
    printf '%s\n' "Error: $unfollowed is not followed by a command"
    exit 1
  fi
}

main() {
  arg_zero=$0
  define_env
  env_user=$user
  env_user_home=$user_home
  checking=true
  run_args "$@"
  checking=false
  unset binary_dir
  user=$env_user
  user_home=$env_user_home
  define_user_paths
  run_args "$@"
}

main "$@"
