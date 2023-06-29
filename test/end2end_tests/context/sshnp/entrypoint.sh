#!/bin/bash
cd ~/.local/bin
sudo ./sshnp -f @jeremy_0 -t @smoothalligator -d docker -h @rv_am -s id_ed25519.pub -v > results.txt
sudo cat results.txt
