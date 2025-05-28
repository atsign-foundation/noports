---
description: >-
  In this guide, we demonstrate how to use the NoPorts Tunnel to RDP on a remote
  machine to localhost:3389 so we can access the RDP service locally.
icon: desktop
---

# RDP

The command should look like:

```
npt -f @<client> -t @<device> -d <device name> -r @<relay> -p 3389 -l 33389
```

Example:

```
npt -f @alice_client -t @alice_device -d my_server -r @rv_am -p 3389 -l 33389
```

Now you can connect to localhost:33899 in your favorite RDP client.

### To learn more about NPT

{% content-ref url="../usage/basic-usage.md" %}
[basic-usage.md](../usage/basic-usage.md)
{% endcontent-ref %}
