---
icon: desktop-arrow-down
---

# Installation

## Overview

Installing NoPorts consists of the following steps:

1. [Obtain your NoPorts license](./#id-1.-obtain-your-license) from [noports.com](https://my.noports.com/no-ports-invite/14dayfreetrial)\
   _You can start with a 14-day evaluation license, no credit-card required_
2. [Install NoPorts](./#id-2.-install-noports) software on your devices
   1. Install the NoPorts client\
      _typically on your desktop_
      1. Activate both management keys on your desktop
   2. Install the NoPorts daemon\
      _onto the device(s) you want to connect to, repeat for each device_
      1. Use our enrollment tool to activate your device
3. Use NoPorts!
4. Reach out to us\
   We want to hear about your use-cases. We take all feedback into consideration, it helps us make the best tool we possibly can.&#x20;

## 1. Obtain your license

You will need to register from noports.com.

{% hint style="info" %}
During registration, you will receive two atSigns, these are the identifiers that you will need to setup and use NoPorts, make sure to save them somewhere for later
{% endhint %}

There are two options for registration:

1. [Register for the 14-day evaluation](https://my.noports.com/no-ports-invite/14dayfreetrial)&#x20;
2. Or for additional licenses, use [the main portal](https://my.noports.com/login)\
   after signing in, click "Buy atSigns"

## 2. Install the NoPorts client

We have several installation options available depending on the platform and use case:

### 2.1. Install for the command line

These guides will install the terminal based version of the NoPorts client:

{% content-ref url="linux/" %}
[linux](linux/)
{% endcontent-ref %}

{% content-ref url="windows.md" %}
[windows.md](windows.md)
{% endcontent-ref %}

### 2.2. Desktop application installation guides

We have two desktop applications available for NoPorts:

#### NoPorts Desktop (coming soon)

This version of NoPorts supports all single-socket[^1] TCP applications, such as:

* Remote desktop like RDP & VNC
* HTTP(s) like REST APIs & web applications
* [File sharing with SMB](#user-content-fn-2)[^2]
* [Many more use-cases](#user-content-fn-3)[^3]

The application is currently in alpha, if you would like early access, please reach out to [info@noports.com](mailto:info@noports.com).

#### **SSH NoPorts**

This version of NoPorts only supports SSH, with terminal windows embedded into the app.

* [MacOS](https://apps.apple.com/us/app/ssh-no-ports-desktop/id6476198591?mt=12)
* [Windows](https://apps.microsoft.com/detail/9pbx5vrvqc2z)
* Linux - we don't have official builds, but you can [build from source](https://github.com/atsign-foundation/noports/tree/trunk/packages/dart/sshnoports)\
  [Reach out to us](mailto:support@noports.com) if you need some assistance.

## 3. Install the NoPorts daemon

### 3.1. Use the guided installer (recommended)

These guides will help you use the guided installer to install the NoPorts daemon.

{% hint style="info" %}
These use the same installers as the command-line client.\
Don't worry! You have the right installer.
{% endhint %}

{% content-ref url="linux/" %}
[linux](linux/)
{% endcontent-ref %}

{% content-ref url="windows.md" %}
[windows.md](windows.md)
{% endcontent-ref %}

### 3.2. Manual installation guides

These are supplementary guides, which involve some manual work. You may require this in a bespoke environment, but we recommend using the [automated installation guides](./#id-2.1.-automated-installation-guides-recommended) whenever possible.

{% content-ref url="advanced-installation-guides/" %}
[advanced-installation-guides](advanced-installation-guides/)
{% endcontent-ref %}

{% content-ref url="custom-os-device-installs/ipfire.md" %}
[ipfire.md](custom-os-device-installs/ipfire.md)
{% endcontent-ref %}

## 4. Use NoPorts

Start by exploring the use-cases available in the side bar. We also provide in-depth usage information:

{% content-ref url="../usage/" %}
[usage](../usage/)
{% endcontent-ref %}



[^1]: There are some multi-socket use-cases which also work. If you have a use-case please reach out to us.

[^2]: Currently not supported on Windows due to OS specific limitations.

[^3]: Please reach out to us, we would love to help make your use-case possible.
