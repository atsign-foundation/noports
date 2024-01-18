# 👩💻 Client installation (sshnp)

## Overview

The SSH No Ports client (a.k.a. sshnp) is available as a command line application or desktop application (alpha). This guide is for installing the command line application, the desktop application installation guide will be made available upon official release.

## Download

You can [download a release from GitHub](https://github.com/atsign-foundation/noports/releases/), or see the table below to download the latest release for your platform.

| Platform | Linux                                                                                                                | macOS                                                                                                                        | Windows                                                                                                              |
| -------- | -------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| x64      | [sshnp-linux-x64.tgz](https://github.com/atsign-foundation/noports/releases/latest/download/sshnp-linux-x64.tgz)     | [sshnp-macos-x64.zip](https://github.com/atsign-foundation/noports/releases/latest/download/sshnp-macos-x64.zip) (intel)     | [sshnp-windows-x64.zip](https://github.com/atsign-foundation/noports/releases/latest/download/sshnp-windows-x64.zip) |
| arm64    | [sshnp-linux-arm64.tgz](https://github.com/atsign-foundation/noports/releases/latest/download/sshnp-linux-arm64.tgz) | [sshnp-macos-arm64.zip](https://github.com/atsign-foundation/noports/releases/latest/download/sshnp-macos-arm64.zip) (apple) |                                                                                                                      |
| arm      | [sshnp-linux-arm.tgz](https://github.com/atsign-foundation/noports/releases/latest/download/sshnp-linux-arm.tgz)     |                                                                                                                              |                                                                                                                      |
| risc-v   | [sshnp-linux-riscv.tgz](https://github.com/atsign-foundation/noports/releases/latest/download/sshnp-linux-riscv.tgz) |                                                                                                                              |                                                                                                                      |

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

{% tab title="Windows" %}
**x64:**

```powershell
curl.exe -fSL https://github.com/atsign-foundation/noports/releases/latest/download/sshnp-windows-x64.zip -o sshnp.zip
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

{% tab title="Windows" %}
```powershell
Expand-Archive -Force .\sshnp.zip
```
{% endtab %}
{% endtabs %}

## Activate your client address

If you don't own a pair of addresses, you can obtain them from [noports.com](https://noports.com).

If you haven't activated the client address before, follow the [activate an address guide](activate-an-address-a.k.a.-atsign.md) for the [**client address**](#user-content-fn-1)[^1].

If you have activated the client address before, you must copy the address from another machine where it's been activated. The address will be located at [`~/.atsign/keys/<address_name>_key.atKeys`](#user-content-fn-2)[^2]. Copy this file from your other machine to the same location on the machine that you are currently installing sshnp on.

## Install sshnp

{% tabs %}
{% tab title="Linux" %}
1. First, change directories into the unpacked download:

```sh
cd sshnp
```

2. Then run the installer:

```sh
./install.sh sshnp
```

This will install the binaries to `~/.local/bin`.\
Instead, if you'd like to install the binaries to `/usr/local/bin`, run the installer as root:

```sh
sudo ./install.sh sshnp
```
{% endtab %}

{% tab title="macOS" %}
1. First, change directories into the unpacked download:

```sh
cd sshnp
```

2. Then run the installer:

```sh
./install.sh sshnp
```

This will install the binaries to `~/.local/bin`.\
Instead, if you'd like to install the binaries to `/usr/local/bin`, run the installer as root:

```sh
sudo ./install.sh sshnp
```
{% endtab %}

{% tab title="Windows" %}
Windows doesn't have a dedicated installer at this time.

You can find `sshnp.exe` in the unpacked archive, you may move this binary to wherever you like.
{% endtab %}
{% endtabs %}

## Add bin folder to the path

{% tabs %}
{% tab title="Linux" %}
If you chose not to install as root, you will need to add `~/.local/bin` to your `PATH`.\
Add the following line to your shell's rc file (most likely `~/.zshrc`):

```sh
export PATH="$PATH:$HOME/.local/bin";
```
{% endtab %}

{% tab title="macOS" %}
If you chose not to install as root, you will need to add `~/.local/bin` to your `PATH`.\
Add the following line to your shell's rc file:

```sh
export PATH="$PATH:$HOME/.local/bin";
```
{% endtab %}
{% endtabs %}

## Activate your client address

Before you can use your client, you need an activated noports address in order to continue. See [this guide](activate-an-address-a.k.a.-atsign.md) to learn how to activate it.

## All Done!

sshnp is ready to go, you can now proceed to [installing your device](device-installation-sshnpd.md), or if you've already done that, checkout our [usage guide](../usage-guide/basic-usage.md).

[^1]: client address only, activate the device address from the device.

[^2]: where `<address_name>` is the name of your device address e.g. `@alice_device`
