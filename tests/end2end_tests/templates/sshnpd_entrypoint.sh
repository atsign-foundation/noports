#!/bin/bash
if [ -z "$USE_INSTALLER" ]; then
  SSHNPD_COMMAND="$HOME/.local/bin/sshnpd -a @sshnpdatsign -m @sshnpatsign -d deviceName -s -u -v"
else
  crontab -l
  tmux ls
  ps aux | grep sshnpd
  SSHNPD_COMMAND="sleep 60"
fi
echo "Running: $SSHNPD_COMMAND"
eval "$SSHNPD_COMMAND"
