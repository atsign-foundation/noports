#!/bin/bash
echo "Test Passed" > test.txt
~/.local/bin/sshnpd -a @sshnpdatsign -m @sshnpatsign -d deviceName -s -u -v
