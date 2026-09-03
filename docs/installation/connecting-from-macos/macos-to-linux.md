---
description: How to install NoPorts when connecting from macOS to Linux
icon: linux
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

# macOS to Linux

### Prerequisite

Before starting the NoPorts installation, ensure you have **at least two atSigns** available. If you don’t yet have any atSigns, you can sign up for a NoPorts subscription or free trial at [my.noports.com/no-ports-plans](https://my.noports.com/no-ports-plans).

### Step 1 to Step 4

These initial steps set up the machine initiating the connection.

<details>

<summary>On the machine you are connecting from</summary>

{% hint style="warning" %}
In this installation guide, `@example01_np` will represent the client atSign, while `@example02_np` will represent the device atSign.
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

Make the script executable and run the script by running the command below.

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

{% hint style="info" %}
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

### Step 5 and Step 6

After setting up the machine you're connecting from, you'll configure the machine you're connecting to.

<details>

<summary>On the machine you are connecting to</summary>

### <mark style="color:orange;">Step 5:</mark> Download and run the Installer

{% hint style="warning" %}
Do not run the following commands while logged in as the root user. Instead, use `sudo` from a regular account when elevated privileges are required, and create a regular account if one does not already exist.
{% endhint %}

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

During installation, you’ll be prompted to enter the following items:

{% hint style="info" %}
You may be asked to enter your password if your machine requires sudo privileges.
{% endhint %}

**The install type**

* Enter  `device` when prompted.

**Your atSigns**

* Client Atsign: e.g., `@example01_np`
* Device Atsign: e.g., `@example02_np`&#x20;

**Your device name**

* This should be the name of the machine you're currently installing on.

### <mark style="color:orange;">Step 6:</mark> Initiate Atsign authorization request

Run the following command to make an authorization request:&#x20;

{% hint style="warning" %}
Be sure to replace the following values:

`@<REPLACE>_np` with your **device Atsign**,

&#x20;`<PASSCODE>` with the **passcode generated in Step 4**,&#x20;

`@<REPLACE>_np_key` with your **device Atsign**,&#x20;

`<DEVICE_NAME>` with the name of the machine you are on
{% endhint %}

<pre class="language-bash"><code class="lang-bash">~/.local/bin/at_activate enroll -a @&#x3C;REPLACE>_np \
<strong>  -s &#x3C;PASSCODE> \
</strong><strong>  -p noports \
</strong><strong>  -k ~/.atsign/keys/@&#x3C;REPLACE>_np_key.atKeys \
</strong><strong>  -d &#x3C;DEVICE_NAME> \
</strong><strong>  -n "sshnp:rw,sshrvd:rw"
</strong></code></pre>

Once you see this text, you're ready to continue to the next step.

```
Submitting enrollment request 
Enrollment ID: ---------------------
Waiting for approval; will check every 10 seconds
```

</details>

### Step 7 and Step 8

With both machines now configured, the final steps bring us back to the machine initiating the connection.

<details>

<summary>On the machine you are connecting from</summary>

### <mark style="color:orange;">Step 7:</mark> Approve the Atsign authorization request

Run the following command:

{% hint style="warning" %}
Be sure to replace the following values:

`@<REPLACE>_np` with your **device Atsign**,

`@<REPLACE_NAME>` with the **device name** **from Step 6.**
{% endhint %}

```bash
~/.local/bin/at_activate approve -a @<REPLACE>_np --arx noports --drx <DEVICE_NAME>
```

### <mark style="color:orange;">Step 8:</mark> Use NoPorts!

That's it. You can start using NoPorts or explore some of the documented use cases, including [MCP](../../use-cases/mcp.md), [SSH](../../use-cases/ssh.md), [RDP](../../use-cases/rdp.md), [SFTP](../../use-cases/sftp.md), [Web Server](../../use-cases/web-server.md), and [SMB](../../use-cases/smb.md).&#x20;

</details>

