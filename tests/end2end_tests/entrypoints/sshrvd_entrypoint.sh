#!/bin/bash
"$HOME"/.local/bin/sshrvd -a @sshrvdatsign -i "$(hostname -i)" -v -s 2>&1 | tee -a sshrvd.log
