---
hidden: true
icon: wrench
---

# Troubleshooting

## TimeoutException: Connection timeout to srvd \<atsign> service

You receive the following error while using NoPorts:

```
TimeoutException: Connection timeout to srvd <atsign> service
```

There are a few possibilities for why this might be happening:

1. The relay atsign (-r in cli) is not running a relay or doesn't exist
2. The device atsign (-t in cli) doesn't exist

## TimeoutException: Daemon feature check timed out

You receive the following error while using NoPorts:

```
TimeoutException: Daemon feature check timed out
```

There are a few possibilities for why this might be happening:

1. There is no device running with device name (-d in cli)
2. You don't have permissions to make this connection to the device





* TODO: permit open / policy



*   Replace the \<??> with your details and remember to logout and back into the client so you have`npt`in your PATH.\
    \
    Note: ensure that the sshnpd on the server includes the remote port in their --permit-open/--po rules. If you installed using defaults then you need to edit the `/etc/systemd/system/sshnpd.service` file and add the hosts/ports you want to connect to via npt. \\

    For example:

    `ExecStart=/usr/local/bin/sshnpd -a "$device_atsign" -m "$manager_atsign" -d "$device_name" "$s" "$u" "$v"`

    Would become

    `ExecStart=/usr/local/bin/sshnpd -a "$device_atsign" -m "$manager_atsign" -d "$device_name" "$s" "$u" "$v" --po 127.0.0.1:22,192.168.1.90:445`

    To allow localhost access to SSH and SMB/CIFS access to 192.168.1.90 on port 445. Then run.

    `sudo systemctl daemon-reload`

    `sudo systemctl restart sshnpd.service`

    If you used a non root install (e.g. TMUX) then you will need to make a similar edit to `~/.local/bin/sshnpd.sh` and restart the script\\
