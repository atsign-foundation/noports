#!/bin/bash
USE_INSTALLER=0
if [ "$USE_INSTALLER" = 0 ]; then
  SSHNPD_COMMAND="$HOME/.local/bin/sshnpd -a @sshnpdatsign -m @sshnpatsign -d deviceName -s -u -v"
elif [ "$USE_INSTALLER" = 1 ]; then
    SSHNPD_COMMAND=true # noop
fi
echo "Running: $SSHNPD_COMMAND"
eval "$SSHNPD_COMMAND"
