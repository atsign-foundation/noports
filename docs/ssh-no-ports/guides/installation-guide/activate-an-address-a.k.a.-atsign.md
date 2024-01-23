# 📌 Activate an address (a.k.a. atSign)

## Overview

Both sshnp and sshnpd require activated noports addresses, also known as atSigns.

Both devices where sshnp and sshnpd run must have a noports address. This noports address is a set of cryptographic keys which provide the device access to the atServer which enables secure end-to-end encrypted communication between sshnp and sshnpd.

## Install at\_activate

If you are coming from the client installation guide or device installation guide, you should already have an unpacked download of the release contained in the sshnp directory.

{% tabs %}
{% tab title="Linux" %}
1. First, change directories into the unpacked download:

```sh
cd sshnp
```

2. Then run the installer:

```sh
./install.sh at_activate
```

This will install the binaries to `~/.local/bin`.\
Instead, if you'd like to install the binaries to `/usr/local/bin`, run the installer as root:

```sh
sudo ./install.sh at_activate
```
{% endtab %}

{% tab title="macOS" %}
1. First, change directories into the unpacked download:

```sh
cd sshnp
```

2. Then run the installer:

```sh
./install.sh at_activate
```

This will install the binaries to `~/.local/bin`.\
Instead, if you'd like to install the binaries to `/usr/local/bin`, run the installer as root:

```sh
sudo ./install.sh at_activate
```
{% endtab %}

{% tab title="Window" %}
Windows doesn't have a dedicated installer at this time.

You can find `at_activate.exe` in the unpacked archive, you may move this binary to wherever you like.
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

## Activate an address

{% tabs %}
{% tab title="Linux" %}
Now that you have at\_activate installed, you can invoke the command with the name of the address you would like to activate:

```bash
at_activate -a @my_noports_address
```
{% endtab %}

{% tab title="macOS" %}
Now that you have at\_activate installed, you can invoke the command with the name of the address you would like to activate:

```bash
at_activate -a @my_noports_address
```
{% endtab %}

{% tab title="Windows" %}
Now that you have at\_activate installed, you can invoke the command with the name of the address you would like to activate:

```powershell
at_activate.exe -a @my_noports_address
```
{% endtab %}
{% endtabs %}

### Enter the OTP

The application will pause and wait for the input of a one time pin (OTP) before you can continue. You should receive this pin to the contact information associated with the registration of your noports address (i.e. email or text message).&#x20;

Once you receive the message, enter the pin into the application and press enter to continue. The application should proceed to create the cryptographic keys and store them at [`~/.atsign/keys/<address_name>_key.atKeys`](#user-content-fn-1)[^1].&#x20;

Following the example from above, `@my_noports_address` will be activated to `~/.atsign/keys/@my_noports_address_key.atKeys`.

An address can only be activated once, to install this address to another device, you must copy this file to the device.

[^1]: where `<address_name>` is the name of your device address e.g. `@alice_device`
