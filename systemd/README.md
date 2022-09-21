# Systemd Units

This directory contains a systemd unit definitions. It runs a the sshnpd component
of the ssh! no ports in a GNU screen, which can be attached to (for logging etc.)
with `screen -r`

## Installation

The `sshnpd.service` files should be placed in `/etc/systemd/system` (as root).

Modify the `sshnpd.service` unit to use the appropriate host and client
atSigns. (The boilerplate uses @deviceatsign @manageratsign). Also change the username and make sure that username running sshnpd has the .atkeys file in place at '~/.atsign/keys'.

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

Make sure you have 'screen' installed it allows you to connect to the runing sshnpd and see the logs in realtime.

When running there will a detached screen `screen -r` will list it:

```
There are several suitable screens on:
        904.sshnpd   (09/03/22 16:26:53)     (Detached)

Type "screen [-d] -r [pid.]tty.host" to resume one of them.
```

An individual screen can be attached to by e.g. `screen -r 904.sshnpd`.

To detach again use `Ctrl-a d`
