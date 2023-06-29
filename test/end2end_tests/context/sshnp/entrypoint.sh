#!/bin/bash
sudo -u atsign cd ~/.local/bin
sudo -u atsign ./sshnp -f @jeremy_0 -t @smoothalligator -d docker -h @rv_am -s id_ed25519.pub -v > results.txt
sudo -u atsign cat results.txt
