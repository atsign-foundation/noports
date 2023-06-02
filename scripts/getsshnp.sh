#!/bin/bash

BINARY_NAME="sshnp";

norm_atsign() {
  KEY="$1" # Get the variable name
  INPUT=${!KEY} # Get the value of the variable
  # Add @ if missing
  shopt -s extglob
  ATSIGN=${INPUT/#?(\@)/\@}
  shopt -u extglob
  export "${KEY}"="$ATSIGN" # Set the variable to new value
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
    -f|--from)
      if [ $# -lt 0 ]; then
        echo "Missing argument for $1";
        exit 1;
      fi
      CLIENT_ATSIGN="$2"
      shift 2
      ;;
    -t|--to)
      if [ $# -lt 0 ]; then
        echo "Missing argument for $1";
        exit 1;
      fi
      DEVICE_MANAGER_ATSIGN="$2"
      shift 2
      ;;
    -h|--host)
      if [ $# -lt 0 ]; then
        echo "Missing argument for $1";
        exit 1;
      fi
      HOST_RENDEZVOUS_ATSIGN="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
    esac
    shift
  done

  if [ -z "$CLIENT_ATSIGN" ]; then
    echo "Client atSign: ";
    read -r CLIENT_ATSIGN;
  fi

  if [ -z "$DEVICE_MANAGER_ATSIGN" ]; then
    echo "Device manager atSign: ";
    read -r DEVICE_MANAGER_ATSIGN;
  fi

  if [ -z "$HOST_RENDEZVOUS_ATSIGN" ]; then
    echo "Host rendezvous atSign: ";
    read -r HOST_RENDEZVOUS_ATSIGN;
  fi

  norm_atsign CLIENT_ATSIGN
  norm_atsign DEVICE_MANAGER_ATSIGN
  norm_atsign HOST_RENDEZVOUS_ATSIGN
}

parse_env() {
  HOME_PATH=$(eval echo "~$SUDO_USER");

  if [ -z "$SSHNP_VERSION" ]; then
    SSHNP_VERSION="latest";
  fi
  URL="https://api.github.com/repos/atsign-foundation/sshnoports/releases/$SSHNP_VERSION";

  case "$(uname)" in
  Darwin)
    PLATFORM="macos"
    EXT="zip"
    ;;
  Linux)
    PLATFORM="linux"
    EXT="tgz"
    ;;
  *)
    PLATFORM="Unknown"
    ;;
  esac

  if [ "$PLATFORM" == "Unknown" ]; then
    echo "Unsupported platform: $(uname)";
    exit 1;
  fi

  # ARCH includes the dot at the end to avoid conflict between arm and arm64
  case "$(uname -m)" in
  x86_64)
    ARCH="x64."
    ;;
  arm64)
    if [ "$PLATFORM" == "macos" ]; then
      ARCH="arm"
    else
      ARCH="arm64."
    fi
    ;;
  arm)
    ARCH="arm."
    ;;
  riscv64)
    ARCH="riscv64."
    ;;
  *)
    ARCH="Unknown"
    ;;
  esac

  if [ "$ARCH" == "Unknown" ]; then
    echo "Unsupported architecture: $(uname -m)";
    exit 1;
  fi

  DOWNLOADS=$(curl -s "$URL" | grep browser_download_url | cut -d\" -f4);
  DOWNLOAD=$(echo "$DOWNLOADS" | grep "$PLATFORM" | grep "$ARCH" | cut -d\" -f4)
}

make_dirs() {
  mkdir -p "$HOME_PATH/.ssh" \
           "$HOME_PATH/.sshnp" \
           "$HOME_PATH/.atsign/keys" \
           "$HOME_PATH/.atsign/temp" \
           "$HOME_PATH/.local/bin" \
           "/usr/local/bin";

  chown -R "$SUDO_USER" "$HOME_PATH/.ssh" \
                        "$HOME_PATH/.sshnp" \
                        "$HOME_PATH/.atsign" \
                        "$HOME_PATH/.local/bin";

  chmod -R 700 "$HOME_PATH/.local/bin";
  chmod -R 600 "$HOME_PATH/.ssh" \
               "$HOME_PATH/.sshnp" \
               "$HOME_PATH/.atsign/keys";
}

download() {
  echo "Downloading $BINARY_NAME from $DOWNLOAD";
  curl -sL "$DOWNLOAD" -o "$HOME_PATH/.atsign/temp/$BINARY_NAME.$EXT";

  case "$EXT" in
  zip)
    unzip -qo "$HOME_PATH/.atsign/temp/$BINARY_NAME.$EXT" -d "$HOME_PATH/.atsign/temp";
    ;;
  tgz|tar.gz)
    tar -zxvf "$HOME_PATH/.atsign/temp/$BINARY_NAME.$EXT" -C "$HOME_PATH/.atsign/temp/";
    ;;
  esac
}

# Place user based scripts locally
setup_local() {
  echo "Installing $BINARY_NAME$DEVICE_MANAGER_ATSIGN to $HOME_PATH/.local/bin/$BINARY_NAME$DEVICE_MANAGER_ATSIGN";
  sed -e "s/\$CLIENT_ATSIGN/$CLIENT_ATSIGN/g" \
      -e "s/\$DEVICE_MANAGER_ATSIGN/$DEVICE_MANAGER_ATSIGN/g" \
      -e "s/\$DEFAULT_HOST_ATSIGN/$HOST_RENDEZVOUS_ATSIGN/g" \
  <"$HOME_PATH/.atsign/temp/$BINARY_NAME/templates/client/sshnp-full.sh" \
  >"$HOME_PATH/.local/bin/$BINARY_NAME$DEVICE_MANAGER_ATSIGN"
  chmod +x "$HOME_PATH/.local/bin/$BINARY_NAME$DEVICE_MANAGER_ATSIGN";
}

# Place the actual sshnp binary for global access
setup_global() {
  GLOBAL_BINARIES="$BINARY_NAME at_activate";
  for binary in $GLOBAL_BINARIES; do
    echo "Installing $binary to /usr/local/bin/$binary";
    mv "$HOME_PATH/.atsign/temp/$BINARY_NAME/$binary" "/usr/local/bin/$binary";
    chmod +x "/usr/local/bin/$binary";
  done
}

cleanup() {
  rm -rf "$HOME_PATH/.atsign/temp";
}

post_install() {
  echo "$BINARY_NAME installed."
}

# Wrapping install steps prevents issues caused by interrupting the download
main () {
  if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root";
    exit 1;
  fi
  parse_env
  make_dirs
  download

  setup_local
  setup_global

  cleanup
  post_install
}

parse_args "$@";
main
