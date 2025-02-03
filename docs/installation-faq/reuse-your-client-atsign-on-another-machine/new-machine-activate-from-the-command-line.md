# New machine: activate from the command line

{% hint style="info" %}
Make sure to replace the appropriate values:\
`<REPLACE_client>` to your client atSign\
`<client_device_name>` to a unique name for the device\
`<PASSCODE>` with the passcode from step 1
{% endhint %}

### Step 2) Enroll the new key pair (send a request for keys from the new machine)

```
~/.local/bin/at_activate enroll -a @<REPLACE_client> \
  -s <PASSCODE> \
  -p noports \
  -k ~/.atsign/keys/@<REPLACE_client>_key.atKeys \
  -d <client_device_name> \
  -n "sshnp:rw,sshrvd:rw"
```
