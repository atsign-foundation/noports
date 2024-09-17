---
icon: linux
description: Installation of client and server software
---

# Linux & MacOS Installation Guide

{% embed url="https://player.vimeo.com/video/1004237823?amp;app_id=58479&amp;autopause=0&amp;badge=0&amp;byline=0&amp;player_id=0&amp;portrait=0&title=0" %}

For more control of the installation look at the [advanced-installation-guides](../advanced-installation-guides/ "mention").

| Legend     | Meaning                   |
| ---------- | ------------------------- |
| :desktop:  | Client Side               |
| :printer:  | Device side               |
| \<REPLACE> | Fill in with your details |

## :desktop: Step 1:  Install on the Client machine&#x20;

{% hint style="danger" %}
If you don't own a pair of atSigns/addresses, please visit [the registrar](https://my.noports.com/no-ports-invite/14dayfreetrial) before continuing
{% endhint %}

### (1.1) Download the Installer

First, make sure that you have [curl](https://curl.se) available on your system, curl is a common shell utility.

The following command will download the `universal.sh` bash installer into your current directory:

```sh
curl -L https://github.com/atsign-foundation/noports/releases/latest/download/universal.sh -o universal.sh
```

To check if the installation downloaded correctly:

```bash
ls | grep -w "universal.sh"
```

### (1.2) Run the Installer

Make the script executable and run the script.

```sh
chmod u+x universal.sh
./universal.sh
```

Type in **`client`** when asked for what type of install. Continue following along with the instructions provided with the installer until the installation is complete.

#### Useful tips when answering the client installation

Your client atSign should look like : `@sshnp_client`

Your device atSign should look like: `@sshnp_device`

[Device name](installation-details.md#device-names) should look like:  `my_host, pi3, home_server_2`

### (1.3) [Activate Client atSign (e.g. @sshnp\_client)](activating-your-atsigns.md#activate-the-client-atsign)

This command activates your atSign and prompts you to enter an OTP. This is only done during the setup of a brand new atsign.

```
~/.local/bin/at_activate -a @<REPLACE>_client
```

#### Enter the One Time Password (OTP) & Check your SPAM/PROMOTIONS folders

at\_activate will pause and wait for the input of a one time pin (OTP) sent to your email or phone number.  \
\
Once activated, the master keys will save at `~/.atsign/keys`.

### (1.4) [Activate Device atSign (e.g. @sshnp\_device)](activating-your-atsigns.md#activate-the-device-atsign)

This command activates your atSign and prompts you to enter an OTP. This is only done during the setup of a brand new atsign.

```
~/.local/bin/at_activate -a @<REPLACE>_device
```

#### Enter the One Time Password (OTP) & Check your SPAM/PROMOTIONS folders

at\_activate will pause and wait for the input of a one time pin (OTP) sent to your email or phone number.&#x20;

Once activated, the master keys will save at `~/.atsign/keys`.

{% hint style="success" %}
Your client machine software installation is completed. Now, on to the device/server
{% endhint %}

***

## :printer: Step 2 : Installing the Device

### (2.1) Download the installer&#x20;

```bash
curl -L https://github.com/atsign-foundation/noports/releases/latest/download/universal.sh -o universal.sh
```

To check if the installation downloaded correctly:

```bash
ls | grep -w "universal.sh"
```

### (2.2) Run the installer

```bash
chmod u+x universal.sh
./universal.sh
```

The script will guide you through the installation process. It will prompt you for the information you need. Make sure you type in `device` when it asks what type of installation.\
&#x20;\
**You will need the client atSign, device atSign and the device name. making sure they match your earlier choices.**

***

## Step 3: Authorizing atSigns

### (3.1) :desktop:: Generate a passcode

On the **client machine**, run the following command. It should output a 6-character passcode.

```bash
~/.local/bin/at_activate otp -a @<REPLACE>_device
```

### (3.2) :printer:: Make an authorization request from your device machine

On the **device machine**, run the following command, using the DEVICE\_NAME that you chose while running the installer earlier

<pre class="language-bash"><code class="lang-bash"><strong>~/.local/bin/at_activate enroll -a @&#x3C;REPLACE>_device \
</strong><strong>  -s &#x3C;PASSCODE> \
</strong><strong>  -p noports \
</strong><strong>  -k ~/.atsign/keys/@&#x3C;REPLACE>_device_key.atKeys \
</strong><strong>  -d &#x3C;DEVICE_NAME> \
</strong><strong>  -n "sshnp:rw,sshrvd:rw"
</strong></code></pre>

#### Once you see this text, you're ready to continue to the next step.

```
Submitting enrollment request 
Enrollment ID: ---------------------
Waiting for approval; will check every 10 seconds
```

### (3.3) :desktop:: Approve the authorization request

On the **client machine**, run the following command

```bash
~/.local/bin/at_activate approve -a @<REPLACE>_device \
  --arx noports \
  --drx <DEVICE_NAME>
```

{% hint style="success" %}
Installation Complete!\
\
You are ready to use SSH No Ports, visit the [basic-usage-1](../../usage/basic-usage-1/ "mention").
{% endhint %}

### [#want-to-use-your-client-atsign-on-a-different-machine](installation-details.md#want-to-use-your-client-atsign-on-a-different-machine "mention")
