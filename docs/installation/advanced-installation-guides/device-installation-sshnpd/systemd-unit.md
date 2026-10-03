---
description: How we use systemd
layout:
  width: default
  title:
    visible: true
  description:
    visible: true
  tableOfContents:
    visible: true
  outline:
    visible: true
  pagination:
    visible: false
  metadata:
    visible: true
  tags:
    visible: true
  actions:
    visible: true
---

# Systemd Unit

[systemd](https://en.wikipedia.org/wiki/Systemd) has become the standard way of defining and managing services on all major Linux distributions. Our .deb and .rpm packages will automatically install a systemd unit for the NoPorts daemon `sshnpd` into `/lib/systemd/system/sshnpd.service`:

```systemd
[Unit]
Description=NoPorts Daemon
After=network-online.target

[Install]
WantedBy=multi-user.target

[Service]
Type=simple
Restart=always
RestartSec=3
KillMode=process

# The line below runs the sshnpd service, with the config from
# /etc/noports/sshnpd.yaml
ExecStart=/usr/bin/sshnpd
```

### override.conf

We also create an `/etc/systemd/system/sshnpd.service.d/override.conf` that's primarily used to set the username that NoPorts runs as. The template (without comments) is:

```systemd
[Service]
User=1000
```

`1000` will be replaced by `universal.sh` with the username of the user running the install script. To set it manually, or change it to another user, run `sudo systemctl edit sshnpd` . Once changes have been made then run `sudo systemctl daemon-reload` to pick up the changes then `sudo systemctl restart sshnpd` to restart the daemon. You can follow the daemon logs with `journalctl -u sshnpd -f` .

### NoPorts daemon config - sshnpd.yaml

The expected location for NoPorts daemon config is at `/etc/noports/sshnpd.yaml` and that file should be edited to reflect your choice of device and client names etc. At a minimum the sections marked `TODO` must be filled out correctly.

#### Config migration

Previous versions of NoPorts put config into environment variables in systemd units and then passed those into command line arguments for the daemon.

When upgrading with `universal.sh` those variables will be migrated from the systemd units to `sshnpd.yaml` . If you've created a very complex config please check that the migration has completed correctly.
