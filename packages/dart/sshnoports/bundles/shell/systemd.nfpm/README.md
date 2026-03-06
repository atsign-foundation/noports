# Systemd Units

This directory contains systemd unit definitions for running various
components of the NoPorts suite that will be installed using packages
created by nfpm.

## sshnpd

### Installation

The `sshnpd.service` file is placed in `/usr/lib/systemd/system`.

### Config

Config is read from `/etc/noports/sshnpd.yaml`

### Usage

To enable the service:

```sh
sudo systemctl enable sshnpd
```

The services will then start at the next reboot, or can be started immediately
with:

```sh
sudo systemctl start sshnpd
```

To view the realtime logs, use journalctl:

```sh
journalctl -u sshnpd -f
```

## srvd

### Installation

The `srvd.service` file is placed in `/usr/lib/systemd/system`.

### Usage

To enable the service use:

```sh
sudo systemctl enable srvd
```

The services will then start at the next reboot, or can be started immediately
with:

```sh
sudo systemctl start srvd
```

To view the realtime logs, use journalctl:

```sh
journalctl -u srvd -f
```
