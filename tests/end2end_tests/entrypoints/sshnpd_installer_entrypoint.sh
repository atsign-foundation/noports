#!/bin/bash
SSHNPD_COMMAND="$HOME/.local/bin/sshnpd@sshnpatsign 2>&1 | tee all.txt"
echo "Running: $SSHNPD_COMMAND"
eval "$SSHNPD_COMMAND"
