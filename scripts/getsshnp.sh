#!/bin/bash

BINARY_NAME="sshnp";

norm_atsign() {
  KEY="$1" # Get the variable name
  INPUT=${!KEY} # Get the value of the variable
  shopt -s extglob
  ATSIGN=${INPUT/#?(\@)/\@} # Add @ if missing
  shopt -u extglob
  export "${KEY}"="$ATSIGN" # Set the variable to new value
}

usage() {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  -f, --from <address>    (mandatory)  Client address"
  echo "  -t, --to <address>      (mandatory)  Device manager address"
  echo "  -h, --host <region>     (mandatory)  Default host rendezvous region code (am, eu, ap)"
  echo "  -l, --local <path>                   Install using local zip/tgz"
  echo "  -d, --dev <path>                     Install using local repo"
  echo "      --help                           Display this help message"
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
    --help)
      usage
      exit 0
    ;;
    -l|--local)
      if [ $# -lt 0 ]; then
        echo "Missing argument for $1";
        exit 1;
      fi
      SSHNP_LOCAL="$2"
      shift 2
    ;;
    -d|--dev)
      if [ $# -lt 0 ]; then
        echo "Missing argument for $1";
        exit 1;
      fi
      SSHNP_DEV_MODE="$2"
      shift 2
    ;;
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
  done

  if [ -z "$CLIENT_ATSIGN" ]; then
    read -rp "Client address: " CLIENT_ATSIGN;
  fi

  if [ -z "$DEVICE_MANAGER_ATSIGN" ]; then
    read -rp "Device manager address: " DEVICE_MANAGER_ATSIGN;
  fi

  if [ -z "$HOST_RENDEZVOUS_ATSIGN" ]; then
    echo Pick your default region:
    echo am: Americas
    echo ap: Asia Pacific
    echo eu: Europe
    read -rp "region: " HOST_RENDEZVOUS_ATSIGN;
  fi

  while [[ "$HOST_RENDEZVOUS_ATSIGN" != @rv_* ]]; do
    case "$HOST_RENDEZVOUS_ATSIGN" in
    [Aa][Mm]*)
      HOST_RENDEZVOUS_ATSIGN="@rv_am"
      ;;
    [Ee][Uu]*)
      HOST_RENDEZVOUS_ATSIGN="@rv_eu"
      ;;
    [Aa][Pp]*)
      HOST_RENDEZVOUS_ATSIGN="@rv_ap"
      ;;
    esac
    if [[ "$HOST_RENDEZVOUS_ATSIGN" != @rv_* ]]; then
      echo "Invalid region: $HOST_RENDEZVOUS_ATSIGN"
      read -rp "region: " HOST_RENDEZVOUS_ATSIGN;
    fi
  done
  echo;

  norm_atsign CLIENT_ATSIGN
  norm_atsign DEVICE_MANAGER_ATSIGN
}

parse_env() {
  if [ -z "$SSHNP_USER" ]; then
    SSHNP_USER="$USER";
  fi
  HOME_PATH=$(eval echo "~$SSHNP_USER");

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
           "$HOME_PATH/.local/bin";
}

download() {
  if [ -n "$SSHNP_LOCAL" ]; then
    echo "DEV MODE: Installing using local $EXT file: $SSHNP_LOCAL";
    cp "$SSHNP_LOCAL" "$HOME_PATH/.atsign/temp/$BINARY_NAME.$EXT";
  else
    echo "Downloading $BINARY_NAME from $DOWNLOAD";
    curl -sL "$DOWNLOAD" -o "$HOME_PATH/.atsign/temp/$BINARY_NAME.$EXT";
  fi

  case "$EXT" in
  zip)
    unzip -qo "$HOME_PATH/.atsign/temp/$BINARY_NAME.$EXT" -d "$HOME_PATH/.atsign/temp";
    ;;
  tgz|tar.gz)
    tar -zxvf "$HOME_PATH/.atsign/temp/$BINARY_NAME.$EXT" -C "$HOME_PATH/.atsign/temp/";
    ;;
  esac
  if [ -n "$SSHNP_DEV_MODE" ]; then
    echo "DEV MODE: Installing from local repo: $SSHNP_DEV_MODE";
    cp -R "$SSHNP_DEV_MODE/templates" "$HOME_PATH/.atsign/temp/$BINARY_NAME/";
    cp -R "$SSHNP_DEV_MODE/scripts/" "$HOME_PATH/.atsign/temp/$BINARY_NAME/";
  fi
}

# Place the actual sshnp binary
setup_main_binaries() {
  MAIN_BINARIES="$BINARY_NAME at_activate sshrv update_sshnp";
  for binary in $MAIN_BINARIES; do
    mv "$HOME_PATH/.atsign/temp/$BINARY_NAME/$binary" "$HOME_PATH/.local/bin/$binary";
    chmod +x "$HOME_PATH/.local/bin/$binary";
  done
  echo "Installed binaries: $MAIN_BINARIES";
}

# Place custom user based scripts
setup_custom_binary() {
  echo "Installing $BINARY_NAME$DEVICE_MANAGER_ATSIGN to $HOME_PATH/.local/bin/$BINARY_NAME$DEVICE_MANAGER_ATSIGN";
  sed -e "s/\$CLIENT_ATSIGN/$CLIENT_ATSIGN/g" \
      -e "s/\$DEVICE_MANAGER_ATSIGN/$DEVICE_MANAGER_ATSIGN/g" \
      -e "s/\$DEFAULT_HOST_ATSIGN/$HOST_RENDEZVOUS_ATSIGN/g" \
  <"$HOME_PATH/.atsign/temp/$BINARY_NAME/templates/client/sshnp-full.sh" \
  >"$HOME_PATH/.local/bin/$BINARY_NAME$DEVICE_MANAGER_ATSIGN"
  chmod +x "$HOME_PATH/.local/bin/$BINARY_NAME$DEVICE_MANAGER_ATSIGN";
}

post_install() {
  rm -rf "$HOME_PATH/.atsign/temp";
  echo;

  if ! echo "$PATH" | grep -q "$HOME_PATH/.local/bin"; then
    PATH="\$PATH:$HOME_PATH/.local/bin";
    echo "Added $HOME_PATH/.local/bin to your PATH."
    echo "Include the following line in your shell profile to persist across logins:"
    echo "  export PATH=\"\$PATH:$HOME_PATH/.local/bin\""
  fi

  echo; echo "Installation complete!";
}

# Wrapping install steps prevents issues caused by interrupting the download
main () {
  parse_env
  make_dirs
  download

  setup_main_binaries
  setup_custom_binary

  post_install
}

parse_args "$@";
main
