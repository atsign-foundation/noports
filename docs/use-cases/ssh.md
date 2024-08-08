---
icon: rectangle-terminal
---

# SSH

## Overview

In this guide, we demonstrate how to use SSH NoPorts to SSH to a remote machine.

The command should look like:

```
sshnp -f @<client> -t @<device> -d <device name> -r @<relay> -i <your ssh key>
```

Example:

```
sshnp -f @alice_client -t @alice_device -d my_server -r @rv_am -i ~/.ssh/id_ed25519
```

#### Auto SSH key upload

If you don't have an ssh key uploaded on the remote machine, you can upload one by adding `-s` to the command:

```
sshnp -f @alice_client -t @alice_device -d my_server -r @rv_am -i ~/.ssh/id_ed25519 -s
```

{% hint style="warning" %}
Note: this feature can be disabled in sshnpd. If you get an error when using -s, it is likely that the administrator disabled this feature for security reasons.
{% endhint %}

### To learn more about SSHNP

{% content-ref url="../usage/basic-usage-1/" %}
[basic-usage-1](../usage/basic-usage-1/)
{% endcontent-ref %}
