#!/bin/bash
cd ~/.local/bin
sudo ./sshnpd -a @smoothalligator -m @jeremy_0 -d docker -s -u -v > results.txt
sudo cat results.txt
