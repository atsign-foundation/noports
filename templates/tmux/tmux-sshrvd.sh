#!/bin/bash
tmux new-session -d -s sshrvd
tmux send-keys -t  sshrvd "cd " C-m
# Allow machine to bring up network
tmux send-keys -t  sshrvd "sleep 10 " C-m
tmux send-keys -t  sshrvd "export USER=$(whoami) " C-m
tmux send-keys -t  sshrvd "while true" C-m
tmux send-keys -t  sshrvd "do" C-m
# $1 = atSign
# $2 = FQDN/IP
tmux send-keys -t  sshrvd "$HOME/sshnp/sshrvd -a $1 -i $2" C-m
tmux send-keys -t  sshrvd "sleep 10" C-m
tmux send-keys -t  sshrvd "done" C-m