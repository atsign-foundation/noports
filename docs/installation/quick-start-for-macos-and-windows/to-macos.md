---
icon: apple
---

# Quick Start to macOS

This guide provides instructions for connecting from the NoPorts desktop application, to a machine running macOS .

### Step 6 and Step 7

Complete these steps **on the machine you are connecting to (MacOS)**

<details>

<summary>On the machine you are connecting to</summary>

### <mark style="color:orange;">Step 6:</mark> Download and run the Installer

Download the installer from GitHub by running the following command:

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

* Client atSign: e.g., `@example01_np`
* Device atSign: e.g., `@example02_np`&#x20;

**Your device name**

* This should be the name of the machine you're currently installing on.

### <mark style="color:orange;">Step 7:</mark> Initiate atSign authorization request

Run the following command to make an authorization request:&#x20;

{% hint style="warning" %}
Be sure to replace the following values:

`@<REPLACE>_np` with your **device atSign**,

&#x20;`<PASSCODE>` with the **passcode generated in Step 5**,&#x20;

`@<REPLACE>_np_key` with your **device atSign**,&#x20;

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

### Step 8 to Step 11

With both machines now configured, the final steps bring us back to the machine initiating the connection.

<details>

<summary>On the machine you are connecting from</summary>

### <mark style="color:orange;">Step 8:</mark> Approve the atSign authorization request

1. Click on **Requests** and approve the pending request. The request will then move to the approved enrollments list.
2. After a few seconds, the request will also show as approved on the machine you are connecting to.

### <mark style="color:orange;">Step 9:</mark> Switch back to your client atSign (@example01\_np)

1. Click **Back**, and then click on the **Settings** icon in the top right corner of the screen, then select **Sign Out**.

2) Click **Get Started** and select your **client atSign** from the drop down menu, and then click **Next**.

### <mark style="color:orange;">Step 10:</mark> Create a Connection Profile

1. Click **Add New**, to create a new profile.
2. Enter the following information into the profile then click **Submit**.
   1. Profile Name - The name that will be displayed in the profile list.
   2. Device atSign - Your device atSign (eg example02\_np).
   3. Device Name - The name of your remote device.
   4. Relay - Select the relay sever closest to you for optimum speed.
   5. Local Port - The port you will use on your local machine.
   6. Remote Host - The hostname or IP address of the machine you are connecting to.
   7. Remote Port - The port that will be used on the remote machine.

For reference, we've documented our most common use cases, including [MCP](../../use-cases/mcp.md), [SSH](../../use-cases/ssh.md), [RDP](../../use-cases/rdp.md), [SFTP](../../use-cases/sftp.md), [Web Server](../../use-cases/web-server.md), and [SMB](../../use-cases/smb.md).&#x20;

### <mark style="color:orange;">Step 11:</mark> Establish a connection

Click the **Connect Icon ▶️** to establish a connection with your remote device. If the connection is successful, you will see green. If you see red, hover over the icon to see reason for failure.

</details>
