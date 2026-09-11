---
icon: rectangle-terminal
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

# npt Usage

### Quick Start

```bash
npt -f @<your_client_atsign> -t @<your_device_atsign> -r @rv_[am|ap|eu|oc] -d <name> \
-p <remote-port> -l <local-port>
```

### Overview

This guide covers the basics to understanding the parameters of npt and invoking npt.

The NoPorts Tunnel, or npt for short, provides an end to end encrypted TCP Tunnel without the need for inbound listening ports on either of your machines.

### Options

<table><thead><tr><th width="100">Option</th><th width="134">Required / Default</th><th width="230">Value Format</th><th width="382">Description</th></tr></thead><tbody><tr><td>-f</td><td><strong>required</strong></td><td>Atsign</td><td>The client Atsign, a.k.a. the <strong>from</strong> Atsign, since we are connecting from the client.</td></tr><tr><td>-t</td><td><strong>required</strong></td><td>Atsign</td><td>The device Atsign, a.k.a. the <strong>to</strong> Atsign, since we are connecting to the device.</td></tr><tr><td>-r</td><td><strong>required</strong></td><td>Atsign</td><td><p>The Atsign of the relay service used to establish the session connection. NoPorts currently provides coverage in 4 regions:</p><p>@rv_am - Americas</p><p>@rv_eu - Europe</p><p>@rv_ap - Asia/Pacific<br>@rv_oc - Oceania</p></td></tr><tr><td>-d</td><td><strong>required</strong></td><td>String<br><em>Only <code>[a-z0-9_-]</code> allowed.</em><br><em>Maximum of 36 characters.</em></td><td>Allows multiple devices to run sshnpd under a single device name.</td></tr><tr><td>-p</td><td><strong>required</strong></td><td>Port number.<br><em>Between 1-65535.</em></td><td>The port you are connecting to on the device/remote side. This port must be included in the --permit-open list and/or policy allowances.</td></tr><tr><td>-l</td><td>"0"</td><td>Port number<br><em>Between 1024-65535.</em></td><td>The port you are connecting to on the client/local side. Defaults to any unused port.</td></tr><tr><td>-h</td><td>"localhost"</td><td>DNS / ip address</td><td>The host that the daemon will connect to. nslookup is resolved on the remote machine where the daemon is running.</td></tr><tr><td>-K</td><td>N/A</td><td>N/A</td><td>Keep alive. If a session ends, try to create a new session and re-bind the port. If you are using this in a script or as a daemon, it's recommended that you handle restarts externally (e.g. with an init system) and do not rely on npt -K.</td></tr><tr><td>-T</td><td>"30s"<br>"24h" (with -K)</td><td>Human readable duration:<br>e.g. "7d" or "1h,14m,30s"</td><td>How long to keep the npt session open if there have been no connections. To "never" timeout, use "-T 0" which sets a timeout of 365 days.</td></tr><tr><td>-x</td><td>N/A</td><td>N/A</td><td><p>Starts the session in the background under a different process id, then exits, printing the bound port to stdout. </p><p></p><p>Note that the background npt session will automatically close due to the timeout feature (see -T).</p><p></p><p>If you are scripting npt, this feature means you will lose control over the session process, do not use this feature if you also intend to control when npt stops or if you need to detect when the npt session dies.</p></td></tr><tr><td>-v / -q</td><td>N/A</td><td>N/A</td><td>Use -v for verbose logging.<br>Use -q for quiet (i.e. less) logging.</td></tr></tbody></table>

### Example

```bash
npt -f @alice_client -t @alice_device -d my_server -r @rv_am -p 3389 -l 33389
```

### Use Cases

{% content-ref url="../use-cases/rdp.md" %}
[rdp.md](../use-cases/rdp.md)
{% endcontent-ref %}

{% content-ref url="../use-cases/sftp.md" %}
[sftp.md](../use-cases/sftp.md)
{% endcontent-ref %}

{% content-ref url="../use-cases/web-server.md" %}
[web-server.md](../use-cases/web-server.md)
{% endcontent-ref %}
