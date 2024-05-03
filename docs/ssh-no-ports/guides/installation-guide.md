---
description: Installation of client and server software
---

# 💽 Simple Installation Guide Linux/MacOS

{% embed url="https://www.youtube.com/watch?v=HSthe7wVGao" %}
Prefer to follow along to a video ? Great !  Below you can just cut and paste along with Colin.&#x20;
{% endembed %}

{% hint style="info" %}
For more control of the installation look at the Advanced Installation guides.
{% endhint %}

## Getting things ready for installation

SSH No Ports software needs to be installed on both the machine you are going to SSH to (device) and the machine you are going to SSH from (client). SSH No Ports uses [atSigns](https://atsign.com/faqs/) as addresses and you will need two one for the client and one for the device

Example client atSign&#x20;

```
@sshnp_client
```

Example device atSign

```
@sshnp_device
```

{% hint style="danger" %}
If you don't own a pair of atSigns/addresses, please visit [the registrar](https://my.noports.com/no-ports-invite/14dayfreetrial) before continuing.
{% endhint %}

You will also need to have a name for the device you want to log into. Each device atSign can be used for multiple devices and so each device needs a unique name.  The device name is limited to alphanumeric [snake case](https://www.tuple.nl/knowledge-base/snake-case) (lowercase alphanumeric separated by \_ ) up to 36 characters.

Example snake case device names

```
my_host
canary02
oci_mail_0001
dc_001_row_009_rack_0067_ru_014
```

{% hint style="success" %}
Once you have these you are ready !
{% endhint %}

* [x] Client atSIgn (e.g. @sshnp\_client)
* [x] Device atSign (e.g. @sshnp\_device)
* [x] Device name (e.g. my\_host\_01)

## _On the client machine_

## SSH Keys

SSH uses keys to authenticate as well as having a fallback of using passwords, but using keys is easier and more secure than "mypassword!". If you already are a seasoned user of SSH then you might have keys already but if not then on the client machine you can create a key pair using ssh-keygen.

Example ssh-keygen command to create SSH Key Pair

```
ssh-keygen -t ed25519 -a 100 -f ~/.ssh/id_ed25519
```

## Download universal.sh

First, make sure that you have curl available on your system. This is a common shell utility, so a simple web search should tell you how to install it.

Then run the following command:

```sh
curl -L https://github.com/atsign-foundation/noports/releases/latest/download/universal.sh -o universal.sh
```

## Run universal.sh

Then make the script executable and run the script.

```sh
chmod u+x universal.sh
./universal.sh
```

The script will guide you through the installation process. It will prompt you for the information you need. Make sure you select `client` when it asks what type of installation.

<details>

<summary>Useful tips when answering the client installation</summary>

* Your client atSign for example&#x20;
  * ```bash
    @sshnp_client
    ```
* Your device atSign for example
  * ```
    @sshnp_device
    ```
* Device name is a unique name for which you can use to identify your device. e.g.
  * ```
    my_host
    ```
* Home region - default Socket Rendezvous location
  * ```
    am
    ```

</details>

## Activate your Client atSign

### First time activating this atSign

We will now activate the client address, you only need to activate the client address now. The device address should be activated during the device installation.

{% tabs %}
{% tab title="Linux" %}
Now that you have at\_activate installed, you can invoke the command with the name of the address you would like to activate:

<pre class="language-bash"><code class="lang-bash"><strong>~/.local/bin/at_activate -a @&#x3C;REPLACE>_client
</strong></code></pre>
{% endtab %}

{% tab title="macOS" %}
Now that you have at\_activate installed, you can invoke the command with the name of the address you would like to activate:

```bash
~/.local/bin/at_activate -a @<REPLACE>_client
```
{% endtab %}
{% endtabs %}

### Enter the One Time Password (OTP) & Check your SPAM/PROMOTIONS folders

The application will pause and wait for the input of a one time pin (OTP) before you can continue. You should receive this pin to the contact information associated with the registration of your noports address (i.e. email or text message).

{% hint style="warning" %}
If you are using a gmail.com account we have seen that sometimes the OTP gets stuck in the SPAM or PROMOTIONS folder. If you do not see the OTP check those folders.&#x20;
{% endhint %}

Once you receive the message, enter the pin into the application and press enter to continue. The application should proceed to create the cryptographic keys and store them in the  `~/.atsign/keys/` directory with a filename that includes the atSign.

### Activated this atSign before ?

{% hint style="warning" %}
If you have activated the client address before, you must copy the atSign from the machine where it's been activated in the past.
{% endhint %}

The atSign keys file will be located at `~/.atsign/keys/` directory with a filename that will include the atSign. Copy this file from your other machine to the same location on the machine that you are installing SSH No Ports on, using `scp` or similar.

{% hint style="success" %}
Your client machine software installation is completed now on to the device/server
{% endhint %}



## _On the device you want to SSH to_

The instructions are very similar to the client install&#x20;

### Download the universal installer&#x20;

```
curl -L https://github.com/atsign-foundation/noports/releases/latest/download/universal.sh -o universal.sh
```

## Run the installer

```
chmod u+x universal.sh
./universal.sh
```

This time you can enter `device` and the questions are a little easier, but you will need the client atSign, device atSign and the device name. making sure they match your earlier choices.

<details>

<summary>Useful tips for installing the device</summary>

* Your client atSign for example&#x20;
  * ```
    @sshnp_client
    ```
* Your device atSign for example
  * ```
    @sshnp_device
    ```
* Device name is a unique name for which you can use to identify your device. e.g.
  * ```
    my_host
    ```

</details>

## Activate the device atSign

### First time activating this atSign

<pre><code><strong>~/.local/bin/at_activate -a @&#x3C;REPLACE>_device
</strong></code></pre>

### Activated this atSign before ?

&#x20;As before if this atSign is already activated elsewhere then you need to copy the .atKeys file for this atSign into the `~/.atsign/keys/` directory.

{% hint style="success" %}
You are ready to go back to the client and use SSH No Ports&#x20;
{% endhint %}
