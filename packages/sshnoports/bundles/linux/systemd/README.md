# Systemd Units

This directory contains a systemd unit definition. It runs the sshnpd component
of SSH no ports in a GNU screen.

## Installation

The `sshnpd.service` file should be placed in `/etc/systemd/system` (as root).

Modify the `sshnpd.service` unit to use the appropriate host and client atSigns,
(The boilerplate uses @device_atsign @manager_atsign) as well as the devicename.
Also change the username and make sure that username running sshnpd has the
.atkeys file in place at '~/.atsign/keys'.

Then:

```bash
sudo systemctl enable sshnpd.service
```

The services will then start at the next reboot, or can be started manually
with:

```bash
sudo systemctl start sshnpd.service
```

## Usage

To view the realtime logs, use journalctl:

```bash
sudo journalctl -u sshnpd.service
```
