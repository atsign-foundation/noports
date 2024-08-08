---
icon: at
---

# Activating your atSigns

## Overview

SSH No Ports software needs to be installed on both the machine you are going to SSH to (device) and the machine you are going to SSH from (client). SSH No Ports uses [atSigns](https://atsign.com/faqs/) as addresses and you will need two, one for the client and one for the device

{% hint style="danger" %}
If you don't own a pair of atSigns/addresses, please visit [the registrar](https://my.noports.com/no-ports-invite/14dayfreetrial) before continuing.
{% endhint %}

Example client atSign&#x20;

```
@sshnp_client
```

Example device atSign

```
@sshnp_device
```

## Activate your atSigns

{% hint style="info" %}
Activation of a particular atSign is only done once. During activation, cryptographic keys are cut and stored on your machine.

You will activate both the client atSign _**and**_ the device atSign on your client machine, and you will then authorize your device(s) to use the device atSign.
{% endhint %}

### Activate the client atSign

(1) Run the at\_activate command for the client atSign

{% tabs %}
{% tab title="Linux" %}
<pre class="language-bash"><code class="lang-bash"><strong>~/.local/bin/at_activate -a @&#x3C;REPLACE>_client
</strong></code></pre>
{% endtab %}

{% tab title="macOS" %}
```bash
~/.local/bin/at_activate -a @<REPLACE>_client
```
{% endtab %}
{% endtabs %}

(2) Enter the One Time Password (OTP) & Check your SPAM/PROMOTIONS folders

at\_activate will pause and wait for the input of a one time pin (OTP) before you can continue. You should receive this pin to the contact information associated with the registration of your noports address (i.e. email or text message).

{% hint style="warning" %}
If you are using a gmail.com account we have seen that sometimes the OTP gets stuck in the SPAM or PROMOTIONS folder. If you do not see the OTP check those folders.&#x20;
{% endhint %}

Once you receive the message, enter the pin into the application and press enter to continue. The application should proceed to create the cryptographic keys and store them in the  `~/.atsign/keys/` directory with a filename that includes the atSign.

### Activate the device atSign

1\) Run the at\_activate command for the device atSign

{% tabs %}
{% tab title="Linux" %}
<pre class="language-bash"><code class="lang-bash"><strong>~/.local/bin/at_activate -a @&#x3C;REPLACE>_device
</strong></code></pre>
{% endtab %}

{% tab title="macOS" %}
```bash
~/.local/bin/at_activate -a @<REPLACE>_device
```
{% endtab %}
{% endtabs %}

2\) Enter the One Time Password (OTP) & Check your SPAM/PROMOTIONS folders

Again, at\_activate will pause and wait for the input of a one time pin (OTP) before you can continue. You should receive this pin to the contact information associated with the registration of your noports address (i.e. email or text message).

{% hint style="warning" %}
If you are using a gmail.com account we have seen that sometimes the OTP gets stuck in the SPAM or PROMOTIONS folder. If you do not see the OTP check those folders.&#x20;
{% endhint %}

Once you receive the message, enter the pin into the application and press enter to continue. The application should proceed to create the cryptographic keys and store them in the  `~/.atsign/keys/` directory with a filename that includes the atSign.
