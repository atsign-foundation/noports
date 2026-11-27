# Headless Scripts

This directory contains headless scripts for running various components of the
SSH No Ports suite.

## sshnpd

### Installation

The `sshnpd.sh` file should be placed in `~/.local/bin`.

Modify the `sshnpd.sh` unit to use the appropriate host and client atSigns,
(The boilerplate uses $device_atsign $manager_atsign) as well as the devicename.
Also make sure that username running sshnpd has the .atkeys file in place at
'~/.atsign/keys'.

`sshnpd` is a script that runs the `atsc` installed beside it, and `sshnpd`
starts the `srv` installed there too.
Run the following command to view full usage information of sshnpd:
```sh
/usr/local/bin/sshnpd
```
or if you didn't install the binaries as root:
```sh
~/.local/bin/sshnpd
```

### Usage

A cron entry is created which automatically runs this script upon boot using the
`@reboot` directive. You can use the `crontab` command to view and edit the
configuration:

To view the crontab:
```sh
crontab -l
```

To edit the crontab:
```sh
crontab -e
```

## srvd

### Installation

The `srvd.service` file should be placed in `/etc/systemd/system` (as root).

Modify the `srvd.service` unit to use the appropriate atSign,
(The boilerplate uses @atsign) as well as the internet address.
Also change the username and make sure that username running srvd has the
.atkeys file in place at '~/.atsign/keys'.

`srvd` is a script that runs the `atsc` installed beside it.
Run the following command to view full usage information of srvd:
```sh
/usr/local/bin/srvd
```
or if you didn't install the binaries as root:
```sh
~/.local/bin/srvd
```

### Usage

A cron entry is created which automatically runs this script upon boot using the
`@reboot` directive. You can use the `crontab` command to view and edit the
configuration:

To view the crontab:
```sh
crontab -l
```

To edit the crontab:
```sh
crontab -e
```