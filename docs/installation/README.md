---
icon: desktop-arrow-down
description: >-
  On this page you will find instructions on how to get started with NoPorts and
  set up secure remote access. Installation guides are also provided for each
  Operating System. Let's get started!
---

# Installation

## Installation Overview

To complete an installation of NoPorts and set up remote access from a client to a remote device, we must perform an installation on both the client and device machines. We will also obtain two atSigns during registration: one client atSign and one device atSign. Once we have the client and device atSigns, we are ready to begin installation.

1. [Obtain your NoPorts license](./#id-1.-obtain-your-license) from [noports.com](https://my.noports.com/no-ports-plans)\
   &#xNAN;_&#x59;ou can start with a 30-day evaluation license, no credit-card required_
2. [Install NoPorts](./#id-2.-install-noports) software on your devices
   1. Install the NoPorts client\
      &#xNAN;_&#x74;ypically on your desktop_
      1. Activate both management keys on your desktop
   2. Install the NoPorts daemon\
      &#xNAN;_&#x6F;nto the device(s) you want to connect to, repeat for each device_
      1. Use our enrollment tool to activate your device
3. Use NoPorts!
4. Reach out to us\
   We want to hear about your use-cases. We take all feedback into consideration, it helps us make the best tool we possibly can.

The Client is defined as the machine where we are launching the remote access from. The Device is defined as the remote device that we are connecting to.

* Client installation has two options: Desktop App or CLI
* Device installation is CLI only

In summary, Installing and using NoPorts consists of the following steps:

1. Obtain NoPorts License and atSigns
2. Install the NoPorts Client on the client machine
   1. Register the client atSign
   2. Register device atSign
3. Install the NoPorts Daemon on the remote device
   1. Repeat for multiple devices

Once NoPorts is installed you will be able to utilize it for any TCP connections such as remote access via SSH and RDP etc! Please see the complete instructions below:

## 1. Obtain NoPorts License and atSigns

To begin, you will need a NoPorts subscription or Free Trial

1. [Purchase NoPorts](https://my.noports.com/no-ports-plans)
2. Or, [Activate a Free Trial](https://my.noports.com/no-ports-invite/30dayfreetrial)

{% hint style="info" %}
During registration, you will receive your client and device atSigns. Ensure you make note of them for future reference.
{% endhint %}

## 2. Install the NoPorts Client on the client machine

{% hint style="info" %}
If this is your first time using NoPorts on Mac or Windows, we recommend getting started with the desktop app for client installation.
{% endhint %}

### MacOS: Choose Desktop App or CLI installation for the client

{% content-ref url="macos/desktop.md" %}
[desktop.md](macos/desktop.md)
{% endcontent-ref %}

{% content-ref url="macos/cli-client.md" %}
[cli-client.md](macos/cli-client.md)
{% endcontent-ref %}

### Linux: CLI only

{% content-ref url="linux/cli-client.md" %}
[cli-client.md](linux/cli-client.md)
{% endcontent-ref %}

### Windows: Choose Desktop App or CLI installation for the client&#x20;

{% content-ref url="windows/desktop.md" %}
[desktop.md](windows/desktop.md)
{% endcontent-ref %}

{% content-ref url="windows/cli-client.md" %}
[cli-client.md](windows/cli-client.md)
{% endcontent-ref %}

## 3. Install the NoPorts Daemon on the remote device

### MacOS

{% content-ref url="macos/device.md" %}
[device.md](macos/device.md)
{% endcontent-ref %}

### Linux:

{% content-ref url="linux/device.md" %}
[device.md](linux/device.md)
{% endcontent-ref %}

### Windows:

{% content-ref url="windows/device.md" %}
[device.md](windows/device.md)
{% endcontent-ref %}

#### This concludes the installation instructions and you are now ready to use NoPorts for secure remote access!

## Use NoPorts

Start by exploring the use-cases available in the side bar such as SSH, RDP, SFTP, Web Server, and SMB. We also provide in-depth usage information here:

{% content-ref url="../usage/" %}
[usage](../usage/)
{% endcontent-ref %}

## Other Installation Guides:

We have additional installation guides below if you are looking for more advanced/custom installations, or installing NoPorts as part of creating a new virtual machine.

### Manual Installation Guides

These are supplementary guides, which involve some manual work.

{% content-ref url="advanced-installation-guides/" %}
[advanced-installation-guides](advanced-installation-guides/)
{% endcontent-ref %}

{% content-ref url="custom-os-device-installs/ipfire.md" %}
[ipfire.md](custom-os-device-installs/ipfire.md)
{% endcontent-ref %}

### Cloud Installation Guides

These guides will show you how to install NoPorts as part of creating a new VM.

{% content-ref url="cloud-installation-guides/automated-installation-on-amazon-web-services-aws.md" %}
[automated-installation-on-amazon-web-services-aws.md](cloud-installation-guides/automated-installation-on-amazon-web-services-aws.md)
{% endcontent-ref %}

{% content-ref url="cloud-installation-guides/automated-installation-on-google-cloud-platform-gcp.md" %}
[automated-installation-on-google-cloud-platform-gcp.md](cloud-installation-guides/automated-installation-on-google-cloud-platform-gcp.md)
{% endcontent-ref %}

{% content-ref url="cloud-installation-guides/automated-installation-on-microsoft-azure.md" %}
[automated-installation-on-microsoft-azure.md](cloud-installation-guides/automated-installation-on-microsoft-azure.md)
{% endcontent-ref %}

{% content-ref url="cloud-installation-guides/automated-installation-on-oracle-cloud-infrastructure-oci.md" %}
[automated-installation-on-oracle-cloud-infrastructure-oci.md](cloud-installation-guides/automated-installation-on-oracle-cloud-infrastructure-oci.md)
{% endcontent-ref %}

