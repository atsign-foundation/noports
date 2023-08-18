#!/bin/bash
SSHNPD_COMMAND="$HOME/.local/bin/sshnpd@sshnpatsign -s -u"
echo "Running: $SSHNPD_COMMAND"
eval "$SSHNPD_COMMAND"
