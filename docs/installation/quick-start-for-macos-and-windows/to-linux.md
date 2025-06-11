---
icon: linux
---

# Quick Start to Linux

This guide provides instructions for connecting from the NoPorts desktop application, to a machine running Linux.

### Step 1 to Step 3

Complete these steps in the NoPorts desktop application on the machine you are connecting from

<details>

<summary>On the machine you are connecting from</summary>

### <mark style="color:orange;">Step 1:</mark> Activate your device atSign

{% hint style="warning" %}
Both the client and device atSigns are activated on the machine you are connecting from. Later, you’ll grant your remote machine access to the keys stored on this machine.
{% endhint %}

1. You'll need to switch atSigns. To sign out from the client atSign, click the **Settings** icon in the top right corner of the screen, then select **Sign Out**.
2. Click **Get Started** and enter your **device atSign** into the text field (e.g., @pluto83\_client). Leave the root domain as is, and then click **Next**.
3. A **one-time password (OTP)** will be sent to you via email. Enter this OTP into the app and then click **Confirm**.&#x20;

### <mark style="color:orange;">Step 2:</mark> Save a copy of your device atKeys&#x20;

Your atKeys (cryptographic keys) will be used to pair your atSign with this and other devices in future. You can [learn more about these keys here](https://www.youtube.com/watch?v=bRRLCOHP-BY).

1. Click on **Save atKeys**
2. Select a memorable location on your machine and **save** your keys. We recommend creating a folder in your home drive called `~/.atsign/keys` and storing your keys there.

### <mark style="color:orange;">Step 3:</mark> Generate a device atSign authorization passcode

Click on the **key icon** in the top right corner and then click on **OTP.** You will use this 4 character code in **Step 5**.

</details>

### Step 4 and Step 5&#x20;

After setting up the machine you're connecting from, you'll configure the machine you're connecting to.

<details>

<summary>On the machine you are connecting to</summary>

### <mark style="color:orange;">Step 4:</mark> Download and run the Installer

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

### <mark style="color:orange;">Step 5:</mark> Initiate atSign authorization request

Run the following command to make an authorization request:&#x20;

{% hint style="warning" %}
Be sure to replace the following values:

`@<REPLACE>_device` with your **device atSign**,

&#x20;`<PASSCODE>` with the **passcode generated in Step 3**,&#x20;

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

### Step 6 to Step 9&#x20;

With both machines now configured, the final steps bring us back to the machine initiating the connection.

<details>

<summary>On the machine you are connecting from</summary>

### <mark style="color:orange;">Step 6:</mark> Approve the atSign authorization request

1. Click on **Requests** and approve the pending request. The request will then move to the approved enrollments list.
2. After a few seconds, the request will also show as approved on the machine you are connecting to.

### <mark style="color:orange;">Step 7:</mark> Switch back to your client atSign

1. Click **Back**, and then click on the **Settings** icon in the top right corner of the screen, then select **Sign Out**.

2) Click **Get Started** and select your **client atSign** from the drop down menu, and then click **Next**.

### <mark style="color:orange;">Step 8:</mark> Create a Connection Profile

1. Click **Add New**, to create a new profile.
2. Enter the following information into the profile then click **Submit**.
   1. Profile Name - The name that will be displayed in the profile list.
   2. Device atSign - Your device atSign.
   3. Device Name - The name assigned to your remote device.
   4. Relay - Select the relay sever closest to you for optimum speed.
   5. Local Port - The port you will use on your local machine.
   6. Remote Host - The hostname or IP address of the machine you are connecting to.
   7. Remote Port - The port that will be used on the remote machine.

### <mark style="color:orange;">Step 9:</mark> Establish a connection

Click the **Connect Icon ▶️** to establish a connection with your remote device. If the connection is successful, you will see green. If you see red, hover over the icon to see reason for failure.

</details>
