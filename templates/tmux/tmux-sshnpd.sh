#!/bin/bash
tmux new-session -d -s sshnpd
tmux send-keys -t  sshnpd "cd " C-m
# Allow machine to bring up network
tmux send-keys -t  sshnpd "sleep 10 " C-m
tmux send-keys -t  sshnpd "export USER=$(whoami) " C-m
tmux send-keys -t  sshnpd "while true" C-m
tmux send-keys -t  sshnpd "do" C-m
# -a = client atSign
# -m = device manager atSign
# -d = device name
tmux send-keys -t  sshnpd "$HOME/.local/bin/sshnpd -a $1 -m $2  -u  -d $3 -v -s" C-m
tmux send-keys -t  sshnpd "sleep 10" C-m
tmux send-keys -t  sshnpd "done" C-m