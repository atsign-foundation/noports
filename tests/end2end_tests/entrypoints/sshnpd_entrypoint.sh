#!/bin/bash
echo "SSHNPD START ENTRY"
set -x
$HOME/.local/bin/sshnpd -a @sshnpdatsign -m @sshnpatsign -d deviceName -s -u -v 2> >(tee err.txt)
