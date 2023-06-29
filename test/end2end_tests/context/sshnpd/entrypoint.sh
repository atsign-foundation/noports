#!/bin/bash
sudo -u atsign cd ~/.local/bin
sudo -u atsign ./sshnpd -a @smoothalligator -m @jeremy_0 -d docker -s -u -v > results.txt
sudo -u atsign cat results.txt
