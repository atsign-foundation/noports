---
description: How to install NoPorts when connecting from Windows to Windows
hidden: true
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

# Windows to Windows Legacy

### Step 1 to Step 4

These initial steps set up the machine initiating the connection.

<details>

<summary>On the machine you are connecting from</summary>

{% hint style="warning" %}
In this installation guide, `@example01_np` will represent the client atSign, while `@example02_np` will represent the device atSign.
{% endhint %}

### <mark style="color:orange;">Step 1:</mark> Download and run the Installer

Download the installer from [GitHub](https://github.com/atsign-foundation/noports/releases/latest/download/NoPortsInstaller-windows-x64.zip). Then unzip the file.

Launch the NoPortsInstaller.exe program and allow it administrative permissions. Click **Client Install** and follow the process until installation is complete.

<figure><img src="../../.gitbook/assets/CleanShot 2025-01-20 at 16.44.12@2x.png" alt=""><figcaption></figcaption></figure>

<figure><img src="../../.gitbook/assets/CleanShot 2025-01-20 at 16.44.39@2x.png" alt=""><figcaption></figcaption></figure>

<figure><img src="../../.gitbook/assets/CleanShot 2025-01-20 at 16.45.20@2x.png" alt=""><figcaption></figcaption></figure>

<figure><img src="../../.gitbook/assets/CleanShot 2025-01-20 at 18.46.29@2x.png" alt=""><figcaption></figcaption></figure>



### <mark style="color:orange;">Step 2:</mark> Activate your client atSign (@example01\_np)

{% hint style="warning" %}
If you've already activated your **client** atSign on another device, this step will not work. Instead, follow this guide: [reuse-your-client-atsign-on-another-machine](../../installation-faq/reuse-your-client-atsign-on-another-machine/ "mention")
{% endhint %}

Step 2.1 Click on **Activate atSign.**

<figure><img src="../../.gitbook/assets/CleanShot 2025-01-20 at 16.48.11@2x.png" alt=""><figcaption></figcaption></figure>

Step 2.2 Enter the atSign you wish to activate and click **Submit**.

<figure><img src="../../.gitbook/assets/Screenshot 2025-10-01 at 8.19.37 PM.png" alt=""><figcaption></figcaption></figure>

Step 2.3 Check your email for the OTP (one-time password), then enter it and press **Generate.**

<figure><img src="../../.gitbook/assets/Screenshot 2025-10-01 at 8.20.54 PM.png" alt=""><figcaption></figcaption></figure>

Step 2.4 Once activated, the master keys will save at `~/.atsign/keys`. Wait for the keys to generate, then go back **Home**.

<figure><img src="../../.gitbook/assets/CleanShot 2025-01-20 at 17.24.43@2x.png" alt=""><figcaption></figcaption></figure>

### <mark style="color:orange;">Step 3:</mark> Activate your device atSign (@example02\_np)

Repeat the activation process, but for your device atSign. The device master keys will also save at `~/.atsign/keys`.&#x20;

### <mark style="color:orange;">Step 4:</mark> Generate an atSign authorization passcode for your device atSign

Follow the steps below to generate a 6-character one-time passcode which you will use in **Step 6.**

4.1 Click **Manage Keys**.

<figure><img src="../../.gitbook/assets/CleanShot 2025-01-20 at 17.26.37@2x.png" alt=""><figcaption></figcaption></figure>

4.2 Enter your device atSign and click **Next**.

<figure><img src="../../.gitbook/assets/Screenshot 2025-04-02 at 12.05.23 PM.png" alt=""><figcaption></figcaption></figure>

4.3 Click **New OTP**.

<figure><img src="../../.gitbook/assets/CleanShot 2025-01-20 at 17.28.20@2x.png" alt=""><figcaption></figcaption></figure>

4.4 Wait a few seconds for the OTP to appear, then proceed to **Step 5** on the machine you are connecting to

<figure><img src="../../.gitbook/assets/CleanShot 2025-01-20 at 17.29.22@2x.png" alt=""><figcaption></figcaption></figure>



</details>

### Step 5 and Step 6

After setting up the machine you're connecting from, you'll configure the machine you're connecting to.

<details>

<summary>On the machine you are connecting to</summary>

### <mark style="color:orange;">Step 5:</mark> Download and run the Installer

Download the installer [from GitHub](https://github.com/atsign-foundation/noports/releases/latest/download/NoPortsInstaller-windows-x64.zip). Then unzip the file.

Install the Device Software

5.1 Click **Device Install**.

<figure><img src="../../.gitbook/assets/CleanShot 2025-01-20 at 17.46.42@2x.png" alt=""><figcaption></figcaption></figure>

5.2 Enter both of your atSigns into the associated fields, then enter the name of the machine you are on into the a device name field, and click **Next**. You will need to enter this device name in **Step 7**.

<figure><img src="../../.gitbook/assets/Screenshot 2025-10-01 at 8.17.31 PM.png" alt=""><figcaption></figcaption></figure>

5.3 If you wish to add additional arguments to pass to sshnpd, enter them, and then click **Next.**

<figure><img src="../../.gitbook/assets/CleanShot 2025-01-20 at 17.51.22@2x.png" alt=""><figcaption></figcaption></figure>

5.4 Wait for the installation to complete, then click **Next.**

### <mark style="color:orange;">Step 6:</mark> Initiate atSign authorization request

You will see the following screen. Enter the **one-time passcode generated in Step 4** on the machine you are connecting from. Then click **Generate**.

<figure><img src="../../.gitbook/assets/Screenshot 2025-10-01 at 8.25.05 PM.png" alt=""><figcaption></figcaption></figure>

</details>

### Step 7 and Step 8

With both machines now configured, the final steps bring us back to the machine initiating the connection.

<details>

<summary>On the machine you are connecting from</summary>

### <mark style="color:orange;">Step 7:</mark> Approve the atSign authorization request

Click **Refresh** and the new request will appear.&#x20;

* If the request looks incorrect, press **Deny** to deny it and start the process again.
* If the request looks correct, press **Approve** to approve it.

<figure><img src="../../.gitbook/assets/CleanShot 2025-01-20 at 17.33.42@2x.png" alt=""><figcaption></figcaption></figure>

Once approved, the request will disappear from the list. On the machine you are connecting to, it will take a few seconds to process the approval.

### <mark style="color:orange;">Step 8:</mark> Use NoPorts!

That's it. You can start using NoPorts or explore some of the documented use cases, including [MCP](../../use-cases/mcp.md), [SSH](../../use-cases/ssh.md), [RDP](../../use-cases/rdp.md), [SFTP](../../use-cases/sftp.md), [Web Server](../../use-cases/web-server.md), and [SMB](../../use-cases/smb.md).&#x20;

</details>

### Connecting more machines to your device atSign

To connect more machines to your device atSign, repeat **Steps 4 through 7**.
