#!/bin/bash
echo "SSHNPD START ENTRY"
SSHNPD_COMMAND="$HOME/.local/bin/sshnpd -a @sshnpdatsign -m @sshnpatsign -d deviceName -s -u -v 2>&1 | tee all.txt"
echo "Running: $SSHNPD_COMMAND"
eval "$SSHNPD_COMMAND"
tail -f all.txt
