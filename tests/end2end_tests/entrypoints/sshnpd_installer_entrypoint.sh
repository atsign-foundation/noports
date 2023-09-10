#!/bin/bash
set -x
$HOME/.local/bin/sshnpd@sshnpatsign 2> >(tee err.txt)
