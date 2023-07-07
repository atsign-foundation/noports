#!/bin/bash
echo "Test Passed" > test.txt
~/.local/bin/sshnpd -a @sshnpdatsign -m @sshnpatsign -d e2e -s -u -v
