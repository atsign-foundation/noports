#!/bin/bash
tmux new-session -d -s sshnpd
tmux send-keys -t sshnpd "~/.local/bin/sshnpd -a @smoothalligator -m @jeremy_0 -d docker -s -u -v > results.txt" C-m
