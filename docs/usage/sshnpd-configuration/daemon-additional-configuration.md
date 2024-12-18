---
description: NoPorts daemon `sshnpd` additional configuration
icon: gear
---

# Daemon Additional Configuration

### Additional Options

#### -k, --key-file, --keyFile

Specify the `.atKeys` file for the `-a, --atsign` atSign if it's not stored in `~/.atsign/keys`

#### -s, --\[no-]sshpublickey

When set, will update authorized\_keys to include public key sent by manager.

#### -h, --hide

Hides the device from advertising its information to the manager atSign. Even with this enabled, sshnpd will still respond to ping requests from the manager. (This takes priority over the \[now deprecated] -u / --un-hide flag).

#### -v, --\[no-]verbose

More logging

#### --ssh-client

What to use for outbound ssh connections.

\[openssh (default), dart]

#### --root-domain

atDirectory domain

(Defaults to "root.atsign.org")

#### --device-group

The name of this device's group. When delegated authorization is being used then the group name is sent to the authorizer service as well as the device name, this daemon's atSign, and the client atSign which is requesting a connection

(Defaults to "\_\_none\_\_")

#### --local-sshd-port

Port on which sshd is listening locally on localhost

(Defaults to "22")

#### -S, --sshpublickey-permissions

When --sshpublickey is enabled, will include the specified permissions in the public key entry in authorized\_keys

(Defaults to "")

#### --ephemeral-permissions

The permissions which will be added to the authorized\_keys file for the ephemeral public keys which are generated when a client is connecting via forward ssh e.g. PermitOpen="host-1:3389",PermitOpen="localhost:80"

(Defaults to "")

#### --ssh-algorithm

Use RSA 4096 keys rather than the default ED25519 keys

\[ssh-ed25519 (default), ssh-rsa]

#### --storage-path

Directory for local storage.

(Defaults to `$HOME/.atsign/storage/$atSign/.npd/$deviceName/`)

#### --permit-open,--po

Comma separated-list of host:port to which the daemon will permit a connection from an authorized client. Hosts may be dns names or ip addresses.

(Defaults to "localhost:22,localhost:3389")

