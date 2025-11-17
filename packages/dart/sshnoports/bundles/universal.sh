#!/bin/sh
# shellcheck disable=SC2034
# Version specific information
version='v5.13.0'
macos_arm64_sha='83ca40f17c7bfc0d873f810e41b1cd8ab9fc290ac38a3ef38ecd11f396742df6'
macos_x64_sha='69500b83cce4fa460569dae0e2e5a1ad225d2454a421c823b22379acbcdae223'
linux_arm64_sha='896f1d23d96d8de71853f6e2b24e33c4e8c4837bab0c9560932abc5cc7741f7a'
linux_x64_sha='8598e0e07cc82bb22982139477e3310080eb7634d738cd60453c676ea97f66fd'
linux_arm_sha='ddfee0fe2fbb9f7b055a2e29a77e8d4cacd8b816893602127514212a1e6d3611'
linux_riscv64_sha='182859c58883070d8873a1efd962592f792e2852c2f450ffa3f26cc86c4e39e8'

# N.B. Be careful about the formatting in the above lines.
# They are automatically updated by: .github/workflows/multibuild.yaml

GREP_COLOR=never
unset GREP_OPTIONS

repo_url="https://github.com/atsign-foundation/noports"

unset os
unset ext
unset arch
unset download_url
unset download_path
unset download_sha
unset extract_path
unset user_home

parse_environment() {
  # Get the os
  case "$(uname)" in 
    Darwin) os='macos'; ext='zip';
      user_home="/Users/$SUDO_USER";;
    Linux) os='linux'; ext='tgz';
      user_home="$SUDO_HOME";;
    *)
      >&2 echo "Detected an unsupported platform: $(uname)"
      >&2 echo "Please open an issue at: $repo_url"
      >&2 echo "and provide the following information: $(uname -a)"
      exit 1
  esac

  # Get the architecture
  case "$(uname -m)" in
    x86_64 | amd64 | x64)
      arch="x64"
      ;;
    arm64 | aarch64)
      arch="arm64"
      ;;
    arm | armv7l)
      arch="arm"
      ;;
    riscv64)
      arch="riscv64"
      ;;
    *)
      >&2 echo "Detected an unsupported architecture: $(uname -m)"
      >&2 echo "Please open an issue at: $repo_url"
      >&2 echo "and provide the following information: $(uname -a)"
      exit 1
      ;;
  esac

  # compute urls, shas, and paths
  download_url="https://github.com/atsign-foundation/noports/releases/download/${version}/sshnp-${os}-${arch}.${ext}";

  version_sha="$(echo ${version}-${os}-${arch}| sha1sum - | cut -d' ' -f1)";
  download_path="/tmp/noports-$version_sha.$ext";
  extract_path="/tmp/noports-$version_sha"

  download_sha="$(eval "echo \${${os}_${arch}_sha}")"
}

# Function to download the release
download() {
  if command -v curl >/dev/null 2>&1; then
    curl -sSfL "$download_url" -o "$download_path";
  elif command -v wget >/dev/null 2>&1; then
    wget "$download_url" -q -O "$download_path";
  else
    >&2 echo;
    >&2 echo "Couldn't find curl or wget to download package";
    >&2 echo "Please install one of them";
    >&2 echo "Also how did you download this script???";
    >&2 echo;
    exit 1;
  fi
}

extract() {
  case "$ext" in
    zip)
    command -v unzip >/dev/null 2>&1 || {
      >&2 echo "ERROR: unzip not found";
      >&2 echo "Please install unzip and make it available on the PATH";
      exit 1;
    };
  unzip -qo "$download_path" -d "$extract_path";
      ;;
    tgz)
    command -v tar >/dev/null 2>&1 || {
      >&2 echo "ERROR: tar not available";
      >&2 echo "Please install tar and make it available on the PATH";
      exit 1;
    };
    mkdir -p "$extract_path";
    tar -zxf "$download_path" -C "$extract_path";
      ;;
  esac
}

artifact() {
  cp "$extract_path/$1" "$2"
}

binary() {
  dst="/usr/local/bin/$(basename "$1")"
  artifact "$1" "$dst"
  chmod 755 "$dst"
}

service() {
  case "$os" in
    macos)
      service_base="$user_home/Library/LaunchAgents"
      [ -d "$user_home/Library/Services" ] && service_base="$user_home/Library/Services"
      dst="$service_base/$(basename "$1")"
      [ -f "$dst" ] && mv "$dst" "${dst}.old"
      cp "$extract_path/$1" "$dst"
      chown "$SUDO_USER:$SUDO_USER" "$dst"
      ;;
    linux)
      dst="/etc/systemd/system/$(basename "$1")"
      [ -f "$dst" ] && mv "$dst" "${dst}.old"
      cp "$extract_path/$1" "$dst"
      ;;
  esac
}

print_macos() {
    cat <<EOF
NoPorts Daemon installed to: ~/Library/Services/com.atsign.sshnpd.plist
To edit the configuration:

  textedit "~/Library/Application Support/NoPorts/sshnpd.yaml"

The service can be enabled or disabled from System Settings under the "Login Items" menu.
EOF
}

print_linux() {
  cat <<EOF
NoPorts Daemon installed to: /etc/systemd/system/sshnp.service
To edit the configuration:

  sudo nano /etc/noports/sshnpd.yaml

Once configured, the following commands can be used to manage the service.
Enable/disable automatic startup:

  systemctl enable sshnpd
  systemctl disable sshnpd

Immediately start/stop/restart the service:

  systemctl start sshnpd
  systemctl stop sshnpd
  systemctl restart sshnpd

View status/logs:

  systemctl status sshnpd
  journalctl -u sshnpd
EOF
}

arg_zero="$0"

main() {
  # Ensure this script is only executed as root.
  [ "$(id -u)" -ne 0 ] && {
    command -v sudo >/dev/null 2>&1 || {
      echo "sudo command not found, please manually re-run this installer as root.";
        exit 1;
      };
    sudo "$arg_zero" "$@"
    exit $?;
  };
  # Root operations begin here
  set -eu;

  # Flag parsing
  for arg in "$@"; do
    [ "$arg" = '-q' ] || [ "$arg" = '--quiet' ] && {
      exec>/dev/null;
    }
    [ "$arg" = '-v' ] || [ "$arg" = '--verbose' ] && {
      set -x;
    }
  done


  echo Setting up the installation environment
  parse_environment

  echo Checking for a cached archive download
  [ "$(sha256sum "$download_path" | cut -d' ' -f1)" = "$download_sha" ] || {
    echo "Downloading the release archive to $download_path"
    download;
  }

  echo Verifying archive download checksum
  [ "$(sha256sum "$download_path" | cut -d' ' -f1)" = "$download_sha" ] || {
    echo "Release archive checksum failed."
    rm "$download_path"
    exit 1
  }

  echo Extracting the downloaded archive to "$extract_path"
  extract
  mkdir -p /usr/local/bin

  echo Installing the binaries
  binary "sshnp/at_activate"
  binary "sshnp/srv"
  binary "sshnp/npt"
  binary "sshnp/sshnp"
  binary "sshnp/sshnpd"
  binary "sshnp/srvd"
  binary "sshnp/npp_atserver"
  binary "sshnp/npp_file"
  binary "sshnp/npa_file"

  echo Installing the service and config file
  [ "$os" = 'macos' ] && {
    service "sshnp/launchd/com.atsign.sshnpd.plist"
    artifact "sshnp/config/sshnpd.yaml" \
      "$user_home/Library/Application Support/Noports/sshnpd.yaml"
    chown "$SUDO_USER:$SUDO_USER" "$user_home/Library/Application Support/Noports/sshnpd.yaml"
    print_macos
  }

  [ "$os" = 'linux' ] && {
    service "sshnp/systemd/sshnpd.service"
    artifact "sshnp/config/sshnpd.yaml" \
      "/etc/noports/sshnpd.yaml"
    print_linux
  }
 
  exit 0;
}

main "$@"
