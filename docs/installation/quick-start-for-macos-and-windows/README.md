---
description: How to quickly install and try NoPorts on both MacOS and Windows devices.
icon: forward
layout:
  title:
    visible: true
  description:
    visible: true
  tableOfContents:
    visible: true
  outline:
    visible: true
  pagination:
    visible: true
---

# Quick Start from macOS or Windows

This guide is intended for people connecting from a machine running Windows or macOS.

{% hint style="info" %}
For people connecting from Linux please follow the [Linux Installation Guide](../connecting-from-linux/).
{% endhint %}

### <mark style="color:orange;">Step 1:</mark> Sign up for a NoPorts free trial

Go to [noports.com](https://my.noports.com/no-ports-invite/30dayfreetrial) and sign up for a 30-day free trial.&#x20;

{% hint style="info" %}
Make note of your atSigns (e.g., @pluto83\_client). You'll need them shortly.
{% endhint %}

### <mark style="color:orange;">Step 2:</mark> Download the NoPorts desktop application

Download the NoPorts desktop app using one of the links below:

[Link to Apple Store](https://apps.apple.com/ca/app/noports-desktop/id6737338881)

[Link to Windows Store](https://apps.microsoft.com/detail/9n69scrrgv6r)

{% hint style="info" %}
For people connecting from Linux please follow the [Linux Installation Guide](../connecting-from-linux/).
{% endhint %}

### <mark style="color:orange;">Step 3:</mark> Activate your client atSign

1. Launch the NoPorts desktop app and click **Get Started**.
2. Enter your **client atSign** into the text field (e.g., @pluto83\_client), leave the root domain as is, and then click **Next**.
3. A **one-time password (OTP)** will be sent to you via email. Enter this OTP into the app and then click **Confirm**.&#x20;

{% hint style="info" %}
For Windows, if the app stalls at "Preparing for activation", verify that your CA certificates are up to date.
{% endhint %}

### <mark style="color:orange;">Step 4:</mark> Save a copy of your client atKeys

Your atKeys (cryptographic keys) will be used to pair your atSign with this and other devices in future. You can [learn more about these keys here](https://www.youtube.com/watch?v=bRRLCOHP-BY).

1. Click on **Save atKeys**
2. Select a memorable location on your machine and **save** your keys. We recommend creating a folder in your home drive called `~/.atsign/keys` and storing your keys there.

### <mark style="color:orange;">Step 5:</mark> Establish a connection&#x20;

**Connect to your own remote machine**

Please select the operating system running on the machine you are connecting to:

<table data-view="cards"><thead><tr><th></th><th data-hidden data-card-target data-type="content-ref"></th></tr></thead><tbody><tr><td>macOS</td><td><a href="to-macos.md">to-macos.md</a></td></tr><tr><td>Linux</td><td><a href="../connecting-from-macos/macos-to-linux.md">macos-to-linux.md</a></td></tr><tr><td>Windows</td><td><a href="to-windows.md">to-windows.md</a></td></tr></tbody></table>

**Or set up a test connection to our hidden trial page**&#x20;

1. Download the[ NoPorts test connection profile. ](https://drive.google.com/file/d/1qb0YrpRaGstLSBKoLJ4wwVUIMO5zCaMq/view)This is a json file containing connection details for a test profile we have created.
2. Return to the NoPorts app **Dashboard**.
3. Click **Import** and select the test connection profile that you just downloaded.
4. Click the **Connect Icon ▶️** to establish a connection.
5. Open a web browser and navigate to`http://localhost:8080`.

Congratulations! You're connected to a hidden webpage via NoPorts!&#x20;
