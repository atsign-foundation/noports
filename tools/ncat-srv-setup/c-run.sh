#!/bin/bash

session_name=c_srv_test

if ! tmux has-session -t $session_name; then
	tmux new-session -ds $session_name
	# Setup the layout
	tmux split-window -h -p 50 -t $session_name:^
	tmux split-window -v -p 50 -t $session_name:^
fi

# Left side pane
tmux send-keys -t $session_name:^.0 C-c C-l # Clear the pane
tmux send-keys -t $session_name:^.0

# Top right pane
tmux send-keys -t $session_name:^.1 C-c C-l # Clear the panel
tmux send-keys -t $session_name:^.1

# Bottom right pane
tmux send-keys -t $session_name:^.2 C-c C-l # Clear the panel
tmux send-keys -t $session_name:^.2
