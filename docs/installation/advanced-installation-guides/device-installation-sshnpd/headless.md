# Headless

## 1. Run the installer

{% hint style="warning" %}
It is important to note that the log files of the headless job have the potential to grow infinitely. We recommend implementing a logrotate cron job to prevent this.
{% endhint %}

{% tabs %}
{% tab title="Linux" %}
1. Change directories into the unpacked download:

```sh
cd sshnp
```

2. Then run the installer:

```sh
./install.sh headless sshnpd
```

This will install the binaries to `~/.local/bin`.\
Instead, if you'd like to install the binaries to `/usr/local/bin`, run the installer as root:

```sh
sudo ./install.sh headless sshnpd
```
{% endtab %}

{% tab title="macOS" %}
1. Change directories into the unpacked download:

```sh
cd sshnp
```

2. Then run the installer:

```sh
./install.sh headless sshnpd
```

This will install the binaries to `~/.local/bin`.\
Instead, if you'd like to install the binaries to `/usr/local/bin`, run the installer as root:

```sh
sudo ./install.sh headless sshnpd
```
{% endtab %}
{% endtabs %}

## 2. Configure the startup script

After installing the startup script, we must configure it.

```bash
vi ~/.local/bin/sshnpd.sh
```

You'll then be greeted with a file that looks like this:

{% @github-files/github-code-block url="https://github.com/atsign-foundation/noports/blob/trunk/packages/dart/sshnoports/bundles/shell/headless/sshnpd.sh" %}

Replace `$user` with the [linux user ](#user-content-fn-1)[^1]running sshnpd

Replace `$device_atsign` with the [device address](#user-content-fn-2)[^2]

Replace `$manager_atsign` with the [client address](#user-content-fn-3)[^3]

Replace `$device_name` with your own [custom \*\*unique \*\* identifier](#user-content-fn-4)[^4] for this device. You will need this value later, so don't forget it.

{% hint style="info" %}
`$device_name` must be alphanumeric snake case, max length 30 - e.g. dev\_abc1
{% endhint %}

Add any additional config to the end of the line where sshnpd is run, some useful flags you should consider adding:

* `-u` : "unhide" the device, sharing the username and making it discoverable by `sshnp --list-devices`
* `-s` : "ssh-public-key", allow ssh public keys to be shared by sshnp and automatically authorized by sshd, saves you from dealing with ssh public key management. If multiple people use the device, we recommend leaving this off and managing ssh public keys yourself.
* To see the rest of the available options run sshnpd to see the usage.

{% hint style="warning" %}
This service does not do log rotations of the logs stored at `$HOME/.sshnpd/logs`.

It is recommended that you implement a cron job which handles log rotations.
{% endhint %}

## 3. Activate your device address

{% hint style="danger" %}
If you don't own a pair of noports addresses, please visit [the registrar](https://my.noports.com/no-ports-invite/14dayfreetrial) before continuing.
{% endhint %}

### 3.a. First time activating your address

We will now activate the device address, you only need to activate the device address now. The client address will be activated later during the client installation.

{% tabs %}
{% tab title="Linux" %}
Now that you have at\_activate installed, you can invoke the command with the name of the address you would like to activate:

<pre class="language-bash"><code class="lang-bash"><strong>./at_activate -a @my_noports_device
</strong></code></pre>
{% endtab %}

{% tab title="macOS" %}
Now that you have at\_activate installed, you can invoke the command with the name of the address you would like to activate:

```bash
./at_activate -a @my_noports_device
```
{% endtab %}
{% endtabs %}

### Enter the One Time Password (OTP) & Check your SPAM/PROMOTIONS folders

The application will pause and wait for the input of a one time pin (OTP) before you can continue. You should receive this pin to the contact information associated with the registration of your noports address (i.e. email or text message).

\*\*\*If you are using a gmail.com account we have seen that sometimes the OTP gets stuck in the SPAM or PROMOTIONS folder. If you do not see the OTP check those folders.

Once you receive the message, enter the pin into the application and press enter to continue. The application should proceed to create the cryptographic keys and store them at [`~/.atsign/keys/<address_name>_key.atKeys`](#user-content-fn-5)[^5].

An address can only be activated once, to install this address to future devices, you must copy this file to the device (see 3.b.).

### 3.b. Activated this address before

{% hint style="warning" %}
If you have activated the device address before, you must copy the address from another machine where it's been activated.
{% endhint %}

The address will be located at [`~/.atsign/keys/<address_name>_key.atKeys`](#user-content-fn-6)[^6]. Copy this file from your other machine to the same location on the machine that you are installing sshnpd on.

## 4. Start the service

The headless service will automatically be started by the `cron @reboot` directive when your machine restarts. If you would like to start it immediately, note that you must make sure to disown the process so that it doesn't hangup when you logout.

Run the following command to start it immediately:

```bash
nohup $HOME/.local/bin/sshnpd.sh > $HOME/.sshnpd/logs/sshnpd.log 2> $HOME/.sshnpd/logs/sshnpd.err &
```

### Observing the service

The service should already be running in the background, to observe the logs:

```bash
tail -f $HOME/.sshnpd/logs/sshnpd.log
tail -f $HOME/.sshnpd/logs/sshnpd.err
```

{% hint style="info" %}
Most of the logs will be found in `sshnpd.err`, it is usually worth checking that file first
{% endhint %}

## 5. All done!

Your headless job is ready to go, you can now proceed to [installing your client](../client-installation-sshnp.md), or if you've already done that, checkout our [usage guide](../../../usage/basic-usage-1/).

[^1]: If you aren't sure, type "echo $USER" in your terminal.

[^2]: e.g. @alice\_device

[^3]: e.g. @alice\_client

[^4]: This device name is how you distinguish between all of the devices you have running sshnpd.

[^5]: where `<address_name>` is the name of your device address e.g. `@alice_device`

[^6]: where `<address_name>` is the name of your device address e.g. `@alice_device`
