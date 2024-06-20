# 🗃️ SFTP

## Outdated

This section is outdated. For the most current information, please see the updated documentation.

{% content-ref url="../../../noports-tunnel/" %}
[noports-tunnel](../../../noports-tunnel/)
{% endcontent-ref %}

## Overview

In this guide, we will demonstrate how to use SSH No Ports to bridge SFTP on a remote development machine to localhost:2222 so we can access it in an SFTP client locally.

## Local SSH Options

The `-o, --local-ssh-options` parameter allows you to specify additional options which are passed down to the ssh process. This allows us to use the built in TCP forwarding feature of SSH to expose the SFTP port.

## TCP Forwarding

You can add the following configuration to your sshnp command:

```bash
sshnp ... -o '-L 2222:localhost:22'
```

We bridge remote port 22 to port 2222 on the local machine, since 22 is already in use on the local machine.

Now you can connect to localhost:2222 in your favorite SFTP client, use the same user name and SSH private key that you used to connect via sshnp.

## Putting it altogether

Assuming your original command was:

```bash
sshnp -f @alice_client -t @alice_device -d my_server -h @rv_am -i ~/.ssh/id_ed25519
```

With a web server forwarding the command might look like:

```bash
sshnp -f @alice_client -t @alice_device -d my_server -h @rv_am -i ~/.ssh/id_ed25519 -o '-L 2222:localhost:22'
```

Now you can connect to localhost:2222 in your favorite SFTP client.&#x20;

Use the same user name as the SSH session, and the same file as passed into `-i` as the SSH private key for authentication (`~/.ssh/id_ed25519` in this example).
