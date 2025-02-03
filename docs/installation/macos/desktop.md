---
description: Video and written directions for installing the NoPorts desktop app
---

# MacOS Desktop Client Installation

{% embed url="https://vimeo.com/1038239765" %}
NoPorts Desktop Overview
{% endembed %}

{% include "../../.gitbook/includes/get-atsigns-from-reg-warning.md" %}

## Step 1: Download the NoPorts desktop application&#x20;

[Link to Apple Store](https://apps.apple.com/ca/app/noports-desktop/id6737338881)

## Step 2: Log into the NoPorts desktop application

1. Launch the NoPorts desktop app and click 'Get Started'.
2. Enter your client atSign into the text field (e.g., @pluto83\_client), leave the root domain as is, and then click 'Next'.
3. A one-time password (OTP) will be sent to you via email. Enter this OTP into the app and then click 'Confirm'.

## Step 3: Back up your atKeys

Your atKeys (cryptographic keys) will be used to pair your atSign with this and other devices in future. You can [learn more about these keys here](https://docs.noports.com/installation-faq/why-activate-the-device-atsign-on-the-client).

1. Click on the Settings Icon in the top right corner of the app.
2. Click on 'Back Up Your Keys' in the left navigation panel.
3. Select a location on your device and save your keys.

## Step 4: Prepare a Profile to establish a NoPorts connection

1. Return to the Dashboard
2. Click the 'Add New' button to create a new Profile
   1. Enter the details for the new profile
   2. Start the connection by pressing :arrow\_forward: for the profile you just created
3.  **Or,** connect using our test profile.

    1. Download the[ NoPorts test connection profile. ](https://drive.google.com/file/d/1qb0YrpRaGstLSBKoLJ4wwVUIMO5zCaMq/view)This is a json file containing connection details for a test profile we have created.
    2. Return to the NoPorts app Dashboard.
    3. Click 'Import' and select the test connection profile that you just downloaded.
    4. Click the Connect Icon :arrow\_forward: to establish a connection.
    5. Open a web browser and navigate to`http://localhost:8080`to confirm you successfully connected to our hidden webpage.



{% hint style="info" %}
\*Note, if you are connecting to your remote device, the remote device installation must be complete before the profile will connect. If utilizing a test profile, it will connect to our test site without needing a remote device to be set up first.
{% endhint %}
