---
icon: google
---

# Automated Installation on Google Cloud Platform (GCP)

Navigate to Compute Engine > VM instances and hit the `+ CREATE INSTANCE` button as usual, then select Name, Region, Machine configuration etc.

Expand `Advanced options` at the bottom of the page:

<div align="left">

<figure><img src="../../.gitbook/assets/GCP_Advanced_options.PNG" alt=""><figcaption></figcaption></figure>

</div>

Then scroll down and expand `Management`:

<div align="left">

<figure><img src="../../.gitbook/assets/GCP_Management.PNG" alt=""><figcaption></figcaption></figure>

</div>

In the `Automation` section paste in your customised startup script like:

```bash
#!/bin/bash
# Modify these lines to set the installation specific variables
ATCLIENT="@democlient"
ATDEVICE="@demodevice"
DEVNAME="cloudvm1"
OTP="739128"
USER="noports"
# The rest of the script shouldn't be changed
useradd ${USER}
export HOME="/home/${USER}"
export SUDO_USER="${USER}"
mkdir -p /run/atsign
cd /run/atsign
VERSION=$(wget -q -O- "https://api.github.com/repos/atsign-foundation/noports/releases/latest" | grep -Po '"tag_name": "v\K.*?(?=")')
wget https://github.com/atsign-foundation/noports/releases/download/v${VERSION}/universal.sh
sh universal.sh -t device -c ${ATCLIENT} -d ${ATDEVICE} -n ${DEVNAME}
/usr/local/bin/at_activate enroll -a ${ATDEVICE} -s ${OTP} -p noports -k /home/${USER}/.atsign/keys/${ATDEVICE}_key.atKeys -d ${DEVNAME} -n "sshnp:rw,sshrvd:rw"
chown -R ${USER}:${USER} /home/${USER}
```

NB this script is creating a new user `noports` to deal with the fact that GCP images don't have default usernames.

Once filled, the box should look something like:

<div align="left">

<figure><img src="../../.gitbook/assets/GCP_Startup_script.PNG" alt=""><figcaption></figcaption></figure>

</div>

The VM is now ready for `Create`

After a few minutes the APKAM key can be approved:

```
at_activate approve -a @demodevice --arx noports --drx cloudvm1
```

If the VM isn't quite ready you'll see:

```
Found 0 matching enrollment records
No matching enrollment(s) found
```

Waiting a little longer and retrying should produce a successful approval:

```
Found 1 matching enrollment records
Approving enrollmentId 0bd3613d-d3e2-45b3-b175-8cab06c9bad0
Server response: AtEnrollmentResponse{enrollmentId: 0bd3613d-d3e2-45b3-b175-8cab06c9bad0, enrollStatus: EnrollmentStatus.approved}
```

The VM is now ready for connection with the NoPorts client.
