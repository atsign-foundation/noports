---
description: How to install NoPorts when connecting from Linux to Windows
icon: windows
---

# Linux to Windows

### Step 1 to Step 4

These initial steps set up the machine initiating the connection.

<details>

<summary>On the machine you are connecting from</summary>

{% hint style="warning" %}
In this installation guide, `@example01_np` will represent the client atSign, while `@example02_np` will represent the device atSign.
{% endhint %}

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

### <mark style="color:orange;">Step 2:</mark> Activate your client atSign (@example01\_np)

{% hint style="warning" %}
If you've already activated your **client** atSign on another device, this step will not work. Instead, follow this guide: [reuse-your-client-atsign-on-another-machine](../../installation-faq/reuse-your-client-atsign-on-another-machine/ "mention")
{% endhint %}

This command activates your atSign and prompts you to enter an OTP. This is only done during the setup of a brand new atSign.

{% hint style="warning" %}
Replace `@<REPLACE>_np` with your **client atSign.**
{% endhint %}

```
~/.local/bin/at_activate -a @<REPLACE>_np
```

#### Enter the one-time password (OTP) & Check your SPAM/PROMOTIONS folders

at\_activate will pause and wait for the input of a one-time pin (OTP) sent to your email or phone number.\
\
Once activated, the master keys will save at `~/.atsign/keys`.

### <mark style="color:orange;">Step 3:</mark> Activate your device atSign (@example02\_np)

Run the same command, but for your device atSign.

{% hint style="warning" %}
Replace `@<REPLACE>_np` with your **device atSign.**
{% endhint %}

```
~/.local/bin/at_activate -a @<REPLACE>_np
```

#### Enter the one-time password (OTP) & Check your SPAM/PROMOTIONS folders

at\_activate will pause and wait for the input of a one-time pin (OTP) sent to your email or phone number.\
\
Once activated, the master keys will save at `~/.atsign/keys`.

### <mark style="color:orange;">Step 4:</mark> Generate an atSign authorization passcode for your device atSign

Run the following command to generate a 6-character one-time passcode. You will use this passcode in **Step 6.**

{% hint style="warning" %}
Replace `@<REPLACE>_np` with your device **atSign.**
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

Download the installer [from GitHub](https://github.com/atsign-foundation/noports/releases/latest/download/NoPortsInstaller-windows-x64.zip). Then unzip the file.

Install the Device Software

5.1: Click **Device Install**

<figure><img src="../../.gitbook/assets/CleanShot 2025-01-20 at 17.46.42@2x.png" alt=""><figcaption></figcaption></figure>

5.2 :Enter both of your atSigns into the associated fields, then enter the name of the machine you are on into the a device name field, and click **Next**. You will need to enter this device name in S**tep 7**.

<figure><img src="../../.gitbook/assets/CleanShot 2025-01-20 at 17.50.56@2x.png" alt=""><figcaption></figcaption></figure>

5.3: (Optional) If you wish to add additional arguments to pass to sshnpd, enter them, then click **Next**.

<figure><img src="../../.gitbook/assets/CleanShot 2025-01-20 at 17.51.22@2x.png" alt=""><figcaption></figcaption></figure>

5.4: Wait for the installation to complete, then click **Next**.

### <mark style="color:orange;">Step 6:</mark> Initiate atSign authorization request

You will see the following screen. Enter the **one-time passcode generated in Step 4** on the machine you are connecting from. Then click **Generate**.

<figure><img src="../../.gitbook/assets/Screenshot 2025-04-02 at 11.58.00 AM.png" alt=""><figcaption></figcaption></figure>

</details>

### Step 7 and Step 8

With both machines now configured, the final steps bring us back to the machine initiating the connection.

<details>

<summary>On the machine you are connecting from</summary>

### <mark style="color:orange;">Step 7:</mark> Approve the atSign authorization request

Run the following command:

{% hint style="warning" %}
Be sure to replace the following values:

`@<REPLACE>_np` with your **device atSign**,

`@<REPLACE_NAME>` with the **device name** **from Step 5.**
{% endhint %}

```bash
~/.local/bin/at_activate approve -a @<REPLACE>_np --arx noports --drx <DEVICE_NAME>
```

### <mark style="color:orange;">Step 8:</mark> Use NoPorts!

That's it. You can start using NoPorts or explore some of the documented use cases, including [MCP](../../use-cases/mcp.md), [SSH](../../use-cases/ssh.md), [RDP](../../use-cases/rdp.md), [SFTP](../../use-cases/sftp.md), [Web Server](../../use-cases/web-server.md), and [SMB](../../use-cases/smb.md).&#x20;

</details>
