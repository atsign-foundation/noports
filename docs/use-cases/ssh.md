---
description: >-
  In this guide, we demonstrate how to use SSH NoPorts to SSH to a remote
  machine.
icon: rectangle-terminal
---

# SSH

### Command Line

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

### Desktop Application

When using the NoPorts desktop application, your connection profile should look something like this:

|                   |                   |
| ----------------- | ----------------- |
| **Profile Name**  | My SSH Connection |
| **Device atSign** | @alice\_device    |
| **Device Name**   | my\_server        |
| **Relay**         | @rv\_am           |
| **Local Port**    | 2222              |
| **Local Host**    | localhost         |
| **Remote Host**   |                   |
| **Remote Port**   | 22                |
