# 🗃️ SFTP

In this guide, we demonstrate how to use the NoPorts Tunnel to bridge SFTP on a remote development machine to localhost:2222 so we can access it in an SFTP client locally.

\
The command should look like:

```bash
npt -f @alice_client -t @alice_device -d my_server -r @rv_am -p 22 -l 2222
```

Now you can connect to localhost:2222 in your favorite SFTP client.

### To learn more about NPT

{% content-ref url="basic-usage/" %}
[basic-usage](basic-usage/)
{% endcontent-ref %}
