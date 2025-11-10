---
icon: users-rectangle
---

# Policy Service Installation

This guide explains how to install and run the NoPorts Policy Service via the command line, and how to use it within the NoPorts desktop application. We recommend running the Policy Server in a Linux environment (virtual machine) for easier management.

### Prerequisites

Before you begin the installation, please ensure the following steps are complete:

1. **Subscription**: You’ve signed up for a [NoPorts subscription or free trial](https://my.noports.com/no-ports-plans).
2. **Installation & Activation**: NoPorts is installed and atSigns are activated on at least two machines, one to connect _from_ and one to connect _to_. [View installation guides](./).
3. **NoPorts Desktop App** : If you didn’t use the NoPorts desktop app during installation, you can download it here:
   * [Link to Apple Store](https://apps.apple.com/ca/app/noports-desktop/id6737338881)
   * [Link to Windows Store](https://apps.microsoft.com/detail/9n69scrrgv6r)

### Step 1 and Step 2

<details>

<summary>Steps to be completed on the Admin/Client Machine</summary>

### Step 1: Activate your policy atSign

1\) If you were already signed in with another atSign, click on Settings and then Sign Out.

2\) Click Get Started and then enter your policy atSign.

3\) You'll receive an OTP via email and after entering it, you'll be prompted to save your keys.

### Step 2: Generate a policy atSign authorization passcode

1\) Click on Authenticator and make note of the One-Time Password displayed on screen.

</details>

### Step 3 and Step 4

<details>

<summary>Steps to be completed on the Policy Machine</summary>

### Step 3: Download and extract the policy server binaries

Navigate to the NoPorts GitHub Releases page and copy the link address for the **file matching your operating system**.&#x20;

Location:  [https://github.com/atsign-foundation/noports/releases](https://github.com/atsign-foundation/noports/releases)&#x20;

Open a terminal, and from your home directory run the following command to download the file and save it as `sshnpd.tgz`.&#x20;

```bash
curl -L -o sshnpd.tgz <YOUR URL>
```

Example:&#x20;

```bash
curl -L -o sshnpd.tgz https://github.com/atsign-foundation/noports/releases/download/v5.9.2/sshnp-linux-x64.tgz
```

Once this is done, extract the contents of the file to your home directory.

### Step 4: Initiate an atSign authorization request

Run the following command to make an authorization request:

{% hint style="warning" %}
Be sure to replace the following values:

`@<REPLACE>_np` with your **policy atSign**,

&#x20;`<PASSCODE>` with the **passcode generated in Step 2**,&#x20;

`@<REPLACE>_np_key` with your **policy atSign**,&#x20;

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

### Step 5

<details>

<summary>Step to be completed on the Admin/Client Machine</summary>

### Step 5: Approve the atSign authorization request

1. Click on **Requests** and approve the pending request. The request will then move to the approved enrollments list.
2. After a few seconds, the request will also show as approved on the machine you are connecting to.

</details>

### Step 6

<details>

<summary>Step to be completed on the Policy Machine</summary>

### Step 6: Run the NoPorts Policy Server Software

Run `npp_atserver`, with the previously activated policy atSign.&#x20;

```bash
./npp_atserver -a @<YOUR POLICY ATSIGN>
```

This should display output that looks similar to this

```
SHOUT|2025-04-16 19:12:51.399918|PolicyServiceWithAtClient|Loading groups via AtClient 
SHOUT|2025-04-16 19:12:52.293882|PolicyServiceWithAtClient|Load complete 
SHOUT|2025-04-16 19:12:52.294012| npp |Daemon atSigns: {} 
```

</details>

### Step 7

<details>

<summary>Step to be completed on the machine you'll be connecting to (Device)</summary>

### Step 7: Restart the NoPorts Daemon

Edit `/etc/systemd/system/sshnpd.service.d/override.conf` and add `-p @policy` to the additional arguments environment variable.

Then run the following command to restart the daemon.

```bash
sudo systemctl daemon reload && sudo systemctl restart sshnpd.service
```

</details>

### Step 8

You're now ready to use the Policy Service. You can find instructions in the NoPorts desktop application [here](../usage/noports-desktop-usage/policy-service.md).

