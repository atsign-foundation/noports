#!/bin/sh
set -e

if [ -d /run/systemd/system ]; then
    echo "Stopping and disabling service..."
    systemctl stop sshnpd.service || true
    systemctl disable sshnpd.service || true
fi