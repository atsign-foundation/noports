#!/bin/sh

define_env() {
  script_dir="$(dirname -- "$( readlink -f -- "$0"; )")"
  bin_dir="/usr/local/bin"
  systemd_dir="/etc/systemd/system"
}

usage() {
  true
}

make_bin_dir() {
  mkdir -p "$bin_dir"
}

install_at_activate() {
  make_bin_dir
  cp "$script_dir/at_activate" "$bin_dir/at_activate"
}

install_sshnp() {
  make_bin_dir
  cp "$script_dir/sshnp" "$bin_dir/sshnp"
}

install_sshnpd() {
  make_bin_dir
  cp "$script_dir/sshnpd" "$bin_dir/sshnpd"
}

install_sshrv() {
  make_bin_dir
  cp "$script_dir/sshrv" "$bin_dir/sshrv"
}

install_sshrvd() {
  make_bin_dir
  cp "$script_dir/sshrvd" "$bin_dir/sshrvd"
}

install_binaries() {
  install_at_activate
  install_sshnp
  install_sshnpd
  install_sshrv
  install_sshrvd
}

install_debug_sshrvd() {
  make_debug_dir
  cp "$script_dir/debug/sshrvd" "$bin_dir/sshrvd-debug"
}

install_debug_binaries() {
  install_debug_sshrvd
}

install_all_binaries() {
  install_binaries
  install_debug_binaries
}

linux_only() {
  if [ "$(uname)" = 'Darwin' ]; then
    echo "Error: this operation is only supported on linux"
    exit 1
  fi
}

root_only() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "Error: this operation requires root privileges"
    exit 1
  fi
}

install_systemd_sshnpd() {
  linux_only
  root_only
  install_sshnpd
  install_sshrv
  dest="$systemd_dir/sshnpd.service"
  cp "$script_dir/systemd/sshnpd.service" "$dest"
  echo "Unit installed, make sure to configure the unit by editing $dest"
  echo "Learn more in $script_dir/systemd/README.md"
}

install_systemd_sshrvd() {
  linux_only
  root_only
  install_sshrvd
  dest="$systemd_dir/sshrvd.service"
  cp "$script_dir/systemd/sshrvd.service" "$dest"
  echo "Unit installed, make sure to configure the unit by editing $dest"
  echo "Learn more in $script_dir/systemd/README.md"
}

systemd() {
  case "$1" in
    sshnpd) install_systemd_sshnpd;;
    sshrvd) install_systemd_sshrvd;;
  esac
}

install_headless_sshnpd() {
  true
}

install_headless_sshrvd() {
  true
}

headless() {
  case "$1" in
    sshnpd) install_headless_sshnpd;;
    sshrvd) install_headless_sshrvd;;
  esac
}

install_tmux_sshnpd() {
  true
}

install_tmux_sshrvd() {
  true
}

tmux() {
  case "$1" in
    sshnpd) install_tmux_sshnpd;;
    sshrvd) install_tmux_sshrvd;;
  esac
}

main() {
  if [ $# -lt 1 ]; then
    usage
    exit 0
  fi

  define_env

  case "$1" in
    --help) usage;;
    at_activate) install_at_activate;;
    sshnp) install_sshnp;;
    sshnpd) install_sshnpd;;
    sshrv) install_sshrv;;
    sshrvd) install_sshrvd;;
    binaries) install_binaries;;
    debug) install_debug_binaries;;
    all) install_all_binaries;;
    systemd) systemd "$2";;
    headless) headless "$2";;
    tmux) tmux "$2";;
  esac
}

main "$@"