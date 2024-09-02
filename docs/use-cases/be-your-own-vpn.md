---
icon: house-signal
description: Using sshuttle and SSH built in SOCKS proxy.
---

# Be your own VPN

To follow this guide, you will need to set up an SSH No Ports device (`sshnpd)`on your home network. For this, you could use a Raspberry Pi, an old PC running Linux, a virtual machine, or even a docker container—the choice is yours. You can get your No Ports free trial account [here](https://noports.com) and follow the [installation guide](../installation/linux/) to get started.

SSH is a hugely versatile tool for command line access, but what if you want a full IP tunnel, like a VPN?

SSH has you covered, with the use of two tools: the first is a built in SOCKS proxy; the second is an open source piece of code called `sshuttle`. With these two tools you can use your sshnp service as your own VPN.&#x20;

### The amazing sshuttle&#x20;

Once you have SSH No Ports up and running, you will be able to connect to your device from anywhere on the Internet. You will notice that you did not have to open any ports to the Internet in order to connect. _There is no access to the device from the Internet and yet you can connect._&#x20;

If you are happy with command line access only, great; but you might want to now use your SSH connection as a VPN and have a full IP tunnel. For this, [sshuttle](https://github.com/sshuttle/sshuttle) is the perfect tool. However, if you are using Windows, then you will have to set up a local VM/Container. (If that sounds like too much, skip down to the section below on using SOCKS.)

To use sshuttle, we need to make sure that the SSH command itself can log in without any complex arguments. This requires two steps:

1. **Create SSH keys:** First, make sure that you have created SSH keys.
2. **Place public keys on the remote device:** Next, either:
   * **Manual placement:** Place the public keys directly on the remote device.
   * &#x20;**`sshnpd`flag:** Or, use the `-s` flag of `sshnp` to place them on the remote `sshnpd`. That requires the `-s` flag to be enabled on the `sshnpd` service/config file.&#x20;

Once the SSH keys are in place, you can put an entry in `~/.ssh/config` to let SSH know which key to use to log into localhost. For example:

```
Host localhost
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    IdentityFile ~/.ssh/id_ed25519
    LogLevel QUIET
```

The next thing to do is install `sshuttle` on your machine. The GitHub page details this very well for both Linux and OSX machines.

Once sshuttle is installed, let's use it !&#x20;

This is a two step process:&#x20;

1. **Connect to the device using `sshnp:`** Add the `-x` flag. This flag prints out the SSH command that you can cut and paste to log into the remote device.&#x20;
2. **Establish the VPN:** In another terminal window, run the sshuttle command to connect to the remote device. You'll need to tweak your IP routing to use this connection as a VPN. **The important part is to use the port number that the** `-x` **flag gave you in the** `sshuttle` **command**.&#x20;

{% embed url="https://asciinema.org/a/msDJ8hPaVtRFEZZHFbnlNnWGh" %}
Be your own VPN
{% endembed %}

With this example, you can see that port `63155` was used in the sshuttle command. You do not need to SSH into the machine—you can just get the port number and use `sshuttle.`  The choice is yours.

This can get a bit tedious to do every day so feel free to script for your environment. Here is an example bash script that does just that!

```bash
#!/bin/bash
#
export USER=$USER
export SSHNPHOME=$HOME/.local/bin <--<default-location-for-SSHNP>
export HOSTDEVICE=<your-host-running-SSHNPD>
export CLIENTATSIGN=<your-local-atsign format @34mypersonalatsign>>
export HOSTATSIGN=<the-host-device-atsign format @55hostdeviceatsign>
export LOCALPORT=<the-port-ito-use-forconnection example 46393>
export SRVD=<atSign-of-srvd-daemon example @rv_eu or @rv_am or @rv_ap>
export NETA=<network-CIDR-style example 0/0 or 10.0.0.0/8>
export NETB=<network-CIDR-style example 172.16.0.0/16>
export NETC=<network-CIDR-style example 192.168.1.0/24>
#
echo ""
echo Starting Atsign SSHNP connects to $HOSTDEVICE on port 46393 for personal VPN
echo ""
#
$SSHNPHOME/sshnp --from $CLIENTATSIGN --to $HOSTATSIGN --srvd $SRVD --remote-user-name $USER --output-execution-command --idle-timeout 90 --device $HOSTDEVICE --local-port $LOCALPORT
sleep 3
sshuttle --dns -r $USER@127.0.0.1:$LOCALPORT $NETA $NETB $NETC 
#
```

### SOCKS

If you are using Windows, this is likely your best option unless you are comfortable setting up a virtual machine and using sshuttle.

&#x20;All you need to do is add an option to the normal `sshnp` command and that will set up a local SOCKS proxy: `-o "-D 1080"`  That's it!&#x20;

```bash
sshnp -f @my_client -t @my_device -h @rv_am -d my_pi -o "-D 1080"
```

This will set up a local SOCKS proxy on your machine that will forward requests to the remote device. In effect, you will be at home whilst away. To use this SOCKS proxy, you need to tell your browser or your Operating System. The Firefox browser is the simple choice, and in settings you can configure it as shown below:

<figure><img src="../.gitbook/assets/Screenshot 2024-03-12 at 12.57.14.png" alt=""><figcaption><p>configure your SOCKS proxy</p></figcaption></figure>

Once you have setup Firefox, you can browse as if you were at home! On Windows and Mac, you can configure your SOCKS proxy in directly in the OS in settings. **This works, but you have to remember to remove the setting once you have disconnected from the `sshnpd` session.**
