---
icon: laptop
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

# Client Installation

There are two steps to getting a client installed:

### 1. Install binaries

As described in [Installation Explained](./) this can be done using the `universal.sh` install script, installing  from a package manager (e.g. apt or dnf for Linux or brew for MacOS), or simply downloading the binary archive from [GitHub releases](https://github.com/atsign-foundation/noports/releases) and expanding it to your preferred destination.

### 1a. Add binaries folder to the path

If binaries are installed to their default location then this shouldn't be necessary, but if they're elsewhere it's recommend that you add the binary install location to the PATH.

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

### 2. Activate your client address

{% hint style="danger" %}
If you don't own a pair of NoPorts addresses, please visit [the registrar](https://my.noports.com/no-ports-plans) before continuing.
{% endhint %}

### 2.1. First time activating your address

We will now activate the client address, you only need to activate the client address now. The device address should be activated during the device installation.

{% tabs %}
{% tab title="Linux" %}
Now that you have at\_activate installed, you can invoke the command with the name of the address you would like to activate:

<pre class="language-bash"><code class="lang-bash"><strong>at_activate -a @my_noports_client
</strong></code></pre>
{% endtab %}

{% tab title="macOS" %}
Now that you have at\_activate installed, you can invoke the command with the name of the address you would like to activate:

```bash
at_activate -a @my_noports_client
```
{% endtab %}
{% endtabs %}

### Enter the One Time Password (OTP) & Check your SPAM/PROMOTIONS folders

The application will pause and wait for the input of a one time pin (OTP) before you can continue. You should receive this pin to the contact information associated with the registration of your noports address (i.e. email or text message).

\*\*\*If you are using a gmail.com account we have seen that sometimes the OTP gets stuck in the SPAM or PROMOTIONS folder. If you do not see the OTP check those folders.

Once you receive the message, enter the pin into the application and press enter to continue. The application should proceed to create the cryptographic keys and store them at `~/.atsign/keys/@my_noports_client_key.atKeys`.

An address can only be activated once, to install this address to future devices, you must copy this file to the device (see 3.b.).

### 2.2. Activated this address before

{% hint style="warning" %}
If you have activated the client address before, you must copy the address from another machine where it's been activated.
{% endhint %}

The address will be located at `~/.atsign/keys/@my_noports_client_key.atKeys`. Copy this file from your other machine to the same location on the machine that you are installing NoPorts on.

### All Done!

sshnp is ready to go, you can now proceed to [installing your device](device-installation-sshnpd/), or if you've already done that, checkout our [usage guide](../../usage/basic-usage-1/).
