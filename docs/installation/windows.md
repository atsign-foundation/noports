---
icon: windows
description: SSH No Ports Windows
---

# Windows Installation Guide

### Installation <a href="#installation" id="installation"></a>

First, open a powershell terminal.

Then run the following command:

```powershell
Invoke-WebRequest -Uri "https://github.com/atsign-foundation/noports/releases/latest/download/universal.ps1" -OutFile "universal.ps1"
```

#### Running the installer <a href="#running-the-installer" id="running-the-installer"></a>

After downloading the installer, you can run the installer by running the following command:

```powershell
.\universal.ps1
```

#### Device Side <a href="#device-side" id="device-side"></a>

After finishing the device install, you will have a windows service installed called `sshnpd`. This service will be started automatically and will be running in the background.

#### Client Side <a href="#client-side" id="client-side"></a>

After finishing the client install, you will have a binary called `{device_name@device_atsign}` installed on your machine. You can use this binary to connect to the device.

Example:

```powershell
esp_32@wanderinggazebo 
```

or

```
.\esp_32@wanderinggazebo.ps1 
```

### SSH Key Generation <a href="#ssh-key-generation" id="ssh-key-generation"></a>

To generate an SSH key, you can run the following command:

For RSA:

```powershell
ssh-keygen
```

For Ed25519:

```powershell
ssh-keygen -t ed25519
```

### Activate the device atSign <a href="#activate-the-device-atsign" id="activate-the-device-atsign"></a>

First time activating this atSign

```powershell
at_activate onboard -a "@<REPLACE>_device"
```

or

<pre><code>Users\&#x3C;<a data-footnote-ref href="#user-content-fn-1">user</a>>\.local\bin\at_activate onboard -a "&#x3C;REPLACE>_device"
</code></pre>

\
Activated this atSign before ? As before if this atSign is already activated elsewhere then you need to copy the .atKeys file for this atSign into the \~/.atsign/keys/ directory.

### RDP? Check this out.

{% content-ref url="../use-cases/rdp.md" %}
[rdp.md](../use-cases/rdp.md)
{% endcontent-ref %}

[^1]: replace
