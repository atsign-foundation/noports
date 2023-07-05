#!/bin/bash
echo "Test Passed" > test.txt
~/.local/bin/sshnpd -a @smoothalligator -m @jeremy_0 -d e2e -s -u -v
