---
icon: laptop
---

# Client installation

## Overview

The SSH No Ports client (a.k.a. sshnp) is available as a command line application or desktop application (alpha). This guide is for installing the command line application, the desktop application installation guide will be made available upon official release.

## 1. Download

### 1.a. Download from GitHub

You can [download a release from GitHub](https://github.com/atsign-foundation/noports/releases/), or see the table below to download the latest release for your platform.

| Platform | Linux                                                                                                                | macOS                                                                                                                        | Windows                                                                                                              |
| -------- | -------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| x64      | [sshnp-linux-x64.tgz](https://github.com/atsign-foundation/noports/releases/latest/download/sshnp-linux-x64.tgz)     | [sshnp-macos-x64.zip](https://github.com/atsign-foundation/noports/releases/latest/download/sshnp-macos-x64.zip) (intel)     | [sshnp-windows-x64.zip](https://github.com/atsign-foundation/noports/releases/latest/download/sshnp-windows-x64.zip) |
| arm64    | [sshnp-linux-arm64.tgz](https://github.com/atsign-foundation/noports/releases/latest/download/sshnp-linux-arm64.tgz) | [sshnp-macos-arm64.zip](https://github.com/atsign-foundation/noports/releases/latest/download/sshnp-macos-arm64.zip) (apple) |                                                                                                                      |
| arm      | [sshnp-linux-arm.tgz](https://github.com/atsign-foundation/noports/releases/latest/download/sshnp-linux-arm.tgz)     |                                                                                                                              |                                                                                                                      |
| risc-v   | [sshnp-linux-riscv.tgz](https://github.com/atsign-foundation/noports/releases/latest/download/sshnp-linux-riscv.tgz) |                                                                                                                              |                                                                                                                      |

### 1.b. Download using curl

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

## 2. Unpack the Archive

If you downloaded from GitHub, the file name may be slightly different.

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

## 3. Install sshnp

{% tabs %}
{% tab title="Linux" %}
1. First, change directories into the unpacked download:

```sh
cd sshnp
```

2. Then run the installer:

```sh
./install.sh sshnp && ./install.sh srv
```

This will install the binaries to `~/.local/bin`.\
Instead, if you'd like to install the binaries to `/usr/local/bin`, run the installer as root:

```sh
sudo ./install.sh sshnp && sudo ./install.sh srv
```
{% endtab %}

{% tab title="macOS" %}
1. First, change directories into the unpacked download:

```sh
cd sshnp
```

2. Then run the installer:

```sh
./install.sh sshnp && ./install.sh srv
```

This will install the binaries to `~/.local/bin`.\
Instead, if you'd like to install the binaries to `/usr/local/bin`, run the installer as root:

```sh
sudo ./install.sh sshnp && sudo ./install.sh srv
```
{% endtab %}

{% tab title="Windows" %}
Windows doesn't have a dedicated installer at this time.

You can find `sshnp.exe` in the unpacked archive, you may move this binary to wherever you like.
{% endtab %}
{% endtabs %}

## 4. Add bin folder to the path

This step is optional, but highly recommended.

{% tabs %}
{% tab title="Linux" %}
If you chose not to install as root, you will need to add `~/.local/bin` to your `PATH`.\
Add the following line to your shell's rc file:

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

## 5. Activate your client address

{% hint style="danger" %}
If you don't own a pair of noports addresses, please visit [the registrar](https://my.noports.com/no-ports-invite/14dayfreetrial) before continuing.
{% endhint %}

### 3.a. First time activating your address

We will now activate the client address, you only need to activate the client address now. The device address should be activated during the device installation.

{% tabs %}
{% tab title="Linux" %}
Now that you have at\_activate installed, you can invoke the command with the name of the address you would like to activate:

<pre class="language-bash"><code class="lang-bash"><strong>./at_activate -a @my_noports_client
</strong></code></pre>
{% endtab %}

{% tab title="macOS" %}
Now that you have at\_activate installed, you can invoke the command with the name of the address you would like to activate:

```bash
./at_activate -a @my_noports_device
```
{% endtab %}
{% endtabs %}

### Enter the One Time Password (OTP) & Check your SPAM/PROMOTIONS folders

The application will pause and wait for the input of a one time pin (OTP) before you can continue. You should receive this pin to the contact information associated with the registration of your noports address (i.e. email or text message).

\*\*\*If you are using a gmail.com account we have seen that sometimes the OTP gets stuck in the SPAM or PROMOTIONS folder. If you do not see the OTP check those folders.&#x20;

Once you receive the message, enter the pin into the application and press enter to continue. The application should proceed to create the cryptographic keys and store them at `~/.atsign/keys/@my_noports_client_key.atKeys`.

An address can only be activated once, to install this address to future devices, you must copy this file to the device (see 3.b.).

### 3.b. Activated this address before

{% hint style="warning" %}
If you have activated the client address before, you must copy the address from another machine where it's been activated.&#x20;
{% endhint %}

The address will be located at `~/.atsign/keys/@my_noports_client_key.atKeys`. Copy this file from your other machine to the same location on the machine that you are installing sshnpd on.

## All Done!

sshnp is ready to go, you can now proceed to [installing your device](device-installation-sshnpd/), or if you've already done that, checkout our [usage guide](../../usage/basic-usage-1/).
