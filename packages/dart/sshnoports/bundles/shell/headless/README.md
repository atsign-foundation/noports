# Headless Scripts

This directory contains headless scripts for running various components of the
SSH No Ports suite.

## sshnpd

### Installation

The `sshnpd.sh` file should be placed in `~/.local/bin`.

Modify the `sshnpd.sh` unit to use the appropriate host and client Atsigns,
(The boilerplate uses $device_atsign $manager_atsign) as well as the devicename.
Also make sure that username running sshnpd has the .atkeys file in place at
'~/.atsign/keys'.

`sshnpd` is a script that runs the `atsc` installed beside it, and `sshnpd`
starts the `srv` installed there too.
Run the following command to view full usage information of sshnpd:
```sh
~/.local/bin/sshnpd
```

`install.sh headless sshnpd` installs the binaries to `~/.local/bin`, or to the
directory given with `-b`, and adds the job to the crontab of the user who runs
it. Run it without `sudo`, as the user who will run sshnpd. From a root login it
installs the binaries to `/usr/local/bin`, or to a directory given with `-b`
that only root can change, and the job to root's crontab.

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

The `srvd.sh` file should be placed in `~/.local/bin`.

Modify the `srvd.sh` script to use the appropriate Atsign,
(The boilerplate uses @my_rvd) as well as the internet address.
Also make sure that the user running srvd has the .atkeys file in place at
'~/.atsign/keys'.

`srvd` is a script that runs the `atsc` installed beside it.
Run the following command to view full usage information of srvd:
```sh
~/.local/bin/srvd
```

`install.sh headless srvd` installs the binaries to `~/.local/bin`, or to the
directory given with `-b`, and adds the job to the crontab of the user who runs
it. Run it without `sudo`, as the user who will run srvd. From a root login it
installs the binaries to `/usr/local/bin`, or to a directory given with `-b`
that only root can change, and the job to root's crontab.

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