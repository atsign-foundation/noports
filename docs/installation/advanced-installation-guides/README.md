---
description: The universal.sh installer does a lot, but you may want to have more control
icon: wrench
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

# Installation Explained

### Linux packages

NoPorts is packaged in a .deb for Debian based systems such as Kali, Mint, Raspberry Pi OS (previously Raspbian) and Ubuntu; and in .rpm for Red Hat based systems such as Alma Linux, Amazon Linux, CentOS, Fedora, Red Hat Enterprise Linux (RHEL) and Rocky Linux.

`universal.sh` checks whether it's being run on a distro that supports those packages, and installs from the appropriate package manager.

Once these packages are installed they will be automatically upgraded alongside other packages on the system (e.g. when you run `sudo apt update && sudo apt upgrade -y` or `sudo dnf update`)

If you'd like to install the packages yourself then:

#### apt package

**step by step**

First add our public key to your keyring:

```
sudo mkdir -p /usr/share/keyrings
curl -fsSL https://apt.noports.com/noports.pub.asc | \
  sudo gpg --dearmor -o /usr/share/keyrings/noports-archive-keyring.gpg
```

Then add the `apt.noports.com` repo to apt sources:

```
echo "deb [signed-by=/usr/share/keyrings/noports-archive-keyring.gpg] https://apt.noports.com/ stable main" | \
  sudo tee /etc/apt/sources.list.d/noports.list
```

Then update sources and install NoPorts:

```
sudo apt update && sudo apt install -y noports
```

**one liner**

Alternatively those steps can be combined into a single line:

```
sudo mkdir -p /usr/share/keyrings ; curl -fsSL https://apt.noports.com/noports.pub.asc | sudo gpg --dearmor -o /usr/share/keyrings/noports-archive-keyring.gpg ; echo "deb [signed-by=/usr/share/keyrings/noports-archive-keyring.gpg] https://apt.noports.com/ stable main" | sudo tee /etc/apt/sources.list.d/noports.list ; sudo apt update ; sudo apt install -y noports
```

#### rpm package

Create a repository file at `/etc/yum.repos.d/noports.repo`:

```
sudo tee /etc/yum.repos.d/noports.repo <<EOF
[noports]
name=NoPorts Repository
baseurl=https://rpm.noports.com/\$basearch/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://rpm.noports.com/noports.pub.asc
EOF
```

Then install NoPorts:

```
sudo dnf install noports
```

### Mac Homebrew

If `universal.sh` finds the `brew` command it will offer to install from our [Homebrew tap](https://github.com/atsign-foundation/homebrew-tap). If you'd rather do that yourself then:

```
brew tap atsign-foundation/homebrew-tap
brew install noports
```

### No Package Manager

When `universal.sh` doesn't find a supported package manager it will install NoPorts binaries to `/usr/bin` when run as root (with `sudo`) or `$HOME/.local/bin` when not run as root.

That's done by downloading the platform/architecture appropriate archive (`.tgz` or `.zip`) from the [latest NoPorts GitHub release](https://github.com/atsign-foundation/noports/releases/latest), and then unpacking the files into their destination directory.

If you'd rather not use `universal.sh` or one of the packages mentioned above then download an archive directly and unpack it to the destination of your choice.

### Daemon config - /etc/noports/sshnpd.yaml

`univeral.sh` will ask about client and manager addresses and the device name and use those to populate the config file in `/etc/noports/sshnpd.yaml` . That config can be edited and customised to suit more complex use cases. On systemd based systems a unit file will be installed to run the NoPorts daemon. For more details see [systemd unit](device-installation-sshnpd/systemd-unit.md). If systemd isn't present then there are various options for [running without systemd](device-installation-sshnpd/standalone-binaries.md).



{% content-ref url="device-installation-sshnpd/" %}
[device-installation-sshnpd](device-installation-sshnpd/)
{% endcontent-ref %}

{% content-ref url="client-installation-sshnp.md" %}
[client-installation-sshnp.md](client-installation-sshnp.md)
{% endcontent-ref %}
