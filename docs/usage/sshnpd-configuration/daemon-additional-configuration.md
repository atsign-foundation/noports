---
description: NoPorts daemon `sshnpd` additional configuration
icon: gear
---

# Daemon Additional Configuration

## Additional Options

### -k, --key-file, --keyFile

Specify the `.atKeys` file for the `-a, --atsign` atSign if it's not stored in `~/.atsign/keys`

### -s, --\[no-]sshpublickey

When set, sshnpd adds the ssh public key an authorized Atsign sends it to `~/.ssh/authorized_keys` of the user it runs as, creating `~/.ssh` (mode 0700) and `authorized_keys` (mode 0600) when they are missing.

Each key is written as one line that starts with `from="127.0.0.1,::1"`, so it allows logins only from the device's loopback address, which is where every NoPorts ssh session reaches sshd. The key's comment is kept when it is ASCII and at most 256 characters long, and left out otherwise.

A key already on a line in `authorized_keys` is not added again. When that line does not have the `from="127.0.0.1,::1"` option, sshnpd leaves it as it is and logs a warning.

sshnpd adds nothing, and logs a warning, for a value over 8 KiB, a value holding a control character, or a value that is not one key of a supported type (`ssh-ed25519`, `ssh-rsa`, `rsa-sha2-256`, `rsa-sha2-512`, `ecdsa-sha2-nistp256`, `ecdsa-sha2-nistp384` or `ecdsa-sha2-nistp521`) whose key data is of that type.

### -h, --hide

Hides the device from advertising its information to the manager atSign. Even with this enabled, sshnpd will still respond to ping requests from the manager. (This takes priority over the \[now deprecated] -u / --un-hide flag).

### -v, --\[no-]verbose

More logging

### --ssh-client

What to use for outbound ssh connections.

\[openssh (default), dart]

### --root-server

atDirectory domain

(Defaults to "root.atsign.org")

### --device-group

The name of this device's group. When delegated authorization is being used then the group name is sent to the authorizer service as well as the device name, this daemon's atSign, and the client atSign which is requesting a connection

(Defaults to "\_\_none\_\_")

### --local-sshd-port

Port on which sshd is listening locally on localhost

(Defaults to "22")

### -S, --sshpublickey-permissions

When --sshpublickey is enabled, sshnpd adds these authorized\_keys options to each key's line, after its own `from="127.0.0.1,::1"` option. For example, `-S no-pty` writes lines starting `from="127.0.0.1,::1",no-pty`.

sshnpd sets the `from=` option itself, so it leaves out any `from` option given here, logging a warning at startup. A value holding a newline stops sshnpd at startup. The C daemon takes this option too.

(Defaults to "")

### --ephemeral-permissions

The permissions which will be added to the authorized\_keys file for the ephemeral public keys which are generated when a client is connecting via forward ssh e.g. PermitOpen="host-1:3389",PermitOpen="localhost:80"

(Defaults to "")

### --ssh-algorithm

Use RSA 4096 keys rather than the default ED25519 keys

\[ssh-ed25519 (default), ssh-rsa]

### --storage-path

Directory for local storage.

(Defaults to `$HOME/.atsign/storage/$atSign/.npd/$deviceName/`)

### --permit-open,--po

Comma separated-list of host:port to which the daemon will permit a connection from an authorized client. Hosts may be dns names or ip addresses.

(Defaults to "localhost:22,localhost:3389")

### --client-key-check-secs

How often, in seconds, to check that the enrollment each client signed its session request with is still valid. The daemon ends a session once that enrollment is revoked, superseded, deleted or expires. Only signed requests are checked (see `--require-enrollment-signature`), and only while the daemon that started the session keeps running. 0 turns the check off.

(Defaults to "10")

### --\[no-]require-enrollment-signature

Refuse session requests that aren't signed with the client's enrollment key, or whose signature can't be checked because the client's atServer can't be reached. Older clients, and clients whose enrollment holds no signing key, don't sign them.
