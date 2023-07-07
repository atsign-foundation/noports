#!/bin/bash
echo "Test Passed" > test.txt
~/.local/bin/sshnpd -a @sshnpd_atsign -m @sshnp_atsign -d e2e -s -u -v
