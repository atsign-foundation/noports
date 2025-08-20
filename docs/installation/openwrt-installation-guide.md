---
description: How to install NoPorts onto an OpenWrt router.
icon: router
layout:
  width: default
  title:
    visible: true
  description:
    visible: true
  tableOfContents:
    visible: true
  outline:
    visible: true
  pagination:
    visible: false
---

# OpenWrt Installation Guide

{% embed url="https://vimeo.com/1060920058" %}
OpenWrt installation walk through
{% endembed %}

### Using the LuCI web interface

First download the latest packages for your chosen architecture from our [releases](https://github.com/atsign-foundation/Atsign_OpenWRT_packages/releases) page.

We've created packages for x86\_64, aarch64\_cortex-a53, ramips and mips\_siflower; but if your chosen architecture isn't there please let us know by opening an [issue](https://github.com/atsign-foundation/Atsign_OpenWRT_packages/issues).

With the packages ready to go, sign into the web interface for your router and go to `System`> `Software` in the menu. Click on `Upload Package` and `Browse` to the csshnpd package you downloaded. Click `Open` then `Upload` and `Install`. Repeat that process with the luci-app-csshnpd package.

For the new menu to appear you'll need to `Log out` then sign in again.

You can now go to `Network`>`NoPorts` and fill out the config tab with your device atSign, manager atSign, device name and the OTP for key generation. Click the `Enabled` box then hit `Save & Apply`.

No go to the `NoPorts Enrollment` tab and follow the instructions there to generate a device key.

With the key in place navigate to `System`>`Startup` and `Start` the `sshnpd` service.

### Command line installation

{% embed url="https://vimeo.com/1068947993" %}
Walk through of OpenWrt CLI installation onto a Teltonika RUT241
{% endembed %}

The [releases](https://github.com/atsign-foundation/Atsign_OpenWRT_packages/releases) page includes instructions for command line installation, though these may need to be edited to suit your system architecture.

Those command line snippets set some variables for the `RELEASE` number and `PACKAGE` name then use `wget` to download the package from GitHub.

Packages are installed using `opkg install` for OpenWrt 24.10 and earlier releases that use `.ipk` type packages, or `apk add` for newer OpenWrt which uses `.apk` packages.

For example, to install c1.0.3 on a Teltonika RUTX10 device, which uses the arm\_cortex-a7\_neon-vfpv4 architecture:

```
RELEASE="1.0.3"
PACKAGE="csshnpd_${RELEASE}-1_arm_cortex-a7_neon-vfpv4.ipk"
wget -O ${PACKAGE} https://github.com/atsign-foundation/Atsign_OpenWRT_packages/releases/download/c${RELEASE}/${PACKAGE}
opkg install ${PACKAGE}
```

Now edit `/etc/config/sshnpd` to use your atSigns, device name and device atSign OTP:

```
config sshnpd
        option atsign   '@example_device'
        option manager  '@example_client'
        option device   'rutx10'
        option args     ''
        option otp      '123456'
        option enabled  '1'
```

Run `at_enroll.sh` on the device. It will ask you to approvement the enrollment on your client (where you previously activated the atSigns and generated the OTP):

```
at_activate approve -a @example_device --arx noports --drx rutx10
```

On the device you should see a message saying enrollment is complete, and that the .atKeys file has been written.

Now start the sshnpd service:

```
service sshnpd start
```

And you should be ready to connect to the device:

```
sshnp -f @example_client -t @example_device -d rutx10_remote -h rv_eu
```
