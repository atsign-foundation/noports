#!/bin/bash

BINARY_NAME="sshnpd";

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
  echo "  -c, --client <address>    (mandatory)  Client address"
  echo "  -d, --device <address>    (mandatory)  Device manager address"
  echo "  -n, --name <device name>  (mandatory)  Name of the device"
  echo "  -l, --local <path>                     Install using local zip/tgz"
  echo "  -r, --repo <path>                      Install using local repo"
  echo "      --help                             Display this help message"
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
    -r|--repo)
      if [ $# -lt 0 ]; then
        echo "Missing argument for $1";
        exit 1;
      fi
      SSHNP_DEV_MODE="$2"
      shift 2
    ;;
    -c|--client)
      if [ $# -lt 0 ]; then
        echo "Missing argument for $1";
        exit 1;
      fi
      CLIENT_ATSIGN="$2"
      shift 2
    ;;
    -d|--device)
      if [ $# -lt 0 ]; then
        echo "Missing argument for $1";
        exit 1;
      fi
      DEVICE_MANAGER_ATSIGN="$2"
      shift 2
    ;;
    -n|--name)
      if [ $# -lt 0 ]; then
        echo "Missing argument for $1";
        exit 1;
      fi
      SSHNP_DEVICE_NAME="$2"
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

  if [ -z "$SSHNP_DEVICE_NAME" ]; then
    read -rp "Device name: " SSHNP_DEVICE_NAME;
  fi

  norm_atsign CLIENT_ATSIGN
  norm_atsign DEVICE_MANAGER_ATSIGN
  echo;
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
  rm -rf "$HOME_PATH/.atsign/temp";
  mkdir -p "$HOME_PATH/.ssh/" \
           "$HOME_PATH/.sshnp/logs" \
           "$HOME_PATH/.atsign/keys" \
           "$HOME_PATH/.atsign/temp" \
           "$HOME_PATH/.local/bin";

  if [ ! -f "$HOME_PATH/.ssh/authorized_keys" ]; then
    touch "$HOME_PATH/.ssh/authorized_keys";
    chmod 600 "$HOME_PATH/.ssh/authorized_keys";
  fi
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
    unzip -qo "$HOME_PATH/.atsign/temp/$BINARY_NAME.$EXT" -d "$HOME_PATH/.atsign/temp/";
    ;;
  tgz|tar.gz)
    tar -zxvf "$HOME_PATH/.atsign/temp/$BINARY_NAME.$EXT" -C "$HOME_PATH/.atsign/temp/";
    ;;
  esac
  mv "$HOME_PATH/.atsign/temp/sshnp" "$HOME_PATH/.atsign/temp/$BINARY_NAME"; # Rename the extracted folder

  if [ -n "$SSHNP_DEV_MODE" ]; then
    echo "DEV MODE: Installing from local repo: $SSHNP_DEV_MODE";
    cp -R "$SSHNP_DEV_MODE/templates" "$HOME_PATH/.atsign/temp/$BINARY_NAME/templates";
    cp -R "$SSHNP_DEV_MODE/scripts/" "$HOME_PATH/.atsign/temp/$BINARY_NAME/";
  fi
}

# Place the actual sshnp binary
setup_main_binaries() {
  MAIN_BINARIES="$BINARY_NAME at_activate sshrv update_$BINARY_NAME";
  for binary in $MAIN_BINARIES; do
    mv "$HOME_PATH/.atsign/temp/$BINARY_NAME/$binary" "$HOME_PATH/.local/bin/$binary";
    chmod +x "$HOME_PATH/.local/bin/$binary";
  done
  echo "Installed binaries: $MAIN_BINARIES";
}

# Place custom user based scripts
setup_service() {
  # TODO - Fix this
  # = is used as the delimiter to avoid escaping / in the path
  sed -e "s=\$HOME=$HOME_PATH=g" \
      -e "s/\$1/$DEVICE_MANAGER_ATSIGN/g" \
      -e "s/\$2/$CLIENT_ATSIGN/g" \
      -e "s/\$3/$SSHNP_DEVICE_NAME/g" \
    <"$HOME_PATH/.atsign/temp/$BINARY_NAME/templates/headless/sshnpd.sh" \
    >"$HOME_PATH/.local/bin/$BINARY_NAME$CLIENT_ATSIGN";
    chmod +x "$HOME_PATH/.local/bin/$BINARY_NAME$CLIENT_ATSIGN";

  if command -v tmux; then
    echo "Installing to sshnpd tmux pane"
    COMMAND="tmux send-keys -t  sshnpd $HOME_PATH/.local/bin/$BINARY_NAME$CLIENT_ATSIGN C-m"
    eval "$COMMAND"
    (crontab -l 2>/dev/null; echo "@reboot $COMMAND") | crontab -
  elif command -v screen; then
    echo "Installing to sshnpd screen session"
    COMMAND="screen -dmS sshnpd $HOME_PATH/.local/bin/$BINARY_NAME$CLIENT_ATSIGN"
    eval "$COMMAND"
    (crontab -l 2>/dev/null; echo "@reboot $COMMAND") | crontab -
  else
    echo "Installing as a headless service"
    COMMAND="$BINARY_NAME$CLIENT_ATSIGN"
    (crontab -l 2>/dev/null; echo "* * * * * $COMMAND") | crontab -
  fi
}

post_install() {
  rm -rf "$HOME_PATH/.atsign/temp";
  echo; echo "Installation complete!";
}

# Wrapping install steps prevents issues caused by interrupting the download
main () {
  parse_env
  make_dirs
  download

  setup_main_binaries
  setup_service

  post_install
}

parse_args "$@";
main
