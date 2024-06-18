# 💻 Basic Usage

## Quick Start

```bash
npt -f @<_client> -t @<_device> -r <@rv_(am|ap|eu) -d <name> \
-p <remote-port> -l <local-port>
```

{% hint style="info" %}
Replace the \<??> with your details and remember to logout and back into the client so you have`npt`in your PATH.\
\
Note: ensure that the sshnpd has included the remote port in their --permit-open rules.
{% endhint %}

## Options

<table><thead><tr><th width="142">Option</th><th width="105" data-type="checkbox">Required</th><th width="113">Default</th><th width="382">Description</th></tr></thead><tbody><tr><td>-f, --from</td><td>true</td><td></td><td>The client address, a.k.a. the <strong>from</strong> address, since we are connecting from the client. </td></tr><tr><td>-t, --to </td><td>true</td><td></td><td>The device address, a.k.a. the <strong>to</strong> address, since we are connecting to the device. </td></tr><tr><td>-r, --rvd</td><td>true</td><td></td><td>The address of the socket rendezvous used to establish the session connection. Atsign currently provides coverage in 3 regions, use whichever is closest to you: (@rv_am for Americas, @rv_eu for Europe, @rv_ap for Asia/Pacific)</td></tr><tr><td>-d, --device</td><td>true</td><td></td><td>Allows multiple devices to run sshnpd under a single device name. </td></tr><tr><td>-p,  --rp</td><td>true</td><td></td><td>The port you are connecting to on the device/remote side. This port must be included in the --permit-open list. Read more about         <a href="./#p-remote-port-rp">--permit-open</a>.</td></tr><tr><td>-l, --lp</td><td>false</td><td>0</td><td>The port you are connecting to on the client/local side. Defaults to any unused port.</td></tr></tbody></table>

## Overview

This guide covers the basics to understanding the parameters of npt and invoking npt.

The NoPorts Tunnel or npt for short, provides an end to end encrypted TCP Tunnel without the need for inbound port rules on client or device machines. &#x20;

## Examples

#### -f, --from

This argument is the client address, a.k.a. the **from** address, since we are connecting from the client.&#x20;

```bash
npt ... -f @alice_client ...
```

#### -t, --to

This argument is the device address, a.k.a. the **to** address, since we are connecting to the device.&#x20;

```bash
npt ... -t @alice_device ...
```

#### -d, --device

This argument is the device name, which works in tandem with --to to allow multiple devices to run sshnpd under a single device name. By default, this value is "default", so unless you named your sshnpd device the same thing, you will need to include this parameter. For example:

```bash
npt ... -d my_device ...
```

#### -r, --srvd

This argument is the address of the socket rendezvous used to establish the session connection. Atsign currently provides coverage in 3 regions, use whichever is closest to you:

**Americas**

```bash
npt ... -r @rv_am ...
```

**Europe**

```bash
npt ... -r @rv_eu ...
```

**Asia-Pacific**

```bash
npt ... -r @rv_ap ...
```

#### -p, --remote-port, --rp

This argument is the port you are connecting to on the device side.&#x20;

This argument is mandatory.

It is important to make sure the port you are connecting to is included in the list of permitted ports on the device side. (--permit-open, --po)&#x20;

```bash
npt ... -p 3389 ...
```

#### -l, --local-port, --lp&#x20;

This argument is the port you are connecting to on the client side.

This argument is optional, but suggested.

&#x20;It is important to make sure the port you are connecting to is not a restricted port.&#x20;

```bash
npt ... -l 33389 ...
```

### Putting it altogether

An example of a complete command might look like this:

```bash
npt -f @alice_client -t @alice_device -d my_server -r @rv_am -p 3389
```

## Usage Guides

Here are some guides where we demonstrate how to use the NoPorts Tunnel to run some common TCP Services without opening any ports.

{% content-ref url="../rdp.md" %}
[rdp.md](../rdp.md)
{% endcontent-ref %}

{% content-ref url="../sftp.md" %}
[sftp.md](../sftp.md)
{% endcontent-ref %}

{% content-ref url="../web-server.md" %}
[web-server.md](../web-server.md)
{% endcontent-ref %}
