---
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

# Generate a new set of cryptographic keys

"<mark style="color:red;">**Old machine**</mark>" is the machine that has the **original** set of cryptographic keys that were generated. "<mark style="color:orange;">**New machine**</mark>" is the device you want the new set of cryptographic keys on.

### Step 1) Generate a passcode from your <mark style="color:red;">Old machine</mark>

Choose the operating system that is running on your old machine.

{% tabs %}
{% tab title="MacOS/Linux" %}
{% hint style="warning" %}
Make sure to replace `<REPLACE_client>` with your client Atsign
{% endhint %}

```
~/.local/bin/at_activate otp -a @<REPLACE_client>
```
{% endtab %}

{% tab title="Windows" %}
#### 1.1 Open the Windows installer program and click "Manage Keys"

<figure><img src="../../.gitbook/assets/CleanShot 2025-01-20 at 17.26.37@2x.png" alt=""><figcaption></figcaption></figure>

#### 1.2 Enter the atSign you wish to manage and click "Next"

<figure><img src="../../.gitbook/assets/CleanShot 2025-01-20 at 17.27.40@2x.png" alt=""><figcaption></figcaption></figure>

#### 1.3 Click "New OTP"

<figure><img src="../../.gitbook/assets/CleanShot 2025-01-20 at 17.28.20@2x.png" alt=""><figcaption></figcaption></figure>

#### 1.4 Wait a few seconds for the OTP to appear then proceed to Step 2 on the <mark style="color:orange;">New machine</mark>

<figure><img src="../../.gitbook/assets/CleanShot 2025-01-20 at 17.29.22@2x.png" alt=""><figcaption></figcaption></figure>
{% endtab %}
{% endtabs %}

### Step 2) Make an authorization request on your <mark style="color:orange;">New machine</mark>

Choose the operating system that is running on your new machine.

{% tabs %}
{% tab title="Running MacOS/Linux" %}
{% hint style="warning" %}
Make sure to replace the appropriate values:\
`<REPLACE_client>` with your client Atsign\
`<client_device_name>` with a unique name for the device\
`<PASSCODE>` with the passcode from **Step 1**
{% endhint %}

```
~/.local/bin/at_activate enroll -a @<REPLACE_client> \
  -s <PASSCODE> \
  -p noports \
  -k ~/.atsign/keys/@<REPLACE_client>_key.atKeys \
  -d <client_device_name> \
  -n "sshnp:rw,sshrvd:rw"
```
{% endtab %}

{% tab title="Running Windows" %}
#### 2.1 Open the Windows Installer and click "Generate Keys"

<figure><img src="../../.gitbook/assets/CleanShot 2025-01-20 at 17.14.52@2x.png" alt=""><figcaption></figcaption></figure>

#### 2.2 Enter the atSign you wish to transfer and click "Next"

<figure><img src="../../.gitbook/assets/CleanShot 2025-01-20 at 17.15.11@2x.png" alt=""><figcaption></figcaption></figure>

#### 2.3 Enter the OTP then press "Generate"

<figure><img src="../../.gitbook/assets/CleanShot 2025-01-20 at 17.43.42@2x.png" alt=""><figcaption></figcaption></figure>

#### 2.4 Proceed to Step 3. Once the request has been approved in Step 3, you should see this screen

<figure><img src="../../.gitbook/assets/CleanShot 2025-01-20 at 17.44.52@2x.png" alt=""><figcaption></figcaption></figure>
{% endtab %}
{% endtabs %}

### Step 3) Approve the request on your <mark style="color:red;">Old machine</mark>

Choose the operating system that is running on your old machine.

{% tabs %}
{% tab title="MacOS/Linux" %}
{% hint style="warning" %}
Make sure to replace `<client_device_name>` with the device name from **Step 2**
{% endhint %}

```
~/.local/bin/at_activate approve -a @<REPLACE_client> \
  --arx noports \
  --drx <client_device_name>
```


{% endtab %}

{% tab title="Windows" %}
{% hint style="info" %}
If you aren't already on the "Manage Keys" screen, follow **Steps 1.1 and 1.2** above.
{% endhint %}

#### 3.1 Once step 2 is complete press refresh and the new request will appear

<figure><img src="../../.gitbook/assets/CleanShot 2025-01-20 at 17.32.07@2x.png" alt=""><figcaption></figcaption></figure>

#### 3.2 Approve or Deny the request

* If the request looks incorrect, then press "Deny" to deny it, and start the process again.
* If the request looks correct, then press "Approve" to approve it.

<figure><img src="../../.gitbook/assets/CleanShot 2025-01-20 at 17.33.42@2x.png" alt=""><figcaption></figcaption></figure>

#### 3.3 Once the request is approved, it should disappear from the installer, the new machine's enrollment should complete in a few seconds.

<figure><img src="../../.gitbook/assets/CleanShot 2025-01-20 at 17.34.46@2x.png" alt=""><figcaption></figcaption></figure>
{% endtab %}
{% endtabs %}
