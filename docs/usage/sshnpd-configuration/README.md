---
icon: square-sliders
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

# sshnpd configuration

### TL;DR

```
sshnpd -m @<_client> -a @<_device> -d <name> 
```

{% hint style="info" %}
Replace the \<??> with your specific Atsign details
{% endhint %}

### Overview

sshnpd is the daemon that runs on a device to facilitate access using NoPorts.

### The three main parameters

These mainly mirror the parameters from [sshnp](../basic-usage-1/), but there's one fewer as the socket rendezvous is only ever set by the client.

### 1. -a, --atsign

This argument is the device address, a.k.a. the to address, since this is the address that the device is associated with. This argument is mandatory, in the form of an Atsign. For example:

```
sshnpd ... -a @alice_device ...
```

### 2a. -m, --manager, --managers

This is the address of the client(s) that will be allowed to connect to the device. For example:

```
sshnpd ... -m @alice_client ...
```

### 2b. -p, --policy-manager

As an alternative to defining a list of managers a policy manager can be used, and the policy defined on that manager will describe which clients are allowed to connect. For example:

```
sshnpd ... -p @alice_policy ...
```

### 3. -d, --device

The device name. This is used to associate multiple devices with the same Atsign. By default the value is `default` so unless you want that as the device name you will need to include this parameter. For example:

```
sshnpd ... -d my_device ...
```

### Putting it all together

An example of a complete command might look like this:

```
sshnpd -a @alice_device -m @alice_client -d my_server
```

### Running the daemon as a service

The daemon should normally be run as a service so that it starts up automatically and can be restarted if it should fail.

Most mainstream Linux distributions use [systemd](https://en.wikipedia.org/wiki/Systemd) to manage services, and we provide a systemd unit file that's configured by the universal installer. That file can be edited after installation to customize or add additional options. For distributions such as OpenWrt we provide config and init files that can be customized with a text editor or configured through the web admin interface.

### Additional Configuration

The rest of the configuration for `sshnpd` is contained in a separate guide:

{% content-ref url="daemon-additional-configuration.md" %}
[daemon-additional-configuration.md](daemon-additional-configuration.md)
{% endcontent-ref %}

### Modifying your device's systemd unit&#x20;

If you installed sshnpd through the universal installer, then you can modify the `/etc/systemd/system/sshnpd.service.d/override.conf`  file to take advantage of the configurations and options listed above to tailor sshnpd to your needs.

Lots of configuration can be done to sshnpd by editing this file, such as changing the user that sshnpd runs as, changing the Atsign, enabling/disabling verbose logging, and more.

Sample `override.conf`file:

```sh
# MANDATORY: User to run the daemon as
User=bob

# MANDATORY: Manager (client) or policy manager address (atSign)
Environment=manager_atsign="@alice"

# MANDATORY: Device address (atSign)
Environment=device_atsign="@bob"

# OPTIONAL: Delegated access policy management
Environment=delegate_policy=""

# Device name
Environment=device_name="atsign"

# Comment if you don't want the daemon to update authorized_keys to include
# public keys sent by authorized manager atSigns
Environment=s="-s"

# Comment to disable verbose logging
Environment=v="-v"

# Any additional command line arguments for sshnpd
Environment=additional_args=""
```

Adding additional arguments is as simple as modifying the `Environment=additional_args=""`string found inside of `override.conf` .

The example adds the `--permit-open` to the string of additional args which enables clients to access ports 22, 3389, and 2221 on localhost.

```sh
# Any additional command line arguments for sshnpd
Environment=additional_args="--permit-open \"localhost:22,localhost:3389,localhost:2221\""
```

Don't forget to update sshnpd by executing (may require sudo):

```sh
systemctl daemon-reload
systemctl restart sshnpd.service
```

