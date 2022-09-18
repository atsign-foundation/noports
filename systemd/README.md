# Systemd Units

This directory contains a systemd unit definitions. It runs a the sshnpd component
of the ssh! no ports in a GNU screen, which can be attached to (for logging etc.)
with `screen -r`

## Installation

The `sshnpd.service` files should be placed in `\etc\systemd\system` (as root).

Modify the `sshnpd.service` unit to use the appropriate sender and target
atSigns. (The boilerplate uses @deviceatsign @manageratsign).

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

When running there will be three detached screens. `screen -r` will list them:

```
There are several suitable screens on:
        904.sshnpd   (09/03/22 16:26:53)     (Detached)

Type "screen [-d] -r [pid.]tty.host" to resume one of them.
```

An individual screen can be attached to by e.g. `screen -r sshnpd`.

To detach again use `Ctrl-a d`
