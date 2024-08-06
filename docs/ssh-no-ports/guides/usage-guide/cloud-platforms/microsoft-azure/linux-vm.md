# ⌨️ Linux VM

Connections on Azure are exactly like [basic-usage](../../basic-usage/ "mention"), but you must make sure to supply your SSH Key provided for your native SSH connections on Azure.

```
sshnp -f @<client> -t @<device> -h @<region> -i ~/.ssh/azure_key
```

This is an example of how the command should look:&#x20;

```bash
sshnp -f @azure_cloud_shell -t @iot_device04 -h @rv_am -i ~/.ssh/azure_key
```
