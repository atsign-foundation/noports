#!/bin/bash

SSHNPD_COMMAND="$HOME/.local/bin/sshnpd -a @sshnpdatsign -m @sshnpatsign -d deviceName -s -u -v"
echo "Running: $SSHNPD_COMMAND"
eval "$SSHNPD_COMMAND"
