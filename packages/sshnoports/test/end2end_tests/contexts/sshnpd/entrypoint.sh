#!/bin/bash
echo "Test Passed" > test.txt
~/.local/bin/sshnpd -a @sshnp -m @sshnpd -d e2e -s -u -v
