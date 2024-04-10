---
description: How to  install for either client, device or both.
---

# 💽 Installation Guide

## 1. Download universal.sh

First, make sure that you have curl available on your system. This is a common shell utility, so a simple web search should tell you how to install it.

Then run the following command:

```sh
curl -L https://github.com/atsign-foundation/noports/releases/latest/download/universal.sh -o universal.sh
```

## 2. Run universal.sh

Then make the script executable and run the script.

```sh
chmod u+x universal.sh
./universal.sh
```

The script will guide you through the installation process. It will prompt you for the information you need.

<details>

<summary>Useful tips</summary>

* Client & device address are the addresses you were issued at my.noports.com.
* Device name is a unique name for which you can use to identify your device

</details>

## 3. Activate your address

{% hint style="danger" %}
If you don't own a pair of noports addresses, please visit [the registrar](https://my.noports.com/no-ports-invite/14dayfreetrial) before continuing.
{% endhint %}

{% hint style="warning" %}
If you are installing for the client, you will need to activate / copy the client address on this machine.

If you are installing for the device, you will need to activate / copy the device address on this machine.

If you are installing for both, you will need to activate / copy both addresses on this machine.
{% endhint %}

### 3.a. First time activating your address

We will now activate the client address, you only need to activate the client address now. The device address should be activated during the device installation.

{% tabs %}
{% tab title="Linux" %}
Now that you have at\_activate installed, you can invoke the command with the name of the address you would like to activate:

<pre class="language-bash"><code class="lang-bash"><strong>~/.local/bin/at_activate -a @my_noports_client
</strong></code></pre>
{% endtab %}

{% tab title="macOS" %}
Now that you have at\_activate installed, you can invoke the command with the name of the address you would like to activate:

```bash
~/.local/bin/at_activate -a @my_noports_device
```
{% endtab %}
{% endtabs %}

### Enter the One Time Password (OTP) & Check your SPAM/PROMOTIONS folders

The application will pause and wait for the input of a one time pin (OTP) before you can continue. You should receive this pin to the contact information associated with the registration of your noports address (i.e. email or text message).

{% hint style="warning" %}
If you are using a gmail.com account we have seen that sometimes the OTP gets stuck in the SPAM or PROMOTIONS folder. If you do not see the OTP check those folders.&#x20;
{% endhint %}

Once you receive the message, enter the pin into the application and press enter to continue. The application should proceed to create the cryptographic keys and store them at `~/.atsign/keys/@my_noports_client_key.atKeys`.

An address can only be activated once, to install this address to future devices, you must copy this file to the device (see 3.b.).

### 3.b. Activated this address before

{% hint style="warning" %}
If you have activated the client address before, you must copy the address from another machine where it's been activated.&#x20;
{% endhint %}

The address will be located at `~/.atsign/keys/@my_noports_client_key.atKeys`. Copy this file from your other machine to the same location on the machine that you are installing sshnpd on.

