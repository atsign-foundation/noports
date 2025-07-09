---
description: >-
  In this guide, we demonstrate how to use the NoPorts Tunnel to bridge SFTP on
  a remote machine to localhost:2222 so we can access it in an SFTP client
  locally.
icon: folder-closed
---

# SFTP

### Command Line

The command should look like:

```
npt -f @<client> -t @<device> -d <device name> -r @<relay> -p 22 -l 2222
```

Example:

```
npt -f @alice_client -t @alice_device -d my_server -r @rv_am -p 22 -l 2222
```

Now you can connect to localhost:2222 in your favorite SFTP client.

### To learn more about NPT

{% content-ref url="../usage/basic-usage.md" %}
[basic-usage.md](../usage/basic-usage.md)
{% endcontent-ref %}

### Desktop Application

When using the NoPorts desktop application, your connection profile should look something like this:

|                   |                    |
| ----------------- | ------------------ |
| **Profile Name**  | My SFTP Connection |
| **Device atSign** | @alice\_device     |
| **Device Name**   | my\_server         |
| **Relay**         | @rv\_am            |
| **Local Port**    | 2222               |
| **Remote Host**   | localhost          |
| **Remote Port**   | 22                 |
