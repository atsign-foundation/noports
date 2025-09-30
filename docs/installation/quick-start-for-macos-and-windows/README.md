---
description: How to quickly install and try NoPorts on both MacOS and Windows devices.
icon: forward
---

# Quick Start from macOS or Windows

This guide is intended for people connecting from a machine running Windows or macOS.

{% hint style="info" %}
For people connecting from Linux please follow the [Linux Installation Guide](../connecting-from-linux/).
{% endhint %}

### <mark style="color:orange;">Step 1:</mark> Sign up for a NoPorts free trial

Go to [noports.com](https://my.noports.com/no-ports-invite/30dayfreetrial) and sign up for a subscription or free trial&#x20;

{% hint style="info" %}
Make note of your atSigns (e.g., @example01\_np, @example01\_np). You'll need them shortly.
{% endhint %}

### <mark style="color:orange;">Step 2:</mark> Download the NoPorts desktop application

Download the NoPorts desktop app using one of the links below:

[Link to Apple Store](https://apps.apple.com/ca/app/noports-desktop/id6737338881)

[Link to Windows Store](https://apps.microsoft.com/detail/9n69scrrgv6r)

{% hint style="info" %}
For people connecting from Linux please follow the [Linux Installation Guide](../connecting-from-linux/).
{% endhint %}

### <mark style="color:orange;">Step 3:</mark> Activate your client atSign (@example01\_np)

{% hint style="warning" %}
In this installation guide, `@example01_np` will represent the client atSign, while `@example02_np` will represent the device atSign.
{% endhint %}

1. Launch the NoPorts desktop app and click **Get Started**.
2. Enter your **client atSign** into the text field (e.g., @example01\_np), leave the root domain as is, and then click **Next**.
3. A **one-time password (OTP)** will be sent to you via email. Enter this OTP into the app and then click **Confirm**.&#x20;

{% hint style="info" %}
For Windows, if the app stalls at "Preparing for activation", verify that your CA certificates are up to date.
{% endhint %}

### <mark style="color:orange;">Step 4:</mark> Save a copy of your client atKeys

Your atKeys (cryptographic keys) will be used to pair your atSign with this and other devices in future. You can [learn more about these keys here](https://www.youtube.com/watch?v=bRRLCOHP-BY).

1. Click on **Save atKeys**
2. Select a memorable location on your machine and **save** your keys.&#x20;

### <mark style="color:orange;">Step 5:</mark> Establish a connection&#x20;

{% tabs %}
{% tab title="Connect to your own remote machine" %}
### <mark style="color:orange;">Step 5.1:</mark> Activate your device atSign (@example02\_np)

{% hint style="warning" %}
Both the atSigns are activated on the machine you are connecting from. Later, you’ll grant your remote machine access to the keys stored on this machine.
{% endhint %}

1. You'll need to switch atSigns. To sign out from the client atSign, click the **Settings** icon in the top right corner of the screen, then select **Sign Out**.
2. Click **Get Started** and enter your **device atSign** into the text field (e.g., @example02\_np). Leave the root domain as is, and then click **Next**.
3. A **one-time password (OTP)** will be sent to you via email. Enter this OTP into the app and then click **Confirm**.&#x20;

### <mark style="color:orange;">Step 5.2:</mark> Save a copy of your device atKeys&#x20;

Your atKeys (cryptographic keys) will be used to pair your atSign with this and other devices in future. You can [learn more about these keys here](https://www.youtube.com/watch?v=bRRLCOHP-BY).

1. Click on **Save atKeys**
2. Select a memorable location on your machine and **save** your keys.&#x20;

### <mark style="color:orange;">Step 5.3:</mark> Generate a device atSign authorization passcode

Click on the **key icon** in the top right corner and then click on **OTP.** You will use this 4 character code in **Step 7**.

### <mark style="color:orange;">Step 5.4:</mark> Switch to the machine you are connecting to

Please select the operating system running on the machine you are connecting to and follow the relevant instructions:

<table data-view="cards"><thead><tr><th></th><th data-hidden data-card-target data-type="content-ref"></th></tr></thead><tbody><tr><td><strong>macOS</strong></td><td><a href="to-macos.md">to-macos.md</a></td></tr><tr><td><strong>Linux</strong></td><td><a href="to-linux.md">to-linux.md</a></td></tr><tr><td><strong>Windows</strong></td><td><a href="to-windows.md">to-windows.md</a></td></tr></tbody></table>
{% endtab %}

{% tab title="Set up a test connection to our hidden page " %}
1. Download the[ NoPorts test connection profile. ](https://drive.google.com/file/d/1qb0YrpRaGstLSBKoLJ4wwVUIMO5zCaMq/view)This is a json file containing connection details for a test profile we have created.
2. Return to the NoPorts app **Dashboard**.
3. Click **Import** and select the test connection profile that you just downloaded.
4. Click the **Connect Icon ▶️** to establish a connection.
5. Open a web browser and navigate to`http://localhost:8080`.

Congratulations! You're connected to a hidden webpage via NoPorts!&#x20;
{% endtab %}
{% endtabs %}
