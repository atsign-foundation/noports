# MacOS Device Installation

## Choose the operating system which is running on your <mark style="color:red;">CLIENT machine</mark>:

{% tabs %}
{% tab title="MacOS" %}
### Step 1 : Activate the device atSign from your <mark style="color:red;">CLIENT machine</mark>

If you've already activated the device atSign skip to [step 2](device.md#step-2-installing-on-the-device).

#### (1.1) Download the activation software on the <mark style="color:red;">client machine</mark>

{% include "../../.gitbook/includes/universal.sh-download-command.md" %}

#### (1.2) Run the installer

{% include "../../.gitbook/includes/universal.sh-execute.md" %}

#### (1.3) Activate the device atSign from the <mark style="color:red;">client machine</mark>

{% include "../../.gitbook/includes/activate-cli-device-unix.md" %}

### Step 2 : Installing on the <mark style="color:orange;">DEVICE machine</mark>

#### (2.1) Download the installer

{% include "../../.gitbook/includes/universal.sh-download-command.md" %}

#### (2.2) Run the installer

{% include "../../.gitbook/includes/universal.sh-execute.md" %}

***

### Step 3: Authorizing the device atSign

#### (3.1) Generate a passcode from your <mark style="color:red;">client machine</mark>

{% include "../../.gitbook/includes/apkam-1-unix.md" %}

#### (3.2) Make an authorization request from your <mark style="color:orange;">device machine</mark>

{% include "../../.gitbook/includes/apkam-2-unix.md" %}

#### (3.3) Approve the authorization request from your <mark style="color:red;">client machine</mark>

{% include "../../.gitbook/includes/apkam-3-unix.md" %}
{% endtab %}

{% tab title="Linux" %}
### Step 1 : Activate the device atSign from your <mark style="color:red;">CLIENT machine</mark>

If you've already activated the device atSign skip to [step 2](device.md#step-2-installing-on-the-device).

#### (1.1) Download the activation software on the <mark style="color:red;">client machine</mark>

{% include "../../.gitbook/includes/universal.sh-download-command.md" %}

#### (1.2) Run the installer

{% include "../../.gitbook/includes/universal.sh-execute.md" %}

#### (1.3) Activate the device atSign from the <mark style="color:red;">client machine</mark>

{% include "../../.gitbook/includes/activate-cli-device-unix.md" %}

### Step 2 : Installing on the <mark style="color:orange;">DEVICE machine</mark>

#### (2.1) Download the installer

{% include "../../.gitbook/includes/universal.sh-download-command.md" %}

#### (2.2) Run the installer

{% include "../../.gitbook/includes/universal.sh-execute.md" %}

***

### Step 3: Authorizing the device atSign

#### (3.1) Generate a passcode from your <mark style="color:red;">client machine</mark>

{% include "../../.gitbook/includes/apkam-1-unix.md" %}

#### (3.2) Make an authorization request from your <mark style="color:orange;">device machine</mark>

{% include "../../.gitbook/includes/apkam-2-unix.md" %}

#### (3.3) Approve the authorization request from your <mark style="color:red;">client machine</mark>

{% include "../../.gitbook/includes/apkam-3-unix.md" %}
{% endtab %}

{% tab title="Windows" %}
### Step 1 : Activate the device atSign from your <mark style="color:red;">CLIENT machine</mark>

If you've already activated the device atSign skip to [step 2](device.md#step-2-installing-on-the-device).

#### (1.1) Download the activation software on the <mark style="color:red;">client machine</mark>

See the Windows [#cli-client-installation](../windows/#cli-client-installation "mention")

#### (1.2) Activate the device atSign from the <mark style="color:red;">client machine</mark>

{% include "../../.gitbook/includes/activate-cli-device-windows.md" %}

### Step 2 : Installing on the <mark style="color:orange;">DEVICE machine</mark>

{% include "../../.gitbook/includes/apkam-2-unix.md" %}

#### (3.3) Approve the authorization request from your <mark style="color:red;">client machine</mark>

{% include "../../.gitbook/includes/apkam-3-windows.md" %}
{% endtab %}
{% endtabs %}

Choose the operating system which is running on your <mark style="color:red;">CLIENT machine</mark>:

{% tabs %}
{% tab title="MacOS" %}
### Step 1 : Activate the device atSign from your <mark style="color:red;">CLIENT machine</mark>

If you've already activated the device atSign skip to [step 2](device.md#step-2-installing-on-the-device).

#### (1.1) Download the activation software on the <mark style="color:red;">client machine</mark>

```bash
curl -L https://github.com/atsign-foundation/noports/releases/latest/download/universal.sh -o universal.sh
```

To check if the installation downloaded correctly:

```bash
stat universal.sh
```

#### (1.2) Run the installer

Make the script executable and run the script.

```bash
chmod u+x universal.sh
./universal.sh
```

#### (1.3) Activate the device atSign from the <mark style="color:red;">client machine</mark>

This command activates your atSign and prompts you to enter an OTP. This is only done during the setup of a brand new atsign.

```
~/.local/bin/at_activate -a @<REPLACE>_device
```

**Enter the One Time Password (OTP) & Check your SPAM/PROMOTIONS folders**

at\_activate will pause and wait for the input of a one time pin (OTP) sent to your email or phone number.

Once activated, the management keys will be saved in `~/.atsign/keys`.

### Step 2 : Installing on the <mark style="color:orange;">DEVICE machine</mark>

#### (2.1) Download the installer

```bash
curl -L https://github.com/atsign-foundation/noports/releases/latest/download/universal.sh -o universal.sh
```

To check if the installation downloaded correctly:

```bash
stat universal.sh
```

#### (2.2) Run the installer

Make the script executable and run the script.

```bash
chmod u+x universal.sh
./universal.sh
```

### Step 3: Authorizing the device atSign

#### (3.1) Generate a passcode from your <mark style="color:red;">client machine</mark>

Run the following command. It should output a 6-character passcode.

```bash
~/.local/bin/at_activate otp -a @<REPLACE>_device
```

#### (3.2) Make an authorization request from your <mark style="color:orange;">device machine</mark>

<pre class="language-bash"><code class="lang-bash">~/.local/bin/at_activate enroll -a @&#x3C;REPLACE>_device \
<strong>  -s &#x3C;PASSCODE> \
</strong><strong>  -p noports \
</strong><strong>  -k ~/.atsign/keys/@&#x3C;REPLACE>_device_key.atKeys \
</strong><strong>  -d &#x3C;DEVICE_NAME> \
</strong><strong>  -n "sshnp:rw,sshrvd:rw"
</strong></code></pre>

**Once you see this text, you're ready to continue to the next step.**

```
Submitting enrollment request 
Enrollment ID: ---------------------
Waiting for approval; will check every 10 seconds
```

#### (3.3) Approve the authorization request from your <mark style="color:red;">client machine</mark>

{% include "../../.gitbook/includes/apkam-3-unix.md" %}
{% endtab %}

{% tab title="Linux" %}
### Step 1 : Activate the device atSign from your <mark style="color:red;">CLIENT machine</mark>

If you've already activated the device atSign skip to [step 2](device.md#step-2-installing-on-the-device).

#### (1.1) Download the activation software on the <mark style="color:red;">client machine</mark>

```bash
curl -L https://github.com/atsign-foundation/noports/releases/latest/download/universal.sh -o universal.sh
```

To check if the installation downloaded correctly:

```bash
stat universal.sh
```

#### (1.2) Run the installer

Make the script executable and run the script.

```bash
chmod u+x universal.sh
./universal.sh
```

#### (1.3) Activate the device atSign from the <mark style="color:red;">client machine</mark>

This command activates your atSign and prompts you to enter an OTP. This is only done during the setup of a brand new atsign.

```
~/.local/bin/at_activate -a @<REPLACE>_device
```

**Enter the One Time Password (OTP) & Check your SPAM/PROMOTIONS folders**

at\_activate will pause and wait for the input of a one time pin (OTP) sent to your email or phone number.

Once activated, the management keys will be saved in `~/.atsign/keys`.

### Step 2 : Installing on the <mark style="color:orange;">DEVICE machine</mark>

#### (2.1) Download the installer

```bash
curl -L https://github.com/atsign-foundation/noports/releases/latest/download/universal.sh -o universal.sh
```

To check if the installation downloaded correctly:

```bash
stat universal.sh
```

#### (2.2) Run the installer

Make the script executable and run the script.

```bash
chmod u+x universal.sh
./universal.sh
```

***

### Step 3: Authorizing the device atSign

#### (3.1) Generate a passcode from your <mark style="color:red;">client machine</mark>

Run the following command. It should output a 6-character passcode.

```bash
~/.local/bin/at_activate otp -a @<REPLACE>_device
```

#### (3.2) Make an authorization request from your <mark style="color:orange;">device machine</mark>

<pre class="language-bash"><code class="lang-bash">~/.local/bin/at_activate enroll -a @&#x3C;REPLACE>_device \
<strong>  -s &#x3C;PASSCODE> \
</strong><strong>  -p noports \
</strong><strong>  -k ~/.atsign/keys/@&#x3C;REPLACE>_device_key.atKeys \
</strong><strong>  -d &#x3C;DEVICE_NAME> \
</strong><strong>  -n "sshnp:rw,sshrvd:rw"
</strong></code></pre>

**Once you see this text, you're ready to continue to the next step.**

```
Submitting enrollment request 
Enrollment ID: ---------------------
Waiting for approval; will check every 10 seconds
```

#### (3.3) Approve the authorization request from your <mark style="color:red;">client machine</mark>

Run the following command

```bash
~/.local/bin/at_activate approve -a @<REPLACE>_device --arx noports --drx <DEVICE_NAME>
```
{% endtab %}

{% tab title="Windows" %}
### Step 1 : Activate the device atSign from your <mark style="color:red;">CLIENT machine</mark>

If you've already activated the device atSign skip to [step 2](device.md#step-2-installing-on-the-device).

#### (1.1) Download the activation software on the <mark style="color:red;">client machine</mark>

If you haven't already done so, download the installer [from GitHub](https://github.com/atsign-foundation/noports/releases/download/v5.8.7/NoPortsInstaller-windows-x64.zip). Then unzip the file.

#### (1.2) Activate the device atSign from the <mark style="color:red;">client machine</mark>

Open the installer and click Activate atSign

<figure><img src="../../.gitbook/assets/CleanShot 2025-01-20 at 16.48.11@2x.png" alt=""><figcaption></figcaption></figure>

Enter the device atSign and click Submit

<figure><img src="../../.gitbook/assets/CleanShot 2025-01-20 at 18.42.07@2x.png" alt=""><figcaption></figcaption></figure>

A one-time password will be sent to your registered email address. Enter the OTP and then click Generate

<figure><img src="../../.gitbook/assets/CleanShot 2025-01-20 at 18.42.40@2x.png" alt=""><figcaption></figcaption></figure>

Once activated, the keys will be saved in `~\.atsign\keys`. You can go back to the installer home screen.

### Step 2 : Installing on the <mark style="color:orange;">DEVICE machine</mark>

#### (2.1) Download the installer

```bash
curl -L https://github.com/atsign-foundation/noports/releases/latest/download/universal.sh -o universal.sh
```

To check if the installation downloaded correctly:

```bash
stat universal.sh
```

#### (2.2) Run the installer

Make the script executable and run the script.

```bash
chmod u+x universal.sh
./universal.sh
```

### Step 3: Authorizing the device atSign

#### (3.1) Generate a passcode from your <mark style="color:red;">client machine</mark>

Open the installer and click on Manage Keys.

<figure><img src="../../.gitbook/assets/CleanShot 2025-01-20 at 17.26.37@2x.png" alt=""><figcaption></figcaption></figure>

Enter the device atSign and click Next.

<figure><img src="../../.gitbook/assets/Screenshot 2025-04-02 at 12.05.23 PM.png" alt=""><figcaption></figcaption></figure>

Click New OTP.

<figure><img src="../../.gitbook/assets/CleanShot 2025-01-20 at 17.28.20@2x.png" alt=""><figcaption></figcaption></figure>

Wait a few seconds for the OTP to appear then proceed to the next step.

<figure><img src="../../.gitbook/assets/CleanShot 2025-01-20 at 17.34.46@2x.png" alt=""><figcaption></figcaption></figure>

#### (3.2) Make an authorization request from your <mark style="color:orange;">device machine</mark>

Run the following command on your remote device.

<pre class="language-bash"><code class="lang-bash">~/.local/bin/at_activate enroll -a @&#x3C;REPLACE>_device \
<strong>  -s &#x3C;PASSCODE> \
</strong><strong>  -p noports \
</strong><strong>  -k ~/.atsign/keys/@&#x3C;REPLACE>_device_key.atKeys \
</strong><strong>  -d &#x3C;DEVICE_NAME> \
</strong><strong>  -n "sshnp:rw,sshrvd:rw"
</strong></code></pre>

**Once you see the text below, you're ready to continue to the next step.**

```
Submitting enrollment request 
Enrollment ID: ---------------------
Waiting for approval; will check every 10 seconds
```

#### (3.3) Approve the authorization request from your <mark style="color:red;">client machine</mark>

#### (3.3) Approve the authorization request from your <mark style="color:red;">client machine</mark>

Click Refresh and the new request will appear

<figure><img src="../../.gitbook/assets/CleanShot 2025-01-20 at 17.32.07@2x.png" alt=""><figcaption></figcaption></figure>

If the request looks incorrect, then click "Deny" to deny it, and start the process again.

If the request looks correct, then click "Approve" to approve it.

<figure><img src="../../.gitbook/assets/CleanShot 2025-01-20 at 17.33.42@2x.png" alt=""><figcaption></figcaption></figure>

Once the request has been approved, it should disappear from the list in the installer. The enrollment will complete on the remote device in a few seconds.

<figure><img src="../../.gitbook/assets/CleanShot 2025-01-20 at 17.29.22@2x.png" alt=""><figcaption></figcaption></figure>
{% endtab %}
{% endtabs %}
