#!/bin/bash
"$HOME"/.local/bin/sshrvd -a @sshrvdatsign -i "$(hostname -i)" -v -s
sleep 60 # sleep 60 because other containers depend on it. And if it's not being used (let's say you're using @rv_am), then it will just sleep until sshnp exits
exit 0
