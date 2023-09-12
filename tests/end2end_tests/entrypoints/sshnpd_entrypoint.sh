#!/bin/bash
echo "SSHNPD START ENTRY"
SSHNPD_COMMAND="$HOME/.local/bin/sshnpd -a @sshnpdatsign -m @sshnpatsign -d deviceName -s -u -v >> all.txt 2>&1"
echo "Running: $SSHNPD_COMMAND"
eval "$SSHNPD_COMMAND"
tail -f all.txt
