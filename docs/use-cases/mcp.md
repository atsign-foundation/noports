---
description: >-
  In this guide, we demonstrate how to use the NoPorts Tunnel to securely access
  an MCP server running on a remote device, making it accessible via
  localhost:3001 on your local machine
icon: arrow-progress
---

# MCP

{% hint style="info" %}
In this example, we assume the OpenAPI-based MCP Server is listening on port 3000. These instructions apply to other MCP server types as well, not just OpenAPI-based deployments.
{% endhint %}

### Command Line

The command should look like:

```
npt -f @<client> -t @<device> -d <device name> -r @<relay> -p 3000 -l 3001
```

Example:

```
npt -f @alice_client -t @alice_device -d my_server -r @rv_am -p 3000 -l 3001
```

Now you can interact with your OpenAPI-based MCP server by connecting to `http://localhost:3001` .

### To learn more about NPT

{% content-ref url="../usage/basic-usage.md" %}
[basic-usage.md](../usage/basic-usage.md)
{% endcontent-ref %}

### Desktop Application

When using the NoPorts desktop application, your connection profile should look something like this:

|                   |                   |
| ----------------- | ----------------- |
| **Profile Name**  | My MCP Connection |
| **Device atSign** | @alice\_device    |
| **Device Name**   | my\_server        |
| **Relay**         | @rv\_am           |
| **Local Port**    | 3001              |
| **Local Host**    | localhost         |
| **Remote Host**   |                   |
| **Remote Port**   | 3000              |
