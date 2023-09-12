#!/bin/bash
SSHNPD_COMMAND="$HOME/.local/bin/sshnpd@sshnpatsign > all.txt 2>&1"
echo "Running: $SSHNPD_COMMAND"
eval "$SSHNPD_COMMAND"
tail -f all.txt