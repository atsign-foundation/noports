#!/bin/bash
echo "Test Passed" > test.txt
~/.local/bin/sshnpd -a @sshnpd -m @sshnp -d e2e -s -u -v
