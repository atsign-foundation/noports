---
icon: rectangle-terminal
---

# sshnp Usage

## TL;DR

```
sshnp -f @<_client> -t @<_device> -h <@rv_(am|ap|eu) -d <name> -i <~/.ssh<ssh_key> -s
```

{% hint style="info" %}
Replace the \<??> with your details and remember to logout and back into the client so you have `sshnp` in your PATH.

Once you have successfully used the command to get access to the device once, you can drop the `-i` and `-s` flags if you wish.
{% endhint %}

## Overview

This guide covers the basics to understanding the parameters of and invoking sshnp.

## The four main parameters

### -f, --from

This argument is the client address, a.k.a. the from address, since we are connecting **from** the client. This argument is mandatory, in the form of an atSign. For example:

```bash
sshnp ... -f @alice_client ...
```

### -t, --to

This argument is the device address, a.k.a. the to address, since we are connecting **to** the device. This argument is mandatory, in the form of an atSign. For example:

```bash
sshnp ... -t @alice_device ...
```

### -d, --device

This argument is the device name, which works in tandem with `--to` to allow multiple devices to run sshnpd under a single device name. By default, this value is `"default"`, so unless you named your sshnpd device the same thing, you will need to include this parameter. For example:

```bash
sshnp ... -d my_device ...
```

### -h, --host

This argument is the address of the socket rendezvous used to establish the session connection. Atsign currently provides coverage in 3 regions, use whichever is closest to you:

#### Americas

```bash
sshnp ... -h @rv_am ...
```

#### Europe

```bash
sshnp ... -h @rv_eu ...
```

#### Asia-Pacific

```bash
sshnp ... -h @rv_ap ...
```

## SSH Authentication

In addition to the four main parameters, it is important to ensure that the appropriate SSH authentication keys are in place.&#x20;

#### Pre-existing keys in place

If you already have an SSH public key installed on the device, use `-i` to specify it. For example:

```bash
sshnp ... -i path/to/my/ssh/private/key ...
```

#### Automated SSH public key management

If you don't have an SSH public key installed on the device, and -s is enabled for the device, then sshnp can extract the SSH public key from the SSH private key, and send it to the daemon for you. This will automatically authorize your SSH private key. For example:

```bash
sshnp ... -i path/to/my/ssh/private/key -s ...
```

#### Manual SSH public key management

If you don't have any SSH public keys in place, you must install them yourself. Copy the SSH public key to `~/.ssh/authorized_keys` on the remote device. For example:

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBOkiUzsOq8wc9/HaEbE4lgcWeQoICBmp8XgRW0vf5T8 (Comment / identifier to remember this key here)
```

Then use the associated private key, as mentioned under [#pre-existing-keys-in-place](./#pre-existing-keys-in-place "mention"):

```
sshnp ... -i path/to/my/ssh/private/key ...
```

## Putting it altogether

An example of a complete command might look like this:

```bash
sshnp -f @alice_client -t @alice_device -d my_server -h @rv_am -i ~/.ssh/id_ed25519
```

\*Note if the username on the remote machine is different than your local machine you will have to also use the `-u` flag and the `-U` flag with the remote username. For example, if the remote username is `bocbc`. If you used the `-u` flag when running the sshnpd daemon then you can safely omit the `-U` flag.

```bash
sshnp -f @alice_client -t @alice_device -d my_server \
 -h @rv_am -i ~/.ssh/id_ed25519 -u bobc -U bobc
```

The rest of the configuration for `sshnp` is contained in a separate guide:

## Additional Configuration

{% content-ref url="additional-configuration.md" %}
[additional-configuration.md](additional-configuration.md)
{% endcontent-ref %}

## Want to use RDP, SFTP or etc?

{% content-ref url="broken-reference" %}
[Broken link](broken-reference)
{% endcontent-ref %}
