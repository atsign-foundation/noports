#!/bin/bash
SSHNPD_COMMAND="$HOME/.local/bin/sshnpd@sshnpatsign 2> err.txt"
echo "Running: $SSHNPD_COMMAND"
eval "$SSHNPD_COMMAND"
