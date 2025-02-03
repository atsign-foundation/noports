---
title: activate-cli-client-unix
---

{% hint style="warning" %}
If you've activated your **client** atSign on another device already, this step will not work. Instead, follow this guide: [reuse-your-client-atsign-on-another-machine](../../installation-faq/reuse-your-client-atsign-on-another-machine/ "mention")
{% endhint %}

This command activates your atSign and prompts you to enter an OTP. This is only done during the setup of a brand new atsign.

```
~/.local/bin/at_activate -a @<REPLACE>_client
```

### Enter the One Time Password (OTP) & Check your SPAM/PROMOTIONS folders

at\_activate will pause and wait for the input of a one time pin (OTP) sent to your email or phone number.\
\
Once activated, the master keys will save at `~/.atsign/keys`.
