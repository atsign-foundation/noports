#!/bin/bash
echo "SSHNPD START ENTRY"
SSHNPD_COMMAND="$HOME/.local/bin/sshnpd -a @sshnpdatsign -m @sshnpatsign -d deviceName -s -u -v 2>&1 | tee -a sshnpd.log"
echo "Running: $SSHNPD_COMMAND"
eval "$SSHNPD_COMMAND"
