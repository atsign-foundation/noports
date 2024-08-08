---
icon: gear-complex-code
---

# Additional Configuration

## Additional Options

### -k, --key-file

Specify the `.atKeys` file for the `-f, --from` atSign if it's not stored in \~/.atsign/keys

### -v, --verbose

More logging.

### -l, --local-port

The local port which will be forwarded to the remote sshd port. If this is set to "0", it defers to to the OS to assign an ephemeral port.\
(Defaults to "0")

### --remote-sshd-port

The remote port which we expect sshd to be running on.

(Defaults to "22")

### -u, --remote-user-name

The username to use in the ssh session on the remote host.

(a.k.a. the user you want to sign in as)

### -U, --tunnel-user-name

The username to use for the initial ssh tunnel.

(a.k.a. the user running sshnpd)

### -i, --identity-file

Identity file to use for the ssh connection.

#### --identity-passphrase

Passphrase for identity file.

### -s, --send-ssh-public-key

Send the ssh public key to the remote host for automatic authorization.

### --idle-timeout

Number of seconds after which inactive ssh connections will be closed

(Defaults to "15")

### -o, --local-ssh-options

Additional ssh options which are passed to the ssh program.

### --add-forwards-to-tunnel

Enable this flag to pass the `-o, --local-ssh-options` to the initial ssh tunnel instead of the ssh session.&#x20;

### --ssh-client

Which ssh-client to use, `openssh` (default) or `dart`.

### --legacy-daemon

Request is to a legacy (< 4.0.0) noports daemon.

### -x, --output-execution-command

Output the ssh execution command instead of executing it.

### --config-file

Pass command line arguments via an environment file.

### --list-devices

List devices which have discovery (-u) enabled.

