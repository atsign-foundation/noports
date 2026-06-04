---
description: Integrate RDP and VNC over NoPorts using Remmina (Linux)
icon: display
---

# Remmina Config

Remmina is a Remote Desktop client for Linux which supports a number of remote access protocols. This guide will walk you through setting up Remmina to connect over NoPorts. While it focuses on VNC and RDP, it should work for most of the other protocols available through Remmina.

Prerequisites:

* Linux Desktop
* [NoPorts Cli binaries](../installation/connecting-from-linux/) installed

### Installing Remmina and Plugins

Dependent on your distribution, the steps may vary. Remmina is quite popular, so you should be able to web search your way to installing Remmina.

{% hint style="warning" %}
When installing Remmina, make sure it is not installed to a sandboxed environment such as Flatpak, otherwise the "Execute a Command" feature in Remmina will not work.
{% endhint %}

In most cases, the package name is `remmina` and you will need to make sure that some optional dependencies are installed:

* `freerdp` - if you want to use RDP (a.k.a. Windows app) with Remmina
* `libvncserver` - if you want to VNC (a.k.a. MacOS screen sharing) with Remmina

If you already have Remmina running, you may need to restart it after installing these optional dependencies, otherwise they won't appear as options to create profiles for. By default, Remmina won't full quit when you close the window. So, check your app tray to full quit, or use the `killall remmina` command.

### Getting the path to npt

If Remmina doesn't have access to the `PATH`, it may not be able to find `npt` . To mitigate this, we will use the absolute path when we create our hook for Remmina.

&#x20;Run the following command:

```bash
which npt
```

The command should output a path such as:

```
/usr/local/bin/npt
```

Save this path for later; we will use it during profile creation.

### Setting up an RDP profile

Create a new profile. There are four settings we should change on this screen:

* Name: a nickname for your profile, anything you want.
* Protocol: RDP
* Server: The loopback interface IP address followed by a random free local port of your choice.
  * Make sure the port is unique per profile, or you can only use one at a time.
* Username: The username of the account you want to log in as.

<div align="left" data-full-width="false"><figure><img src="../.gitbook/assets/image (1) (1).png" alt=""><figcaption></figcaption></figure></div>

Now go to the `Behavior` tab.

Here, we need to craft an npt command that will get us access to RDP on the remote machine.

```bash
/usr/local/bin/npt -f @your_client -t @your_device -d device_name -r @rv_am --lp 12345 -p 3389 -x
```

Breaking down this command:

<table><thead><tr><th width="302.5">Command portion</th><th>Explanation</th></tr></thead><tbody><tr><td><code>/usr/local/bin/npt</code></td><td>Run the npt command</td></tr><tr><td><code>-f @your_client</code></td><td>The "from" Atsign (Atsign of the current computer)</td></tr><tr><td><code>-t @your_device</code></td><td>The "to" Atsign (Atsign of the device you're connecting to)</td></tr><tr><td><code>-d device_name</code></td><td>The device name you gave when you setup sshnpd</td></tr><tr><td><code>-r @rv_am</code></td><td>The Atsign of the relay you want to use</td></tr><tr><td><code>--lp 12345</code> </td><td>The local port, must match the port we added on the basic page.</td></tr><tr><td><code>-p 3389</code> </td><td>The remote port, 3389 is the canonical RDP port</td></tr><tr><td><code>-x</code></td><td>Tell npt to exit when connected<br>(which tells remmina npt is ready for it to connect)</td></tr></tbody></table>

Place this command in the "Before connecting" field.

<figure><img src="../.gitbook/assets/image (3).png" alt=""><figcaption></figcaption></figure>

Save the profile, then use it to connect. At first, you will see a popup window that Remmina opens when it runs the command. That window will automatically close if the command is successful, at which point it will start the RDP connection.

### Setting up a VNC profile

Create a new profile. There are four settings we should change on this screen:

* Name: a nickname for your profile, anything you want.
* Protocol: VNC
* Server: The loopback host followed by a random free local port of your choice.
  * Make sure the port is unique per profile, or you can only use one at a time.
* Username: The username of the account you want to login as.

<figure><img src="../.gitbook/assets/image (4).png" alt=""><figcaption></figcaption></figure>

Now go to the `Behavior` tab.

Here, we need to craft an npt command that will get us access to RDP on the remote machine.

```bash
/usr/local/bin/npt -f @your_client -t @your_device -d device_name -r @rv_am --lp 56789 -p 5900 -x
```

Breaking down this command:

<table><thead><tr><th width="302.5">Command portion</th><th>Explanation</th></tr></thead><tbody><tr><td><code>/usr/local/bin/npt</code></td><td>Run the npt command</td></tr><tr><td><code>-f @your_client</code></td><td>The "from" Atsign (Atsign of the current computer)</td></tr><tr><td><code>-t @your_device</code></td><td>The "to" Atsign (Atsign of the device you're connecting to)</td></tr><tr><td><code>-d device_name</code></td><td>The device name you gave when you setup sshnpd</td></tr><tr><td><code>-r @rv_am</code></td><td>The Atsign of the relay you want to use</td></tr><tr><td><code>--lp 56789</code> </td><td>The local port, must match the port we added on the basic page</td></tr><tr><td><code>-p 5900</code> </td><td>The remote port, 5900 is the canonical VNC port on MacOS</td></tr><tr><td><code>-x</code></td><td>Tell npt to exit when connected<br>(which tells remmina npt is ready for it to connect)</td></tr></tbody></table>

Place this command in the "Before connecting" field.

<figure><img src="../.gitbook/assets/image (6).png" alt=""><figcaption></figcaption></figure>

Save the profile, then use it to connect. At first, you will see a popup window that Remmina opens when it runs the command. That window will automatically close if the command is successful, at which point it will start the VNC connection.

### Troubleshooting

If you have trouble, try running the npt command in a terminal first. If you run into issues, then you know it is your npt command. If the command does work in a terminal, then it is likely something with your Remmina configuration, you may have to tweak additional settings.
