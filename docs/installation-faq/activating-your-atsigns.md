---
description: Steps for client and device Atsign
icon: at
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

# How to activate an Atsign

## Overview

NoPorts needs to be installed on both the machine you are going to connect to (device) and the machine you are going to connect from (client). NoPorts uses Atsigns as addresses and you will need two, one for the client and one for the device.

{% hint style="danger" %}
If you don't own a pair of Atsigns/addresses, please visit [my.noports.com](https://my.noports.com/no-ports-plans) before continuing.
{% endhint %}

Example client Atsign

```
@sshnp_client
```

Example device Atsign

```
@sshnp_device
```

## Activate your Atsigns

{% hint style="info" %}
Activation of a particular Atsign is only done once. During activation, cryptographic keys are cut and stored on your machine.

You will activate both the client Atsign _**and**_ the device Atsign on your client machine, and you will then authorize your device(s) to use the device Atsign.
{% endhint %}

### Activate the client Atsign

(1) Run the at\_activate command for the client Atsign

<pre class="language-bash"><code class="lang-bash"><strong>~/.local/bin/at_activate -a @&#x3C;REPLACE>_client
</strong></code></pre>

(2) Enter the One Time Password (OTP) & Check your SPAM/PROMOTIONS folders

at\_activate will pause and wait for the input of a one time pin (OTP) before you can continue. You should receive this pin to the contact information associated with the registration of your NoPorts address (i.e. email or text message).

{% hint style="warning" %}
If you are using a gmail.com account we have seen that sometimes the OTP gets stuck in the SPAM or PROMOTIONS folder. If you do not see the OTP check those folders.
{% endhint %}

Once you receive the message, enter the pin into the application and press enter to continue. The application should proceed to create the cryptographic keys and store them in the `~/.atsign/keys/` directory with a filename that includes the Atsign.

### Activate the device Atsign

1\) Run the at\_activate command for the device Atsign

<pre class="language-bash"><code class="lang-bash"><strong>~/.local/bin/at_activate -a @&#x3C;REPLACE>_device
</strong></code></pre>

2\) Enter the One Time Password (OTP) & Check your SPAM/PROMOTIONS folders

Again, at\_activate will pause and wait for the input of a one time pin (OTP) before you can continue. You should receive this pin to the contact information associated with the registration of your NoPorts address (i.e. email or text message).

{% hint style="warning" %}
If you are using a gmail.com account we have seen that sometimes the OTP gets stuck in the SPAM or PROMOTIONS folder. If you do not see the OTP check those folders.
{% endhint %}

Once you receive the message, enter the pin into the application and press enter to continue. The application should proceed to create the cryptographic keys and store them in the `~/.atsign/keys/` directory with a filename that includes the atSign.
