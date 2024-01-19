# 🖥 Device installation (sshnpd)

## Overview

The SSH No Ports daemon (a.k.a. sshnpd) is available as a background service in three forms. The service may be installed as a `systemd unit`, in a `tmux session`, or as a background job using `cron` and `nohup`. The binaries can also be installed standalone so that you can install your own custom background service.

### No Windows Support

SSH No Ports for Windows is in beta, and we currently don't offer sshnpd as part of our releases. \
If this is something you would like for us to prioritize, please let us know through one of the following options:

* Create a new [GitHub issue](https://github.com/atsign-foundation/noports/issues/new/choose)
* Join [our discord](https://discord.atsign.com) and post to our `📑｜forum` channel
* [Contact support via email](mailto:support@noports.com)

## Download

You can [download a release from GitHub](https://github.com/atsign-foundation/noports/releases/), or see the table below to download the latest release for your platform.

| Platform | Linux                                                                                                                | macOS                                                                                                                        |
| -------- | -------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| x64      | [sshnp-linux-x64.tgz](https://github.com/atsign-foundation/noports/releases/latest/download/sshnp-linux-x64.tgz)     | [sshnp-macos-x64.zip](https://github.com/atsign-foundation/noports/releases/latest/download/sshnp-macos-x64.zip) (intel)     |
| arm64    | [sshnp-linux-arm64.tgz](https://github.com/atsign-foundation/noports/releases/latest/download/sshnp-linux-arm64.tgz) | [sshnp-macos-arm64.zip](https://github.com/atsign-foundation/noports/releases/latest/download/sshnp-macos-arm64.zip) (apple) |
| arm      | [sshnp-linux-arm.tgz](https://github.com/atsign-foundation/noports/releases/latest/download/sshnp-linux-arm.tgz)     |                                                                                                                              |
| risc-v   | [sshnp-linux-riscv.tgz](https://github.com/atsign-foundation/noports/releases/latest/download/sshnp-linux-riscv.tgz) |                                                                                                                              |

### &#x20;Download using curl

{% tabs %}
{% tab title="Linux" %}
**x64:**

```sh
curl -fSL https://github.com/atsign-foundation/noports/releases/latest/download/sshnp-linux-x64.tgz -o sshnp.tgz
```

**arm64:**

```bash
curl -fSL https://github.com/atsign-foundation/noports/releases/latest/download/sshnp-linux-arm64.tgz -o sshnp.tgz
```

**arm:**

```bash
curl -fSL https://github.com/atsign-foundation/noports/releases/latest/download/sshnp-linux-arm.tgz -o sshnp.tgz
```

**risc-v:**

```bash
curl -fSL https://github.com/atsign-foundation/noports/releases/latest/download/sshnp-linux-riscv.tgz -o sshnp.tgz
```
{% endtab %}

{% tab title="macOS" %}
**x64 (intel):**

```bash
curl -fSL https://github.com/atsign-foundation/noports/releases/latest/download/sshnp-macos-x64.zip -o sshnp.zip
```

**arm64 (apple):**

```bash
curl -fSL https://github.com/atsign-foundation/noports/releases/latest/download/sshnp-macos-arm64.zip -o sshnp.zip
```
{% endtab %}
{% endtabs %}

## Unpack the Archive

{% tabs %}
{% tab title="Linux" %}
```bash
tar -xf sshnp.tgz
```
{% endtab %}

{% tab title="macOS" %}
```bash
unzip sshnp.zip
```
{% endtab %}
{% endtabs %}

## Activate your device address

It is important that you activate your device address **before** installing the background service, otherwise the background service will fail to start.

If you don't own a pair of addresses, you can obtain them from [noports.com](https://noports.com).

If you haven't activated the device address before, follow the [activate an address guide](activate-an-address-a.k.a.-atsign.md) for the [**device address**](#user-content-fn-1)[^1].

If you have activated the device address before, you must copy the address from another machine where it's been activated. The address will be located at [`~/.atsign/keys/<address_name>_key.atKeys`](#user-content-fn-2)[^2]. Copy this file from your other machine to the same location on the machine that you are installing sshnpd on.

## Install sshnpd

Installation methods:

1. [Systemd unit](device-installation-sshnpd.md#systemd-unit-method) - recommended for Linux
2. [Tmux session](device-installation-sshnpd.md#tmux-session) - recommended for macOS
3. [Headless (cron + nohup)](device-installation-sshnpd.md#headless-cron--nohup)
4. [Standalone binaries](device-installation-sshnpd.md#standalone-binaries)

### Systemd unit

{% tabs %}
{% tab title="Linux" %}
1. First, change directories into the unpacked download:

```sh
cd sshnp
```

2. Then run the installer:

```sh
sudo ./install.sh systemd sshnpd
```

This installer must be run as root.
{% endtab %}

{% tab title="macOS" %}
Not available for macOS
{% endtab %}
{% endtabs %}

#### Configure the service file

After installing the systemd unit, we must configure it. This requires root privileges.

```bash
sudo vi /etc/systemd/system/sshnpd.service
```

You'll then be greeted with a file that looks like this:

{% @github-files/github-code-block url="https://github.com/atsign-foundation/noports/blob/trunk/packages/dart/sshnoports/bundles/shell/systemd/sshnpd.service" %}

Replace `<username>` with the [linux user ](#user-content-fn-3)[^3]running sshnpd

Replace `<@device_atsign>` with the [device address](#user-content-fn-4)[^4]

Replace `<@manager_atsign>` with the [client address](#user-content-fn-5)[^5]

Replace `<device_name>` with your own [custom **unique** identifier](#user-content-fn-6)[^6] for this device

Add any additional config to the end of the line where sshnpd is run, some useful flags you should consider adding:

* `-u` : "unhide" the device, sharing the username and making it discoverable by `sshnp --list-devices`
* `-s` : "ssh-public-key", allow ssh public keys to be shared by sshnp and automatically authorized by sshd, saves you from dealing with ssh public key management. If multiple people use the device, we recommend leaving this off and managing ssh public keys yourself.
* To see the rest of the available options run sshnpd to see the usage.

#### Enable the service

Using `systemctl` we can enable and start the sshnpd service.

```bash
sudo systemctl enable sshnpd.service
sudo systemctl start sshnpd.service
```

#### Observing the service

If you need to verify the status of the service:

```bash
sudo systemctl status sshnpd.service
```

#### All done!

Your systemd service is ready to go, you can now proceed to [installing your client](client-installation-sshnp.md), or if you've already done that, checkout our [usage guide](../usage-guide/basic-usage.md).

### Tmux session

{% tabs %}
{% tab title="Linux" %}
1. First, ensure tmux is installed on your machine:

```sh
[[ -n $(command -v tmux) ]] && echo 'Good to go!' || echo 'Uh oh! Install tmux before continuing...'
```

If tmux is not available, a quick web search of `Install tmux for <your distro>` should help you easily install it. Most distros include the tmux package in their repository.

2. Change directories into the unpacked download:

```sh
cd sshnp
```

3. Then run the installer:

```sh
./install.sh tmux sshnpd
```

This will install the binaries to `~/.local/bin`.\
Instead, if you'd like to install the binaries to `/usr/local/bin`, run the installer as root:

```sh
sudo ./install.sh tmux sshnpd
```
{% endtab %}

{% tab title="macOS" %}
1. First, ensure tmux is installed on your machine:

```sh
[[ -n $(command -v tmux) ]] && echo 'Good to go!' || echo 'Uh oh! Install tmux before continuing...'
```

If tmux is not available, the recommended way to install tmux on macOS is with [homebrew](https://brew.sh).

```sh
[[ -n $(command -v brew) ]] && brew install tmux || echo 'brew not installed, first install brew at https://brew.sh, then run this command again.'
```

2. Change directories into the unpacked download:

```sh
cd sshnp
```

3. Then run the installer:

```sh
./install.sh tmux sshnpd
```

This will install the binaries to `~/.local/bin`.\
Instead, if you'd like to install the binaries to `/usr/local/bin`, run the installer as root:

```sh
sudo ./install.sh tmux sshnpd
```
{% endtab %}
{% endtabs %}

#### Configure the startup script

After installing the startup script, we must configure it.

```bash
vi ~/.local/bin/sshnpd.sh
```

You'll then be greeted with a file that looks like this:

{% @github-files/github-code-block url="https://github.com/atsign-foundation/noports/blob/trunk/packages/dart/sshnoports/bundles/shell/headless/sshnpd.sh" %}

Replace `$user` with the [linux user ](#user-content-fn-7)[^7]running sshnpd

Replace `$device_atsign` with the [device address](#user-content-fn-8)[^8]

Replace `$manager_atsign` with the [client address](#user-content-fn-9)[^9]

Replace `$device_name` with your own [custom **unique** identifier](#user-content-fn-10)[^10] for this device

Add any additional config to the end of the line where sshnpd is run, some useful flags you should consider adding:

* `-u` : "unhide" the device, sharing the username and making it discoverable by `sshnp --list-devices`
* `-s` : "ssh-public-key", allow ssh public keys to be shared by sshnp and automatically authorized by sshd, saves you from dealing with ssh public key management. If multiple people use the device, we recommend leaving this off and managing ssh public keys yourself.
* To see the rest of the available options run sshnpd to see the usage.

#### Start the service

The tmux service will automatically be started by the `cron @reboot` directive when your machine restarts. If you would like to start it immediately, note that you must make sure to disown the tmux process so that it doesn't hangup when you logout.

Run the following command to start it immediately:

```bash
nohup &>/dev/null tmux new-session -d -s sshnpd && tmux send-keys -t sshnpd $HOME/.local/bin/sshnpd.sh C-m
```

#### Observing the service

You can use regular tmux commands to observe the service:

```bash
tmux a -t sshnpd
```

{% hint style="info" %}
To detach from the tmux session use the keybind `Ctrl + B, D`.  This will safely detach from the tmux session without killing it.
{% endhint %}

#### All done!

Your tmux session is ready to go, you can now proceed to [installing your client](client-installation-sshnp.md), or if you've already done that, checkout our [usage guide](../usage-guide/basic-usage.md).

### Headless (cron + nohup)

{% hint style="warning" %}
It is important to note that the log files of the headless job have the potential to grow infinitely. We recommend implementing a logrotate cron job to prevent this.
{% endhint %}

{% tabs %}
{% tab title="Linux" %}
1. Change directories into the unpacked download:

```sh
cd sshnp
```

2. Then run the installer:

```sh
./install.sh headless sshnpd
```

This will install the binaries to `~/.local/bin`.\
Instead, if you'd like to install the binaries to `/usr/local/bin`, run the installer as root:

```sh
sudo ./install.sh headless sshnpd
```
{% endtab %}

{% tab title="macOS" %}
1. Change directories into the unpacked download:

```sh
cd sshnp
```

2. Then run the installer:

```sh
./install.sh headless sshnpd
```

This will install the binaries to `~/.local/bin`.\
Instead, if you'd like to install the binaries to `/usr/local/bin`, run the installer as root:

```sh
sudo ./install.sh headless sshnpd
```
{% endtab %}
{% endtabs %}

#### Configure the startup script

After installing the startup script, we must configure it.

```bash
vi ~/.local/bin/sshnpd.sh
```

You'll then be greeted with a file that looks like this:

{% @github-files/github-code-block url="https://github.com/atsign-foundation/noports/blob/trunk/packages/dart/sshnoports/bundles/shell/headless/sshnpd.sh" %}

Replace `$user` with the [linux user ](#user-content-fn-11)[^11]running sshnpd

Replace `$device_atsign` with the [device address](#user-content-fn-12)[^12]

Replace `$manager_atsign` with the [client address](#user-content-fn-13)[^13]

Replace `$device_name` with your own [custom **unique** identifier](#user-content-fn-14)[^14] for this device

Add any additional config to the end of the line where sshnpd is run, some useful flags you should consider adding:

* `-u` : "unhide" the device, sharing the username and making it discoverable by `sshnp --list-devices`
* `-s` : "ssh-public-key", allow ssh public keys to be shared by sshnp and automatically authorized by sshd, saves you from dealing with ssh public key management. If multiple people use the device, we recommend leaving this off and managing ssh public keys yourself.
* To see the rest of the available options run sshnpd to see the usage.

{% hint style="warning" %}
This service does not do log rotations of the logs stored at `$HOME/.sshnpd/logs`.

It is recommended that you implement a cron job which handles log rotations.
{% endhint %}

#### Start the service

The headless service will automatically be started by the `cron @reboot` directive when your machine restarts. If you would like to start it immediately, note that you must make sure to disown the process so that it doesn't hangup when you logout.

Run the following command to start it immediately:

```bash
nohup $HOME/.local/bin/sshnpd.sh > $HOME/.sshnpd/logs/sshnpd.log 2> $HOME/.sshnpd/logs/sshnpd.err &
```

#### Observing the service

The service should already be running in the background, to observe the logs:

```bash
tail -f $HOME/.sshnpd/logs/sshnpd.log
tail -f $HOME/.sshnpd/logs/sshnpd.err
```

{% hint style="info" %}
Most of the logs will be found in `sshnpd.err`, it is usually worth checking that file first
{% endhint %}

#### All done!

Your headless job is ready to go, you can now proceed to [installing your client](client-installation-sshnp.md), or if you've already done that, checkout our [usage guide](../usage-guide/basic-usage.md).

### Standalone binaries

{% tabs %}
{% tab title="Linux" %}
1. Change directories into the unpacked download:

```sh
cd sshnp
```

2. Then run the installer:

```sh
./install.sh sshnpd
```

This will install the binaries to `~/.local/bin`.\
Instead, if you'd like to install the binaries to `/usr/local/bin`, run the installer as root:

```sh
sudo ./install.sh sshnpd
```
{% endtab %}

{% tab title="macOS" %}
1. Change directories into the unpacked download:

```sh
cd sshnp
```

2. Then run the installer:

```sh
./install.sh sshnpd
```

This will install the binaries to `~/.local/bin`.\
Instead, if you'd like to install the binaries to `/usr/local/bin`, run the installer as root:

```sh
sudo ./install.sh sshnpd
```
{% endtab %}
{% endtabs %}

From here, you are on your own for setting up sshnpd.

#### What next?

Once sshnpd is ready to go, you can now proceed to [installing your client](client-installation-sshnp.md), or if you've already done that, checkout our [usage guide](../usage-guide/basic-usage.md).

[^1]: device address only, activate the client address from the client machine.

[^2]: where `<address_name>` is the name of your device address e.g. `@alice_device`

[^3]: If you aren't sure, type "echo $USER" in your terminal.

[^4]: e.g. @alice\_device

[^5]: e.g. @alice\_client

[^6]: This device name is how you distinguish between all of the devices you have running sshnpd.

[^7]: If you aren't sure, type "echo $USER" in your terminal.

[^8]: e.g. @alice\_device

[^9]: e.g. @alice\_client

[^10]: This device name is how you distinguish between all of the devices you have running sshnpd.

[^11]: If you aren't sure, type "echo $USER" in your terminal.

[^12]: e.g. @alice\_device

[^13]: e.g. @alice\_client

[^14]: This device name is how you distinguish between all of the devices you have running sshnpd.
