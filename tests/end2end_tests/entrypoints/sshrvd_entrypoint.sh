#!/bin/bash
"$HOME"/.local/bin/sshrvd -a @sshrvdatsign -i "$(hostname -i)" -v -s > sshrvd.log
