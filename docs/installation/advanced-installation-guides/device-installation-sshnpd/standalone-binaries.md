# Standalone Binaries

### 1. Run the installer

{% tabs %}
{% tab title="Linux" %}
1. Change directories into the unpacked download:

```sh
cd sshnp
```

2. Then run the installer:

```sh
./install.sh sshnpd
```

This will install the binaries to `~/.local/bin`.\
Instead, if you'd like to install the binaries to `/usr/local/bin`, run the installer as root:

```sh
sudo ./install.sh sshnpd
```
{% endtab %}

{% tab title="macOS" %}
1. Change directories into the unpacked download:

```sh
cd sshnp
```

2. Then run the installer:

```sh
./install.sh sshnpd
```

This will install the binaries to `~/.local/bin`.\
Instead, if you'd like to install the binaries to `/usr/local/bin`, run the installer as root:

```sh
sudo ./install.sh sshnpd
```
{% endtab %}
{% endtabs %}

## 2. Setup the installer

You are on your own for setting up the background service to start sshnpd. See our other options if you need help setting this up.

## 3. All Done!

You can now proceed to [installing your client](../client-installation-sshnp.md), or if you've already done that, checkout our [usage guide](../../../usage/basic-usage-1/).
