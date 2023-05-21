#!/bin/bash
tmux new-session -d -s sshrvd
tmux send-keys -t  sshrvd "cd " C-m
# Allow machine to bring up network
tmux send-keys -t  sshrvd "sleep 10 " C-m
tmux send-keys -t  sshrvd "export USER=`whoami` " C-m
tmux send-keys -t  sshrvd "while true" C-m
tmux send-keys -t  sshrvd "do" C-m
tmux send-keys -t  sshrvd "~/sshnp/sshrvd -a <atSign> -i <FQDN/IP>" C-m
tmux send-keys -t  sshrvd "sleep 10" C-m
tmux send-keys -t  sshrvd "done" C-m