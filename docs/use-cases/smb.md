---
icon: folder-tree
---

# SMB

## Overview

In this guide, we demonstrate how to use the NoPorts Tunnel to mount a SMB share on a remote machine on 192.168.1.90 to localhost:9000 so we can access the SMB share service locally.

The command should look like:

```
npt -f @<client> -t @<device> -d <device name> -r @<relay> -p 445 \
-h 192.168.1.90 -l 9000
```

Example:

```
npt -f @alice_client -t @alice_device -d my_server -r @rv_am -p 445 \
-h 192.168.1.90 -l 9000
```

{% hint style="info" %}
NOTE Make sure the sshnpd daemon is allowing port 445 to the SMB file server see Basic Usage for details.
{% endhint %}

Now you can mount the SMB share locally using the finder app ( Go->Connect to server) on MacOs

<figure><img src="../.gitbook/assets/Screenshot 2024-07-03 at 19.52.04.png" alt=""><figcaption></figcaption></figure>

Once mounted you can use the file share as normal, as you dismount the file share the NPT command will disconnect.



{% hint style="info" %}
Windows mounting on a non-standard port is currently not supported by Microsoft but they are working on it.

If you need this functionality, it is possible but fiddly to set up, contact us if you want to know how.
{% endhint %}

### To learn more about NPT

{% content-ref url="../usage/basic-usage/" %}
[basic-usage](../usage/basic-usage/)
{% endcontent-ref %}
