---
description: How to install NoPorts when connecting from macOS to Windows
icon: windows
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

# macOS to Windows

### Step 1 to Step 4

These initial steps set up the machine initiating the connection.

<details>

<summary>On the machine you are connecting from</summary>

{% hint style="warning" %}
In this installation guide, `@example01_np` will represent the client Atsign, while `@example02_np` will represent the device Atsign.
{% endhint %}

### <mark style="color:orange;">Step 1:</mark> Download and run the Installer

Open a terminal and download the installer from GitHub by running the following command:

```bash
curl -L https://github.com/atsign-foundation/noports/releases/latest/download/universal.sh -o universal.sh
```

To check if the installation downloaded correctly:

```bash
stat universal.sh
```

Make the script executable and run the script by running the command below:

```bash
chmod u+x universal.sh
./universal.sh
```

{% hint style="info" %}
You may be asked to enter your password if your machine requires sudo privileges.
{% endhint %}

**The install type**

* Enter  `client` when prompted.

**Your Atsigns (Skip this step)**

* To skip this step, simply press the Enter/Return key twice. Your Atsigns will be activated in the upcoming steps.

### <mark style="color:orange;">Step 2:</mark> Activate your client Atsign (@example01\_np)

{% hint style="warning" %}
If you've already activated your **client** Atsign on another device, this step will not work. Instead, follow this guide: [reuse-your-client-atsign-on-another-machine](../../installation-faq/reuse-your-client-atsign-on-another-machine/ "mention")
{% endhint %}

This command activates your Atsign and prompts you to enter an OTP. This is only done during the setup of a brand new Atsign.

{% hint style="warning" %}
Replace `@<REPLACE>_np` with your **client Atsign.**
{% endhint %}

```
~/.local/bin/at_activate -a @<REPLACE>_np
```

#### Enter the one-time password (OTP) & Check your SPAM/PROMOTIONS folders

at\_activate will pause and wait for the input of a one-time pin (OTP) sent to your email or phone number.\
\
Once activated, the master keys will save at `~/.atsign/keys`.

### <mark style="color:orange;">Step 3:</mark> Activate your device Atsign (@example02\_np)

Run the same command, but for your device Atsign.

{% hint style="warning" %}
Replace `@<REPLACE>_np` with your **device Atsign.**
{% endhint %}

```
~/.local/bin/at_activate -a @<REPLACE>_np
```

#### Enter the one-time password (OTP) & Check your SPAM/PROMOTIONS folders

at\_activate will pause and wait for the input of a one-time pin (OTP) sent to your email or phone number.\
\
Once activated, the master keys will save at `~/.atsign/keys`.

### <mark style="color:orange;">Step 4:</mark> Generate an Atsign authorization passcode for your device Atsign

Run the following command to generate a 6-character one-time passcode. You will use this passcode in **Step 6.**

{% hint style="warning" %}
Replace `@<REPLACE>_np` with your device **Atsign.**
{% endhint %}

```bash
~/.local/bin/at_activate otp -a @<REPLACE>_np
```

</details>

### Step 5 to Step 7

After setting up the machine you're connecting from, you'll configure the machine you're connecting to.

{% include "../../.gitbook/includes/5.13-windows-device-steps.md" %}

### Step 8 and Step 9

With both machines now configured, the final steps bring us back to the machine initiating the connection.

<details>

<summary>On the machine you are connecting from</summary>

### <mark style="color:orange;">Step 8:</mark> Approve the Atsign authorization request

Run the following command:

{% hint style="warning" %}
Be sure to replace the following values:

`@<REPLACE>_np` with your **device Atsign**,

`@<REPLACE_NAME>` with the **device name** **from Step 5.**
{% endhint %}

```bash
~/.local/bin/at_activate approve -a @<REPLACE>_np --arx noports --drx <DEVICE_NAME>
```

### <mark style="color:orange;">Step 9:</mark> Use NoPorts!

That's it. You can start using NoPorts or explore some of the documented use cases, including [MCP](../../use-cases/mcp.md), [SSH](../../use-cases/ssh.md), [RDP](../../use-cases/rdp.md), [SFTP](../../use-cases/sftp.md), [Web Server](../../use-cases/web-server.md), and [SMB](../../use-cases/smb.md).&#x20;

</details>
