---
description: Using sshuttle and SSH built in SOCKS proxy.
---

# 🏔️ Be your own VPN

Many of us want to get to our home networks whilst away for work or pleasure, be that to get to machines at home or to get to our local countries stream services like Netflix.

To follow this guide, you will need to set up a SSH No Ports device (`sshnpd)`on your home network, for this you could use a Raspberry Pi an old PC running Linux or a virtual machine, even a docker container, the choice is yours. You can get your NoPorts trial account [here](https://noports.com) and follow the [installation guide](installation-guide/).

SSH is a hugely versatile tool for command line access but what if you want a full IP tunnel like a VPN ?

SSH has you covered, with the use of two tools the first is a built in SOCKS proxy the second an opensource piece of code called `sshuttle`. With these two tools you can use your sshnp service as your own VPN.&#x20;

### The amazing sshuttle&#x20;

Once you have SSH No Ports up and running you will be able to connect to your device from anywhere on the Internet. You will also notice that you did not have to open any ports to the Internet so there is nothing to attack from the Internet.&#x20;

If you are happy with command line access only great, but you might want to now use your ssh connection as a VPN and have a full IP tunnel, for this [sshuttle](https://github.com/sshuttle/sshuttle) is the perfect tool. However, if you are using Windows then you will have to set up a local VM/Container. If that sounds too much skip down to using SOCKS.

To use sshuttle we need to make sure that the ssh command itself can log in without any complex arguments. To do this make sure that you have created ssh keys and have either placed the public keys on the remote device or used the `-s` flag of `sshnp` to place them on the remote `sshnpd`. That requires the `-s` flag to be enabled on the `sshnpd` service/config file.&#x20;

Once the ssh keys are in place then you can put an entry in `~/.ssh/config` to let ssh know which key to use to log into localhost, for example:

```
Host localhost
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    IdentityFile ~/.ssh/id_ed25519
    LogLevel QUIET
```

The next thing to do is install `sshuttle` on your machine, the GitHub page details this very well for Linux and OSX machines.

Once sshuttle is installed let's use it ! This is a two step process, first we connect to the device using `sshnp` but we add the `-x` flag. This flag prints out the ssh command that you can cut and paste to log into the remote device. Once you have done that in another terminal window you can run the sshuttle command to connect to the remote device and tweak your IP routing to use this connection as a VPN. The important part is to use the port number that the `-x` flag gave you in the `sshuttle` command.&#x20;

{% embed url="https://asciinema.org/a/msDJ8hPaVtRFEZZHFbnlNnWGh" %}
Be your own VPN
{% endembed %}

With this example you can see that port `63155` was used in the sshuttle command. You do not need to ssh into the machine you can just get the port number and use `sshuttle` again the choice is yours.



####

### SOCKS

If you are using windows this is going to be your best option unless you are comfortable setting up a virtual machine and using sshuttle.

&#x20;All you need to do is add an option to the normal `sshnp` command and that will set up a local SOCKS proxy `-o "-D 1080"` and that is it!&#x20;

```bash
sshnp -f @my_client -t @my_device -h @rv_am -d my_pi -o "-D 1080"
```

This will set up a local SOCKS proxy on your machine that will forward requests to the remote device. In effect you will be at home whilst away. To use this SOCKS proxy you need to tell your browser or your Operating System. the Firefox browser is the simple choice and in settings you can configure it as shown below:

<figure><img src="../../.gitbook/assets/Screenshot 2024-03-12 at 12.57.14.png" alt=""><figcaption><p>configure your SOCKS proxy</p></figcaption></figure>

Once you have setup Firefox you can browse as if you were at home! On Windows and Mac there are ways to configure your SOCKS proxy in the OS in settings. This works but you have to remember to remove the setting once you have disconnected from the `sshnpd` session.
