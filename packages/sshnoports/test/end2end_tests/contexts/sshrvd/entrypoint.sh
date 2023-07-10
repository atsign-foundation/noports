#!/bin/bash
~/.local/bin/sshrvd -a @sshrvdatsign -i $(hostname -i) -v -s
sleep 60