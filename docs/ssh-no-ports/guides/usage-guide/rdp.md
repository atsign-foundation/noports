# 🖥️ RDP

## Outdated

This section is outdated. For the most current information, please see the updated documentation.

{% content-ref url="../../../noports-tunnel/" %}
[noports-tunnel](../../../noports-tunnel/)
{% endcontent-ref %}

## Overview

In this guide, we will demonstrate how to use SSH No Ports to bridge RDP on a remote development machine to localhost:3389 so we can access the RDP service locally.

## Local SSH Options

The `-o, --local-ssh-options` parameter allows you to specify additional options which are passed down to the ssh process. This allows us to use the built in TCP forwarding feature of SSH to expose the RDP port.

## TCP Forwarding

You can add the following configuration to your sshnp command:

```bash
sshnp ... -o '-L 33899:localhost:3389'
```

We bridge remote port 3389 to port 33899 on the local machine, since 3389 is possibly already in use on the local machine.

Now you can connect to localhost:33899 in your favorite RDP client, use the same user name and SSH private key that you used to connect via sshnp.

## Putting it altogether

Assuming your original command was:

```bash
sshnp -f @alice_client -t @alice_device -d my_server -h @rv_am -i ~/.ssh/id_ed25519
```

With a web server forwarding the command might look like:

<pre class="language-bash"><code class="lang-bash"><strong>sshnp -f @alice_client -t @alice_device -d my_server -h @rv_am -i ~/.ssh/id_ed25519 -o '-L 33899:localhost:3389'
</strong></code></pre>

Now you can connect to localhost:33899 in your favorite RDP client.

Use the same user name as the SSH session, and the same file as passed into `-i` as the SSH private key for authentication (`~/.ssh/id_ed25519` in this example).
