# Old machine: activate from the command line

{% hint style="info" %}
Make sure to replace the appropriate values:\
`<REPLACE_client>` to your client atSign\
`<client_device_name>` with the device name from step 2
{% endhint %}

### Step 1) Generate an OTP (one time pin code)

```
~/.local/bin/at_activate otp -a @<REPLACE_client>
```

### Step 3) Approve the request

```
~/.local/bin/at_activate approve -a @<REPLACE_client> \
  --arx noports \
  --drx <client_device_name>
```

