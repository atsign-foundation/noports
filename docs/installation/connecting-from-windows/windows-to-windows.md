---
description: How to install NoPorts when connecting from Windows to Windows
icon: windows
layout:
  width: default
  title:
    visible: true
  description:
    visible: true
  tableOfContents:
    visible: true
  outline:
    visible: true
  pagination:
    visible: false
  metadata:
    visible: true
  tags:
    visible: true
  actions:
    visible: true
---

# Windows to Windows

{% hint style="warning" %}
NoPorts version <5.13.0 should follow old instructions located here: [windows-to-windows-1.md](windows-to-windows-1.md "mention")
{% endhint %}

### Prerequisite

Before starting the NoPorts installation, ensure you have **at least two atSigns** available. If you don’t yet have any atSigns, you can sign up for a NoPorts subscription or free trial at [my.noports.com/no-ports-plans](https://my.noports.com/no-ports-plans).

### Step 1 to Step 4

These initial steps set up the machine initiating the connection.

{% include "../../.gitbook/includes/5.13-windows-client-steps.md" %}

### Step 5 to Step 7

After setting up the machine you're connecting from, you'll configure the machine you're connecting to.

{% include "../../.gitbook/includes/5.13-windows-device-steps.md" %}

### Step 8 and Step 9

With both machines now configured, the final steps bring us back to the machine initiating the connection.

<details>

<summary>On the machine you are connecting from</summary>

### <mark style="color:orange;">Step 8:</mark> Approve the device atSign authorization request

Run the following command:

{% hint style="warning" %}
Be sure to replace the following values:

`@<REPLACE>_np` with your **device atSign**,

`@<REPLACE_NAME>` with the **device name** **from Step 6.**
{% endhint %}

```bash
at_activate.exe approve -a "@<REPLACE>_np" --arx noports --drx <REPLACE_NAME>
```

### <mark style="color:orange;">Step 9:</mark> Use NoPorts!

That's it. You can start using NoPorts or explore some of the documented use cases, including [MCP](../../use-cases/mcp.md), [SSH](../../use-cases/ssh.md), [RDP](../../use-cases/rdp.md), [SFTP](../../use-cases/sftp.md), [Web Server](../../use-cases/web-server.md), and [SMB](../../use-cases/smb.md).&#x20;

</details>
