#!/bin/bash
tmux new-session -d -s sshnpd
tmux send-keys -t sshnpd "~/.local/bin/sshnpd -a @smoothalligator -m @jeremy_0 -d docker -s -u -v" C-m
sleep 2

# ~/.local/bin/sshnpd -a @smoothalligator -m @jeremy_0 -d docker -s -u -v
# sleep 2
