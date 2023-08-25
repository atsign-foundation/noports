#!/bin/bash
SSHNPD_COMMAND="$HOME/.local/bin/sshnpd@sshnpatsign > logs.txt"
echo "Running: $SSHNPD_COMMAND"
eval "$SSHNPD_COMMAND"
