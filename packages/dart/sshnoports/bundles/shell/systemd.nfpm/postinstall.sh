#!/bin/sh
set -e

# Check if systemd is running (PID 1 is systemd)
if [ -d /run/systemd/system ]; then
    echo "Systemd detected. Configuring sshnpd service..."
    
    # Reload to pick up the new .service file
    systemctl daemon-reload
    
    # Enable the service (starts on boot)
    systemctl enable sshnpd.service
    
    # Start the service now
    systemctl start sshnpd.service
else
    echo "Systemd not detected or not running. Skipping service activation."
fi