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

Run the following command to view full usage information of the sshnpd binary:
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

## sshrvd

### Installation

The `sshrvd.service` file should be placed in `/etc/systemd/system` (as root).

Modify the `sshrvd.service` unit to use the appropriate atSign,
(The boilerplate uses @atsign) as well as the internet address.
Also change the username and make sure that username running sshrvd has the
.atkeys file in place at '~/.atsign/keys'.

Run the following command to view full usage information of the sshrvd binary:
```sh
/usr/local/bin/sshrvd
```
or if you didn't install the binaries as root:
```sh
~/.local/bin/sshrvd
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