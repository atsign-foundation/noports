---
icon: memo-circle-info
---

# Installation Details

## Device Names

Each device atSign can be used for multiple devices and so each device needs a unique name. The device name is limited to alphanumeric [snake case](https://www.tuple.nl/knowledge-base/snake-case) (lowercase alphanumeric separated by \_ ) up to 36 characters.

Example snake case device names

```
my_host
canary02
oci_mail_0001
dc_001_row_009_rack_0067_ru_014
```

## SSH Keys

SSH uses keys to authenticate as well as having a fallback of using passwords, but using keys is easier and more secure than "mypassword!". If you already are a seasoned user of SSH then you might have keys already but if not then on the client machine you can create a key pair using ssh-keygen.

Example ssh-keygen command to create SSH Key Pair

```
ssh-keygen -t ed25519 -a 100 -f ~/.ssh/id_ed25519
```

## Want to use your client atSign on a different machine?

You can either:

1. Generate a new set of cryptographic keys (Recommended), or
2. Copy the cryptographic keys from the machine where it's been activated in the past (Not recommended)

**1) Generate a new set of cryptographic keys (Recommended)**

* We use the same approach as in the "Authorize the device to use the device atSign" section above
* i) Generate a passcode. On the _original_ client machine, run

```
~/.local/bin/at_activate otp -a @<REPLACE>_client
```

* ii) Make an authorization request. On the _new_ client machine, run

```
~/.local/bin/at_activate enroll -a @<REPLACE>_client \
  -s <PASSCODE> \
  -p noports \
  -k ~/.atsign/keys/@<REPLACE_client>_key.atKeys \
  -d <client_device_name> \
  -n "sshnp:rw,sshrvd:rw"
```

* iii) Approve the authorization request. On the _original_ client machine, run

```
~/.local/bin/at_activate approve -a @<REPLACE>_client \
  --arx noports \
  --drx <client_device_name>
```

**2) (Not recommended) Copy the cryptographic keys from the machine where it's been activated in the past**

* The atSign keys file will be located at `~/.atsign/keys/` directory with a filename that will include the atSign. Copy this file from your other machine to the same location on the machine that you are installing SSH No Ports on, using `scp` or similar.
