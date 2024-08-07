---
icon: globe-pointer
---

# Web Server

Here, we demonstrate how to use the NoPorts Tunnel to bridge a web server on a remote machine to localhost:80 so we can access the web server locally.&#x20;

{% hint style="info" %}
We are assuming that the web server is running on port `8080`, you can replace it with the port that your web server is running on. (Also works over TLS with port 443)
{% endhint %}

\
The command should look like:

```
npt -f @<client> -t @<device> -d <device name> -r @<relay> -p 8080 -l 80
```

Example:

```
npt -f @alice_client -t @alice_device -d my_server -r @rv_am -p 8080 -l 80
```

Now you can access localhost:80 in your browser to access the web server locally.

### To learn more about NPT

{% content-ref url="../usage/basic-usage/" %}
[basic-usage](../usage/basic-usage/)
{% endcontent-ref %}
