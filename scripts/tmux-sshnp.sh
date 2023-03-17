#!/bin/bash
tmux new-session -d -s sshnpd
tmux send-keys -t  sshnpd "cd " C-m
tmux send-keys -t  sshnpd "export USER=`whoami` " C-m
tmux send-keys -t  sshnpd "while true" C-m
tmux send-keys -t  sshnpd "do" C-m
tmux send-keys -t  sshnpd "~/sshnp/sshnpd -a <atSign> -m <atSign>  -u  -d <devicename> -v -s" C-m
tmux send-keys -t  sshnpd "sleep 10" C-m
tmux send-keys -t  sshnpd "done" C-m