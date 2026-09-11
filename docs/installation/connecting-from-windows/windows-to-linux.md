---
description: How to install NoPorts when connecting from Windows to Linux
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

# Windows to Linux

### Prerequisite

Before starting the NoPorts installation, ensure you have **at least two atSigns** available. If you don’t yet have any atSigns, you can sign up for a NoPorts subscription or free trial at [my.noports.com/no-ports-plans](https://my.noports.com/no-ports-plans).

### Step 1 to Step 4

These initial steps set up the machine initiating the connection.

{% include "../../.gitbook/includes/5.13-windows-client-steps.md" %}

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

**Your Atsigns**

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

{% include "../../.gitbook/includes/5.13-windows-msi-activate.md" %}
