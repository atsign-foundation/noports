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
  metadata:
    visible: true
  tags:
    visible: true
  actions:
    visible: true
---

# OpenWrt Installation Guide

{% embed url="https://vimeo.com/1060920058" %}
OpenWrt installation walk through
{% endembed %}

### Packages for OpenWrt 25.12+

Since OpenWrt 25.12 NoPorts is available in the main packages repository.

#### LuCI (web interface) install

From the LuCI web interface browse to `System` > `Software`, hit `Update lists...` then type `cssh` into the `Filter:` box. It should find two packages:

1. **csshnpd** - A small and portable daemon for NoPorts.
2. **luci-app-csshnpd** - LuCI config app for NoPorts daemon (csshnpd)

Clicking `Install` beside **luci-app-csshnpd** will install both (as the LuCI app depends on **csshnpd**).

Once installed `Log out` then log back in again to get the `Network` > `NoPorts` menu for config. Fill out the config tab with your device Atsign, manager Atsign, device name and the OTP for key generation. Click the `Enabled` box then hit `Save & Apply`.

Now go to the `NoPorts Enrollment` tab and follow the instructions there to generate a device key.

With the key in place navigate to `System`>`Startup` and `Start` the `sshnpd` service.

#### Command line install

NoPorts can also be installed on the command line by running:

```
apk update
apk add csshnpd
```

Now edit `/etc/config/sshnpd` to use your Atsigns, device name and device Atsign OTP:

```
config sshnpd
        option atsign   '@example_device'
        option manager  '@example_client'
        option device   'rutx10'
        option args     ''
        option otp      '123456'
        option enabled  '1'
```

Run `at_enroll.sh` on the device. It will ask you to approvement the enrollment on your client (where you previously activated the Atsigns and generated the OTP):

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

### Manual install on older OpenWrt using the LuCI web interface

First download the latest packages for your chosen architecture from our [releases](https://github.com/atsign-foundation/Atsign_OpenWRT_packages/releases) page.

We've created packages for aarch64\_cortex-a53, arm\_cortex-a7\_neon-vfpv4, ath79 (mips\_24k), mips\_siflower, ramips (mipsel\_24k) and x86\_64; but if your chosen architecture isn't there please let us know by opening an [issue](https://github.com/atsign-foundation/Atsign_OpenWRT_packages/issues). These packages _should_ work on older OpenWrt (and OpenWrt derivatives like GL.iNet), though note that the LuCI package uses the JavaScript framework that was introduced in OpenWrt 21.02.

With the packages ready to go, sign into the web interface for your router and go to `System`> `Software` in the menu. Click on `Upload Package` and `Browse` to the csshnpd package you downloaded. Click `Open` then `Upload` and `Install`. Repeat that process with the luci-app-csshnpd package.

For the new menu to appear you'll need to `Log out` then sign in again.

You can now go to `Network`>`NoPorts` and fill out the config tab with your device Atsign, manager Atsign, device name and the OTP for key generation. Click the `Enabled` box then hit `Save & Apply`.

Now go to the `NoPorts Enrollment` tab and follow the instructions there to generate a device key.

With the key in place navigate to `System`>`Startup` and `Start` the `sshnpd` service.

### Command line installation on older OpenWrt (and derivatives)

{% embed url="https://vimeo.com/1068947993" %}
Walk through of OpenWrt CLI installation onto a Teltonika RUT241
{% endembed %}

The [releases](https://github.com/atsign-foundation/Atsign_OpenWRT_packages/releases) page includes instructions for command line installation. These will work on OpenWrt derivatives that don't use LuCI (e.g. Teltonika) or if you just prefer working on the command line.

Those command line snippets set some variables for the `RELEASE` number, `ARCH` for system architecture and `PACKAGE` name then use `wget` to download the package from GitHub.

Packages are installed using `opkg install` for OpenWrt 24.10 and earlier releases that use `.ipk` type packages, or `apk add` for newer OpenWrt which uses `.apk` packages.

For example, to install the c1.0.14 release:

```
RELEASE="1.0.14"
ARCH=$(opkg print-architecture | grep ' 10$' | awk '{print $2}')
PACKAGE="csshnpd_${RELEASE}-1_${ARCH}.ipk"
wget -O ${PACKAGE} https://github.com/atsign-foundation/Atsign_OpenWRT_packages/releases/download/c${RELEASE}/${PACKAGE}
opkg install ${PACKAGE}
```

Now edit `/etc/config/sshnpd` to use your Atsigns, device name and device Atsign OTP:

```
config sshnpd
        option atsign   '@example_device'
        option manager  '@example_client'
        option device   'rutx10'
        option args     ''
        option otp      '123456'
        option enabled  '1'
```

Run `at_enroll.sh` on the device. It will ask you to approvement the enrollment on your client (where you previously activated the Atsigns and generated the OTP):

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
