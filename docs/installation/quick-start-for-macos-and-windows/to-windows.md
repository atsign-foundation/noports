---
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

# Quick Start to Windows

This guide provides instructions for connecting from the NoPorts desktop application, to a machine running Windows.

### Step 7 to Step 9

Complete these steps **on the machine you are connecting to (Windows)**

<details>

<summary>On the machine you are connecting to</summary>

### <mark style="color:orange;">Step 7:</mark> Download and run the Installer

Download the NoPorts msi installer [from GitHub](https://github.com/atsign-foundation/noports/releases/latest/download/sshnp-windows-x64.zip). You can run the MSI inside the sshnp-windows zip.

Ensure both Core Tools & Daemon Service are being installed.

<figure><img src="../../.gitbook/assets/image.png" alt=""><figcaption></figcaption></figure>

### <mark style="color:orange;">Step 8:</mark> Initiate Atsign authorization request

Open a terminal (Command Prompt or PowerShell) and run the following command to make an authorization request.&#x20;

{% hint style="warning" %}
Be sure to replace the following values:

`@<REPLACE>_np` with your **device Atsign**,

&#x20;`<PASSCODE>` with the **passcode generated in Step 5**,&#x20;

`<USER>` with your **Windows username**,&#x20;

`@<REPLACE>_np_key` with your **device Atsign**,&#x20;

`<DEVICE_NAME>` with the name of the machine you are on
{% endhint %}

<pre class="language-bash"><code class="lang-bash">at_activate.exe enroll -a "@&#x3C;REPLACE>_np" `
<strong>  -s &#x3C;PASSCODE> `
</strong><strong>  -p noports `
</strong><strong>  -k C:\Users\&#x3C;USER>\.atsign\keys\@&#x3C;REPLACE>_np_key.atKeys `
</strong><strong>  -d &#x3C;DEVICE_NAME> `
</strong><strong>  -n "sshnp:rw,sshrvd:rw"
</strong></code></pre>

Once you see this text, you're ready to continue to the next step.

```
Submitting enrollment request 
Enrollment ID: ---------------------
Waiting for approval; will check every 10 seconds
```

{% hint style="info" %}
If you encounter a handshake exception, it usually means your root certificates are outdated. To refresh them, run the following command with administrator privileges:<kbd>Install-Script -Name UpdateRootCertificates</kbd>
{% endhint %}

### <mark style="color:orange;">Step 9:</mark> Setup Service Config

The service config lives in C:\Program Data\NoPorts\sshnpd.yaml, you can open it in notepad buy running the following command:

{% hint style="danger" %}
Make sure you run notepad/terminal as administrator or else you won't be able to save your changes!
{% endhint %}

```
notepad C:\ProgramData\NoPorts\sshnpd.yaml
```

Ensure you provide the following fields to your service config:

* **atsign**
  * `atsign: example02_np`
  * `atsign: '@example02_np'`
* **keys (windows path)**
  * `keys: C:\Users\alice\.atsign\keys\@example02_np_key.atKeys`
* **manager**
  * `manager: example01_np`
  * `manager: '@example01_np'`

Examples on how to fill in the fields are inside the config file.

</details>

### Step 10 to Step 13

With both machines now configured, the final steps bring us back to the machine initiating the connection.

<details>

<summary>On the machine you are connecting from</summary>

### <mark style="color:orange;">Step 10:</mark> Approve the Atsign authorization request

1. Click on **Requests** and approve the pending request. The request will then move to the approved enrollments list.
2. After a few seconds, the request will also show as approved on the machine you are connecting to.

### <mark style="color:orange;">Step 11:</mark> Switch to your client Atsign (@example01\_np)

1. Click on **your Atsign** in the top right corner of the screen. This will open a list of atSigns that are currently signed into the app.
2. Select the one you would like to use as your **client Atsign** in order to switch to it.

### <mark style="color:orange;">Step 12:</mark> Create a Connection Profile

1. If you aren't already on the Connections tab, click on **Connections** at the top of the Screen. Then click **Add New**, to create a new profile.
2. Enter the following information into the profile then click **Submit**.
   1. Profile Name - The name that will be displayed in the profile list.
   2. Device Atsign - Your device Atsign (eg example02\_np).
   3. Device Name - The name of your remote device.
   4. Relay - Select the relay sever closest to you for optimum speed.
   5. Local Port - The port you will use on your local machine.
   6. Local Host - The hostname or IP address to bind to on your local machine.
   7. Remote Host - The hostname or IP address of the machine you are connecting to.
   8. Remote Port - The port that will be used on the remote machine.

For reference, we've documented our most common use cases, including [MCP](../../use-cases/mcp.md), [SSH](../../use-cases/ssh.md), [RDP](../../use-cases/rdp.md), [SFTP](../../use-cases/sftp.md), [Web Server](../../use-cases/web-server.md), and [SMB](../../use-cases/smb.md).&#x20;

### <mark style="color:orange;">Step 13:</mark> Establish a connection

Click the **Connect Icon ▶️** to establish a connection with your remote device. If the connection is successful, you will see green. If you see red, hover over the icon to see reason for failure.

</details>
