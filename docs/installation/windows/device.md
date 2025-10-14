# Windows Device Installation

### Step 1: Download the Installer

Download the installer [from GitHub](https://github.com/atsign-foundation/noports/releases/download/v5.8.7/NoPortsInstaller-windows-x64.zip). Then unzip the file.

### Step 2: Activate your client Atsign

{% hint style="warning" %}
If you've activated your **client** atSign on another device already, this step will not work. Instead, follow this guide: [reuse-your-client-atsign-on-another-machine](../../installation-faq/reuse-your-client-atsign-on-another-machine/ "mention")
{% endhint %}

#### Step 2.1 Open the Windows installer and click "Activate atSign"

<figure><img src="../../.gitbook/assets/CleanShot 2025-01-20 at 16.48.11@2x.png" alt=""><figcaption></figcaption></figure>

#### Step 2.2 Enter the atSign you wish to activate and click "Submit"

<figure><img src="../../.gitbook/assets/CleanShot 2025-01-20 at 18.42.07@2x.png" alt=""><figcaption></figcaption></figure>

#### Step 2.3 Wait for the OTP (One time pincode) then enter it and press "Generate"

<figure><img src="../../.gitbook/assets/CleanShot 2025-01-20 at 18.42.40@2x.png" alt=""><figcaption></figcaption></figure>

#### Step 2.4 Wait for the keys to generate, then go home

### Step 3: Install the Device Software

#### 3.1 Click "Device Install"

<figure><img src="../../.gitbook/assets/CleanShot 2025-01-20 at 17.46.42@2x.png" alt=""><figcaption></figcaption></figure>

#### 3.2 Enter both of your atSigns into the associated fields, then pick a device name, and click "Next"

<figure><img src="../../.gitbook/assets/CleanShot 2025-01-20 at 17.50.56@2x.png" alt=""><figcaption></figcaption></figure>

#### 3.3 If you wish to add additional arguments to pass sshnpd enter them, then click "Next"

<figure><img src="../../.gitbook/assets/CleanShot 2025-01-20 at 17.51.22@2x.png" alt=""><figcaption></figcaption></figure>

#### 3.4 Wait for the installation to complete, then click "Next", and continue through the rest of the installation. Once installation has completed, it will look like this:

<figure><img src="../../.gitbook/assets/CleanShot 2025-01-20 at 18.46.29@2x.png" alt=""><figcaption></figcaption></figure>

## FAQ

### How does the Windows Service work?

We use a lightweight wrapper service to run sshnpd. It pulls the arguments from the Windows Registry and executes sshnpd with them.

### How do I start or stop the service?

Open services.msc (appears as "services" from the start menu). The service will be called `sshnpd` with description `NoPorts-SSH-Daemon` . Click on the service and you will be provided with options to start/restart/stop the service depending on it's current status.

### How do I modify my configuration?

Open the registry editor (a.k.a. regedit) and navigate to `Computer\HKEY_LOCAL_MACHINE\SOFTWARE\NoPorts` . The `DeviceArgs` entry will contain all of the arguments that get passed directly into sshnpd. You may modify these accordingly, then [restart the service](device.md#how-do-i-start-or-stop-the-service).
