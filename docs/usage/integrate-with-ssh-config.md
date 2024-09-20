---
icon: square-sliders-vertical
---

# Integrate with ssh config

## The Template

The following is a template for adding an sshnp connection to your ssh config for ease of use:

{% code title="~/.ssh/config" overflow="wrap" lineNumbers="true" %}
```
Host <host>
  Hostname localhost
  AddKeysToAgent yes
  UserKnownHostsFile /dev/null
  StrictHostKeyChecking no
  IdentityFile ~/.ssh/id_ed25519
  ProxyCommand=$(sshnp -f <client> -t <device> -r <srvd> -d <device_name> -u <username> -x 2>/dev/null) -W "%h:%p" -o "StrictHostKeyChecking=no"
  ControlMaster auto
  ControlPath ~/.ssh/control-%r@%n:%p

```
{% endcode %}

Example:

{% code overflow="wrap" %}
```
Host alice_device
  Hostname localhost
  AddKeysToAgent yes
  UserKnownHostsFile /dev/null
  StrictHostKeyChecking no
  IdentityFile ~/.ssh/id_ed25519
  ProxyCommand=$(sshnp -f @alice_client -t @alice_device -r @rv_am -d my_device -u <username> -x 2>/dev/null) -W "%h:%p" -o "StrictHostKeyChecking=no"
  ControlMaster auto
  ControlPath ~/.ssh/control-%r@%n:%p
```
{% endcode %}

```
sshnp -f @alice_client -t @alice_device -d my_server -r @rv_am
```

### Usage

Use this config as you would any other ssh config entry:

```bash
ssh <host>
```

### Template Explained

#### Line 1

`<host>` is the "nickname" you would use to connect to, e.g. `ssh <host>`.

{% hint style="info" %}
You can pick anything you want, but you should make sure that this won't clash with other hostnames you might want to connect to.
{% endhint %}

#### Line 2

Line 2 is mandatory due to the nature of how sshnp works, sshnp must connect over the loopback interface where the NoPorts tunnel was created.

#### Line 3

Tell ssh to automatically add the ssh keys to the agent when we load them (we will load them on line 6)

#### Line 4

Don't cache the connection to known hosts, since sshnp uses ephemeral ports, it is pointless to do so.

#### Line 5

Because we are using ephemeral ports, it is useful to suppress strict host key checking.

#### Line 6

The ssh key you would like to load and authenticate with (this is equivalent to `ssh -i`).

#### Line 7

A proxy command, which first executes sshnp to determine the ssh proxy command which will be executed, fill in the arguments on this line as you would normally.

See [basic-usage-1](basic-usage-1/ "mention") to learn more about filling in this line.

#### Lines 8 & 9

ControlMaster and ControlPath tell ssh to try to reuse existing ssh connections if you start up multiple. This means only the first connection will setup sshnp, the rest of the connections will use the tunnel that is already there!

### Additional Usage Tips

#### 1. Extending ssh config

You can add any additional ssh config to the file as you normally would, for example a TCP forwarding:

{% code title="~/.ssh/config" overflow="wrap" lineNumbers="true" %}
```
Host my_webdev_server
  Hostname localhost
  AddKeysToAgent yes
  UserKnownHostsFile /dev/null
  StrictHostKeyChecking no
  IdentityFile ~/.ssh/id_ed25519
  LocalForward 8080:0:8080
  ProxyCommand=...
```
{% endcode %}

#### 2. Extending ssh command

You can also add any additional flags to the ssh command, for example a TCP forwarding:

```bash
ssh my_webdev_server -L "8080:0:8080"
```
