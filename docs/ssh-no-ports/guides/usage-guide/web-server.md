# 🌐 Web Server

## Outdated

This section is outdated. For the most current information, please see the updated documentation.

{% content-ref url="../../../noports-tunnel/" %}
[noports-tunnel](../../../noports-tunnel/)
{% endcontent-ref %}

## Overview

In this guide, we will demonstrate how to use SSH No Ports to bridge a web server on a remote development machine to localhost:80 so we can access the web server locally.

## Local SSH Options

The `-o, --local-ssh-options` parameter allows you to specify additional options which are passed down to the ssh process. This allows us to use the built in TCP forwarding feature of SSH to expose the webserver's port.

## TCP Forwarding

Assuming you already have a web server setup, you can add the following configuration to your sshnp command:

```bash
sshnp ... -o '-L 80:localhost:8080'
```

We assume that the web server is running on port 8080, you can replace it with the port that your web server is running on.

Now you can access [localhost:80](http://localhost) in your browser to access the webserver locally.

## Putting it altogether

Assuming your original command was:

```bash
sshnp -f @alice_client -t @alice_device -d my_server -h @rv_am -i ~/.ssh/id_ed25519
```

With a web server forwarding the command might look like:

<pre class="language-bash"><code class="lang-bash"><strong>sshnp -f @alice_client -t @alice_device -d my_server -h @rv_am -i ~/.ssh/id_ed25519 -o '-L 80:localhost:8080'
</strong></code></pre>

Now you can go to [localhost:80](http://localhost) in your browser to access the webserver locally.
