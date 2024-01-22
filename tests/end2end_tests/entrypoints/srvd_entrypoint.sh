#!/bin/bash
"$HOME"/.local/bin/srvd -a @srvdatsign -i "$(hostname -i)" -v -s 2>&1 | tee -a srvd.log
