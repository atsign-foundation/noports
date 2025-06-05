---
description: How to install NoPorts when connecting from macOS to macOS
icon: apple
---

# macOS to macOS

### Step 1 to Step 4

These initial steps set up the machine initiating the connection.

{% hint style="danger" %}
If you’ve already completed the Quick Start guide with the client atSign you intend on using on this machine, you can skip **Step 2**. However, be sure to complete **Steps 1, 3, and 4**.
{% endhint %}

<details>

<summary>On the machine you are connecting from</summary>

### <mark style="color:orange;">Step 1:</mark> Download and run the Installer

Download the installer from GitHub by running the following command:

```bash
curl -L https://github.com/atsign-foundation/noports/releases/latest/download/universal.sh -o universal.sh
```

To check if the installation downloaded correctly:

```bash
stat universal.sh
```

Make the script executable and run the script.

```bash
chmod u+x universal.sh
./universal.sh
```

### <mark style="color:orange;">Step 2:</mark> Activate your client atSign

{% hint style="warning" %}
If you've already activated your **client** atSign on another device, this step will not work. Instead, follow this guide: [reuse-your-client-atsign-on-another-machine](../../installation-faq/reuse-your-client-atsign-on-another-machine/ "mention")
{% endhint %}

This command activates your atSign and prompts you to enter an OTP. This is only done during the setup of a brand new atSign.

{% hint style="warning" %}
Replace `@<REPLACE>_client` with your **client atSign.**
{% endhint %}

```
~/.local/bin/at_activate -a @<REPLACE>_client
```

#### Enter the one-time password (OTP) & Check your SPAM/PROMOTIONS folders

at\_activate will pause and wait for the input of a one-time pin (OTP) sent to your email or phone number.\
\
Once activated, the master keys will save at `~/.atsign/keys`.

### <mark style="color:orange;">Step 3:</mark> Activate your device atSign

Run the same command, but for your device atSign.

{% hint style="warning" %}
Replace `@<REPLACE>_device` with your **device atSign.**
{% endhint %}

```
~/.local/bin/at_activate -a @<REPLACE>_device
```

#### Enter the one-time password (OTP) & Check your SPAM/PROMOTIONS folders

at\_activate will pause and wait for the input of a one-time pin (OTP) sent to your email or phone number.\
\
Once activated, the master keys will save at `~/.atsign/keys`.

### <mark style="color:orange;">Step 4:</mark> Generate an atSign authorization passcode for your device atSign

Run the following command to generate a 6-character one-time passcode. You will use this passcode in **Step 6.**

{% hint style="warning" %}
Replace `@<REPLACE>_device` with your device **atSign.**
{% endhint %}

```bash
~/.local/bin/at_activate otp -a @<REPLACE>_device
```

</details>

### Step 5 and Step 6

After setting up the machine you're connecting from, you'll configure the machine you're connecting to.

<details>

<summary>On the machine you are connecting to</summary>

### <mark style="color:orange;">Step 5:</mark> Download and run the Installer

Download the installer from GitHub by running the following command:

```bash
curl -L https://github.com/atsign-foundation/noports/releases/latest/download/universal.sh -o universal.sh
```

To check if the installation downloaded correctly:

```bash
stat universal.sh
```

Make the script executable and run the script.

```bash
chmod u+x universal.sh
./universal.sh
```

### <mark style="color:orange;">Step 6:</mark> Initiate atSign authorization request

Run the following command to make an authorization request:&#x20;

{% hint style="warning" %}
Be sure to replace the following values:

`@<REPLACE>_device` with your **device atSign**,

&#x20;`<PASSCODE>` with the **passcode generated in Step 4**,&#x20;

`@<REPLACE>_device_key` with your **device atSign**,&#x20;

`<DEVICE_NAME>` with a unique name for the machine you are on
{% endhint %}

<pre class="language-bash"><code class="lang-bash">~/.local/bin/at_activate enroll -a @&#x3C;REPLACE>_device \
<strong>  -s &#x3C;PASSCODE> \
</strong><strong>  -p noports \
</strong><strong>  -k ~/.atsign/keys/@&#x3C;REPLACE>_device_key.atKeys \
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

### <mark style="color:orange;">Step 7:</mark> Approve the atSign authorization request

Run the following command:

{% hint style="warning" %}
Be sure to replace the following values:

`@<REPLACE>_device` with your **device atSign**,

`@<REPLACE_NAME>` with the unique **device name** **from Step 6.**
{% endhint %}

```bash
~/.local/bin/at_activate approve -a @<REPLACE>_device --arx noports --drx <DEVICE_NAME>
```

### <mark style="color:orange;">Step 8:</mark> Use NoPorts!

That's it. You can start using NoPorts or explore some of the [use cases available here](../../use-cases/).

</details>

### Connecting more machines to your device atSign

To connect more machines to your device atSign, repeat **Steps 4 through 7**.

