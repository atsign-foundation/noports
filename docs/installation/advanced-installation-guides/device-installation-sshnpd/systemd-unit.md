---
description: >-
  Follow these five steps to set up the NoPorts daemon as a systemd unit
  background service.
---

# Systemd Unit

### Step 1. Run the installer

{% tabs %}
{% tab title="Linux" %}
1. First, change directories into the unpacked download:

```sh
cd sshnp
```

2. Then run the installer:

```sh
sudo ./install.sh systemd sshnpd
```

This installer must be run as root.

To run sshnpd as another account, such as a service account, name it with `-u` so that the installer sets up that account's `~/.ssh/authorized_keys` (see Step 5):

```sh
sudo ./install.sh -u <username> systemd sshnpd
```
{% endtab %}

{% tab title="macOS" %}
Not available for macOS
{% endtab %}
{% endtabs %}

### Step 2. Configure the service file

After installing the systemd unit, we must configure it. This requires root privileges.

```bash
sudo vi /etc/systemd/system/sshnpd.service
```

You'll then be greeted with a file that looks like this:

{% @github-files/github-code-block url="https://github.com/atsign-foundation/noports/blob/trunk/packages/dart/sshnoports/bundles/shell/systemd/sshnpd.service" %}

Replace `<username>` with the [linux user ](#user-content-fn-1)[^1]running sshnpd (we suggest creating a service account, not running as root, and naming it with `-u` in Step 1)

Replace `<@device_atsign>` with the [device address](#user-content-fn-2)[^2]

Replace `<@manager_atsign>` with the [client address](#user-content-fn-3)[^3]

Replace `<device_name>` with your own [custom \*\*unique \*\* identifier](#user-content-fn-4)[^4] for this device. You will need this value later, so don't forget it.

{% hint style="info" %}
`<device_name>` must be alphanumeric snake case, max length 30 - e.g. dev\_abc1
{% endhint %}

Add any additional config to the end of the line where sshnpd is run, some useful flags you should consider adding:

* `-u` : "unhide" the device, sharing the username and making it discoverable by `sshnp --list-devices`
* `-s` : "ssh-public-key", allow ssh public keys to be shared by sshnp and automatically authorized by sshd, saves you from dealing with ssh public key management. If multiple people use the device, we recommend leaving this off and managing ssh public keys yourself.
* To see the rest of the available options run sshnpd to see the usage.

### Step 3. Activate your device address

{% hint style="danger" %}
If you don't own a pair of noports addresses, please visit [the registrar](https://my.noports.com/no-ports-invite/14dayfreetrial) before continuing.
{% endhint %}

### Step 3.1. First time activating your address

We will now activate the device address—you only need to activate the device address now. The client address will be activated later during the client installation.

{% tabs %}
{% tab title="Linux" %}
Now that you have at\_activate installed, you can invoke the command with the name of the address you would like to activate:

<pre class="language-bash"><code class="lang-bash"><strong>./at_activate onboard -a @my_noports_device
</strong></code></pre>
{% endtab %}

{% tab title="macOS" %}
Now that you have at\_activate installed, you can invoke the command with the name of the address you would like to activate:

```bash
./at_activate onboard -a @my_noports_device
```
{% endtab %}
{% endtabs %}

### Enter the One-Time Password (OTP) & Check your SPAM/PROMOTIONS folders

The application will pause and wait for the input of a one-time password (OTP) before you can continue. You should receive this pin to the contact information associated with the registration of your noports address (i.e. email or text message).

\*\*\*If you are using a gmail.com account we have seen that sometimes the OTP gets stuck in the SPAM or PROMOTIONS folder. If you do not see the OTP check those folders.

Once you receive the message, enter the pin into the application and press **Enter** to continue. The application should proceed to create the cryptographic keys and store them at `~/.atsign/keys/@my_noports_device_key.atKeys`.

An address can only be activated once, to install this address to future devices, you must copy this file to the device (see 3.b.).

### Step 3.1. Activated this address before

{% hint style="warning" %}
If you have activated the device address before, you must copy the address from another machine where it's been activated.
{% endhint %}

The address will be located at `~/.atsign/keys/@my_noports_device_key.atKeys`. Copy this file from your other machine to the same location on the machine that you are installing sshnpd on.

### Step 4. Enable the service

Using `systemctl` we can enable and start the sshnpd service.

```bash
sudo systemctl enable sshnpd.service
sudo systemctl start sshnpd.service
```

### Observing the service

If you need to verify the status of the service:

```bash
sudo systemctl status sshnpd.service
```

If you want to follow the logs of the service you can with

```bash
sudo journalctl -u sshnpd.service -f
```

### Step 5. Check your environment.

There are a number of fiddly things to get in place for ssh to work. The first is the `~/.ssh/authorized_keys`file of the user being used to run the systemd unit.

The installer sets up `~/.ssh/authorized_keys` for the user who ran `sudo ./install.sh systemd sshnpd`, or for the account named with `-u`. It runs these steps as that user, creating the file if it is missing, so that user owns it, and it sets the file's mode to 644 (`-rw-r--r--`). If it cannot, it stops with an error that gives the commands to make that user the owner of its `~/.ssh`.

The file needs to be owned by the user running the systemd unit, and writable only by that owner, else `sshd` will not allow logins. Check it with `ls -l`. If it is owned by someone else, correct it with `chown`, substituting `debian` for your username and group, and correct its mode with `chmod`.

```bash
debian@beaglebone:~$ ls -l ~/.ssh/
total 0
-rw-r--r-- 1 root root 0 Feb 18 00:28 authorized_keys
debian@beaglebone:~$ sudo chown debian:debian ~/.ssh/authorized_keys
debian@beaglebone:~$ ls -l ~/.ssh/
total 0
-rw-r--r-- 1 debian debian 0 Feb 18 00:28 authorized_keys
debian@beaglebone:~$ chmod 600 ~/.ssh/authorized_keys
```

Once complete it should look like this.

```
debian@beaglebone:~$ ls -l ~/.ssh/
total 0
-rw------- 1 debian debian 0 Feb 18 00:28 authorized_keys
debian@beaglebone:~$
```

### Running sshnpd at root special steps (not recommended)

If you decided to use the root user in the service setup you have a futher couple of steps.

Run the installer with `-u root` so that it sets up `~root/.ssh/authorized_keys`:

```bash
sudo ./install.sh -u root systemd sshnpd
```

Or create them yourself:

```bash
sudo mkdir -p ~root/.ssh
sudo touch ~root/.ssh/authorized_keys
sudo chmod 600 ~root/.ssh/authorized_keys
```

Then you need to make sure that the root user is allowed to login via sshd. Whist this is not recommended, you can get it working by editing the `/etc/ssh/sshd_config` file and removing the `#` on this line.

```
# PermitRootLogin prohibit-password
```

Once removed, you will need to restart the sshd daemon. How to do this varies from distribution/OS so check on how to do it or reboot.

### Step 6. All Done !

Your systemd service is ready to go. You can now proceed to [installing your client](../client-installation-sshnp.md), or if you've already done that, check out our [usage guide](../../../usage/basic-usage-1/).

[^1]: If you aren't sure, type "echo $USER" in your terminal.

[^2]: e.g. @alice\_device

[^3]: e.g. @alice\_client

[^4]: This device name is how you distinguish between all of the devices you have running sshnpd.
