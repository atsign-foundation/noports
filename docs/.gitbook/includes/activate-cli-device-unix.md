---
title: activate-cli-device-unix
---

This command activates your atSign and prompts you to enter an OTP. This is only done during the setup of a brand new atsign.

```
~/.local/bin/at_activate -a @<REPLACE>_device
```

### Enter the One Time Password (OTP) & Check your SPAM/PROMOTIONS folders

at\_activate will pause and wait for the input of a one time pin (OTP) sent to your email or phone number.

Once activated, the management keys will be saved in `~/.atsign/keys`.
