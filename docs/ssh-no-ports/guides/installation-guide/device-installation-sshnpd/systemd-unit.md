# Systemd Unit

## 1. Run the installer

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
{% endtab %}

{% tab title="macOS" %}
Not available for macOS
{% endtab %}
{% endtabs %}

## 2. Configure the service file

After installing the systemd unit, we must configure it. This requires root privileges.

```bash
sudo vi /etc/systemd/system/sshnpd.service
```

You'll then be greeted with a file that looks like this:

{% @github-files/github-code-block url="https://github.com/atsign-foundation/noports/blob/trunk/packages/dart/sshnoports/bundles/shell/systemd/sshnpd.service" %}

Replace `<username>` with the [linux user ](#user-content-fn-1)[^1]running sshnpd

Replace `<@device_atsign>` with the [device address](#user-content-fn-2)[^2]

Replace `<@manager_atsign>` with the [client address](#user-content-fn-3)[^3]

Replace `<device_name>` with your own [custom **unique** identifier](#user-content-fn-4)[^4] for this device, you will need this value later so don't forget it.

Add any additional config to the end of the line where sshnpd is run, some useful flags you should consider adding:

* `-u` : "unhide" the device, sharing the username and making it discoverable by `sshnp --list-devices`
* `-s` : "ssh-public-key", allow ssh public keys to be shared by sshnp and automatically authorized by sshd, saves you from dealing with ssh public key management. If multiple people use the device, we recommend leaving this off and managing ssh public keys yourself.
* To see the rest of the available options run sshnpd to see the usage.

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

#### Enter the OTP

The application will pause and wait for the input of a one time pin (OTP) before you can continue. You should receive this pin to the contact information associated with the registration of your noports address (i.e. email or text message).

Once you receive the message, enter the pin into the application and press enter to continue. The application should proceed to create the cryptographic keys and store them at `~/.atsign/keys/@my_noports_device_key.atKeys`.

An address can only be activated once, to install this address to future devices, you must copy this file to the device (see 3.b.).

### 3.b. Activated this address before

{% hint style="warning" %}
If you have activated the device address before, you must copy the address from another machine where it's been activated.&#x20;
{% endhint %}

The address will be located at `~/.atsign/keys/@my_noports_device_key.atKeys`. Copy this file from your other machine to the same location on the machine that you are installing sshnpd on.

## 4. Enable the service

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

## 5. All done!

Your systemd service is ready to go, you can now proceed to [installing your client](../client-installation-sshnp.md), or if you've already done that, checkout our [usage guide](../../usage-guide/basic-usage/).

[^1]: If you aren't sure, type "echo $USER" in your terminal.

[^2]: e.g. @alice\_device

[^3]: e.g. @alice\_client

[^4]: This device name is how you distinguish between all of the devices you have running sshnpd.
