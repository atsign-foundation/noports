---
description: How to manage tons of NoPorts SSH connections with Putty
icon: windows
---

# PuTTY config

## Overview

This guide will help you setup some very minimal Python scripts to manage connections with NoPorts. In most cases only 4-5 lines of python will be required to setup a new device.

### Requirements

* Python (version 3)
* OpenSSH (acts as a proxy between NoPorts & PuTTY)

### Usage

Once you've setup your configuration, you will be able to SSH over NoPorts by double clicking a simple shortcut. It will first launch NoPorts, then once NoPorts is started, it will setup your PuTTY session.

### The Base Configuration

The base configuration contains all of the core logic for starting a PuTTY session over NoPorts. Copy this to the folder where you want to store all of your device configurations, name the file `noports_base.py`.

<details>

<summary>Open this to copy the code</summary>

{% code title="noports_base.py" %}
```python
from subprocess import run, PIPE, Popen, CREATE_NO_WINDOW
from socket import socket

class noports_config:
    # NoPorts configs
    client_atsign: str
    device_atsign: str
    device_name: str
    relay_atsign: str
    openssh_keyfile: str
    upload_public_key: bool = False

    # Putty configs
    ssh_user: str
    local_host: str = "localhost"
    local_port: int = None
    putty_keyfile: str

    def get_ephemeral_port(self) -> int:
        sock = socket()
        sock.bind(('', 0))
        port = sock.getsockname()[1]
        sock.close()
        return port

    def run_noports(self):
        if self.local_port == None:
            self.local_port = self.get_ephemeral_port()
        args = ["C:\\Program Files\\NoPorts\\sshnp.exe",
            "-f", self.client_atsign,
            "-t", self.device_atsign,
            "-d", self.device_name,
            "-r", self.relay_atsign,
            "-l", f"{self.local_port}",
            "-i", self.openssh_keyfile,
            "-u", self.ssh_user,
            "-x",
        ]
        if self.upload_public_key:
            args.append("-s")
        result = run(args, stdout=PIPE)
        return result.stdout

    def run_putty(self):
        Popen(["C:\\Program Files\\PuTTY\\putty.exe", 
            "-proxycmd",  self.run_noports(),
            f"{self.ssh_user}@{self.local_host}",
            "-P", f"{self.local_port}",
            "-i", self.putty_keyfile,
        ], creationflags=CREATE_NO_WINDOW)
 
# TODO: Change the strings below to setup your default profile values
class my_default_config(noports_config):
    client_atsign = "@alice_client"
    device_atsign = "@alice_device"
    relay_atsign = "@rv_am"

    # path to ssh keys in openssh key format
    # you may use PuTTYgen to convert from .ppk
    openssh_keyfile = "C:\\Users\\chant\\.ssh\\id_ed25519"

    # path to ssh keys in putty key format
    # you may use PuTTYgen to convert another key to .ppk
    putty_keyfile = "C:\\Users\\chant\\.ssh\\id_ed25519.ppk"
    
    # Upload your SSH public key automatically
    # -s must be enabled on sshnpd for this to work
    upload_public_key = False 
    
    # The username to sign in as
    ssh_user = "alice"
```
{% endcode %}

</details>

### Setting up a new device

To setup a new device, create a new python (`.py`) in the same folder where you created `noports_base.py`. Then copy the following file:

{% code title="example_config.py" %}
```python
from .noports_base import my_default_config
class device(my_default_config):
    # TODO: setup device name and override any default config here
    # make sure to indent these lines the same
    device_name = "my_device_name"
    pass
device().run_putty()
```
{% endcode %}

### Overriding the Default Configuration

If you have a bunch of devices that all use the same configuration values, then you'd want to put that in the noports\_base configuration. However, there may be a few devices where you want to use a different value. You can simply override the value from your device profile:

{% code title="override_defaults.py" %}
```python
from .noports_base import my_default_config
class device(my_default_config):
    # TODO: setup device name and override any default config here
    # make sure to indent these lines the same
    device_name = "my_device_name"
    # Overriding the client & device atsign:
    client_atsign = "@my_other_client_atsign"
    device_atsign = "@my_other_device_atsign"
    pass
device().run_putty()
```
{% endcode %}

### Create Shortcuts to Organize your Profiles

Because all of the profiles need to be in the same directory as the `noports_base.py` file, you can't easily move those files around to organize them. To work around this, simply create shortcuts of all the device profiles, then you can move and rename those shortcuts around freely.

<figure><img src="../.gitbook/assets/CleanShot 2025-03-11 at 16.31.23@2x.png" alt=""><figcaption><p>Example of separate shortcuts into different folders</p></figcaption></figure>
