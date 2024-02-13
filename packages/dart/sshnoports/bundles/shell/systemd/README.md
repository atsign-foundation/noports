# Systemd Units

This directory contains systemd unit definitions for running various components
of the SSH No Ports suite.

## sshnpd

### Installation

The `sshnpd.service` file should be placed in `/etc/systemd/system` (as root).

Modify the `sshnpd.service` unit to use the appropriate host and client atSigns,
(The boilerplate uses @device_atsign @manager_atsign) as well as the devicename.
Also change the username and make sure that username running sshnpd has the
.atkeys file in place at '~/.atsign/keys'.

Run the following command to view full usage information of the sshnpd binary:
```sh
/usr/local/bin/sshnpd
```

### Usage

To enable the service:

```sh
sudo systemctl enable sshnpd.service
```

The services will then start at the next reboot, or can be started immediately
with:

```sh
sudo systemctl start sshnpd.service
```

To view the realtime logs, use journalctl:

```sh
sudo journalctl -u sshnpd.service
```

## srvd

### Installation

The `srvd.service` file should be placed in `/etc/systemd/system` (as root).

Modify the `srvd.service` unit to use the appropriate atSign,
(The boilerplate uses @atsign) as well as the internet address.
Also change the username and make sure that username running srvd has the
.atkeys file in place at '~/.atsign/keys'.

Run the following command to view full usage information of the srvd binary:
```sh
/usr/local/bin/srvd
```

### Usage

To enable the service use:

```sh
sudo systemctl enable srvd.service
```

The services will then start at the next reboot, or can be started immediately
with:

```sh
sudo systemctl start srvd.service
```

To view the realtime logs, use journalctl:

```sh
sudo journalctl -u srvd.service
```