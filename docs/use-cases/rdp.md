---
icon: desktop
---

# RDP

## Overview

In this guide, we demonstrate how to use the NoPorts Tunnel to RDP on a remote machine to localhost:3389 so we can access the RDP service locally.

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

{% content-ref url="../usage/basic-usage/" %}
[basic-usage](../usage/basic-usage/)
{% endcontent-ref %}
