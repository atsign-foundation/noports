---
description: How to install NoPorts as part of creating a new VM
icon: cloud
---

# Cloud Installation Guides

The NoPorts daemon can be installed on a Linux cloud virtual machine (VM) using a cloud-init script of the form:

```bash
#!/bin/bash
# Modify these lines to set the installation specific variables
ATCLIENT="@changeme_clientatsign"
ATDEVICE="@changeme_deviceatsign"
DEVNAME="changeme_devicename"
OTP="123456"
USER="changeme_user"
# The rest of the script shouldn't be changed
export HOME="/home/${USER}"
export SUDO_USER="${USER}"
mkdir -p /run/atsign
cd /run/atsign
VERSION=$(wget -q -O- "https://api.github.com/repos/atsign-foundation/noports/releases/latest" | grep -Po '"tag_name": "v\K.*?(?=")')
wget https://github.com/atsign-foundation/noports/releases/download/v${VERSION}/universal.sh
sh universal.sh -t device -c ${ATCLIENT} -d ${ATDEVICE} -n ${DEVNAME}
/usr/local/bin/at_activate enroll -a ${ATDEVICE} -s ${OTP} -p noports -k /home/${USER}/.atsign/keys/${ATDEVICE}_key.atKeys -d ${DEVNAME} -n "sshnp:rw,sshrvd:rw"
chown -R ${USER}:${USER} /home/${USER}/.atsign
```

Some clouds, such as Azure and Oracle Cloud will take the script pretty much as presented above. Other clouds, including AWS and GCP need alternate formatting or additional customisation.

In all cases the variables in the first section of the script should be changed to match the atSigns being used, the desired device name, the Linux username and the one time password (OTP) or semi-permanent passcode (SPP) being used. e.g.:

```bash
#!/bin/bash
# Modify these lines to set the installation specific variables
ATCLIENT="@democlient"
ATDEVICE="@demodevice"
DEVNAME="cloudvm1"
OTP="643791"
USER="ubuntu"
```

Once the VM is started (which will generally take a few minutes) the NoPorts daemon will be waiting for an APKAM key in order to start up. That key can be approved using `at_activate`:

```bash
at_activate approve -a @democlient --arx noports --drx cloudvm1
```

### Cloud Specific Guides

{% content-ref url="automated-installation-on-oracle-cloud-infrastructure-oci.md" %}
[automated-installation-on-oracle-cloud-infrastructure-oci.md](automated-installation-on-oracle-cloud-infrastructure-oci.md)
{% endcontent-ref %}
