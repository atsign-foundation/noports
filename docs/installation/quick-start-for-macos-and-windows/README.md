---
description: How to quickly install and try NoPorts on both MacOS and Windows devices.
icon: forward
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

# Quick Start from macOS or Windows

This guide is intended for people connecting from a machine running Windows or macOS.

{% hint style="info" %}
For people connecting from Linux please follow the [Linux Installation Guide](../connecting-from-linux/).
{% endhint %}

### <mark style="color:orange;">Step 1:</mark> Sign up for NoPorts or log into the NoPorts Management Portal

If you have not already signed up or purchased NoPorts, go to [my.noports.com](https://my.noports.com/no-ports-invite/30dayfreetrial) and sign up for a subscription or free trial then proceed to **Step 2**.\
\
If you already have a NoPorts account, you’ll need to start by logging into the Management Portal. Go to [my.noports.com/login](https://my.noports.com/login) and enter your registered email address to receive your one‑time password. Once logged in, select the subscription for the Atsigns you want to activate, then continue with the instructions below.&#x20;

{% hint style="info" %}
Make note of your atSigns (e.g., @example01\_np, @example02\_np). You'll need them shortly.
{% endhint %}

### <mark style="color:orange;">Step 2:</mark> Initiate Atsign activation in the Management Portal&#x20;

1. Click **Activate All** and wait for the activation file to be generated.&#x20;
2. Once its completed, download the activation file. It should look something like youratsigns\_activation\_file.yaml.

### <mark style="color:orange;">Step 3:</mark> Download the NoPorts desktop application

Download the NoPorts desktop app using one of the links below:

[Link to Apple Store](https://apps.apple.com/ca/app/noports-desktop/id6737338881)

[Link to Windows Store](https://apps.microsoft.com/detail/9n69scrrgv6r)

{% hint style="info" %}
For people connecting from Linux please follow the [Linux Installation Guide](../connecting-from-linux/).
{% endhint %}

### <mark style="color:orange;">Step 4:</mark> Complete Atsign activation in the NoPorts desktop application

{% hint style="warning" %}
In this installation guide, `@example01_np` will represent the client atSign, while `@example02_np` will represent the device atSign.
{% endhint %}

1. Launch the NoPorts desktop application and click **Get Started** and then click **Complete Activation**
2. Upload or drag and drop you activation file (.yaml) and then click **Next**.

{% hint style="info" %}
If you don’t have an activation file, you can activate your Atsigns individually by entering each one in the Manual Atsign section and following the steps provided in the app.
{% endhint %}

{% hint style="danger" %}
For Windows, if the app stalls at "Preparing for activation", verify that your CA certificates are up to date.
{% endhint %}

### <mark style="color:orange;">Step 4:</mark> Save your atKeys

Your atKeys (cryptographic keys) will be used to pair your Atsign with this and other devices in future. You can [learn more about these keys here](https://www.youtube.com/watch?v=bRRLCOHP-BY).

1. Click on **Save atKeys**
2. Select a memorable location on your machine and **save** your keys.&#x20;

All your Atsigns will be activated and the keys will be saved in your chosen location.&#x20;

### <mark style="color:orange;">Step 5:</mark> Generate a device atSign authorization passcode

Once the activation process is complete you will be signed in using one of your activated Atsigns. This will be your device Atsign, e.g. @example02\_np.&#x20;

Click on **Authenticator** at the top of the screen and then click on **OTP.** Take note of the 6-character code as you will use it in **Step 8**.

### <mark style="color:orange;">Step 6:</mark> Switch to the machine you are connecting to OR use a demo profile to access our test page

Now that your Atsigns are ready, you can either set up your remote machine or try our hidden test page.

* **Remote machine setup:** Install NoPorts on the remote machine, authorize Atsign access to the remote machine and create a connection profile in the desktop app (about 10 minutes).
* **Test page:** Try our demo profile to access our hidden test page if you don't have a machine to connect to.

**Remote Machine Setup**\
Please select the operating system running on the machine you are connecting to and follow the relevant instructions on that machine:

<table data-view="cards"><thead><tr><th></th><th data-hidden data-card-target data-type="content-ref"></th><th data-hidden data-card-cover data-type="image">Cover image</th></tr></thead><tbody><tr><td><strong>macOS</strong></td><td><a href="to-macos.md">to-macos.md</a></td><td><a href="../../.gitbook/assets/Maclogo.png">Maclogo.png</a></td></tr><tr><td><strong>Linux</strong></td><td><a href="to-linux.md">to-linux.md</a></td><td><a href="../../.gitbook/assets/Linuxlogo.png">Linuxlogo.png</a></td></tr><tr><td><strong>Windows</strong></td><td><a href="to-windows.md">to-windows.md</a></td><td><a href="../../.gitbook/assets/Windowslogo.png">Windowslogo.png</a></td></tr></tbody></table>

**OR Test Page**

1. In the NoPorts desktop application, on the Connections tab, you'll see a banner saying "Demo. Click here to load the test profile." Click **Try Now.**
2. Once the profile has been added to your list, click the **Connect Icon ▶️** to establish a connection.
3. Open a web browser and navigate to`http://localhost:8080`.

Congratulations! You're connected to a hidden webpage via NoPorts!&#x20;
