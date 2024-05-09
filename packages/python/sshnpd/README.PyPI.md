<h1><img width=250px src="https://atsign.com/wp-content/uploads/2022/05/atsign-logo-horizontal-color2022.svg" alt="The Atsign Foundation"></h1>

[![GitHub License](https://img.shields.io/badge/license-BSD3-blue.svg)](./LICENSE)
[![PyPI version](https://badge.fury.io/py/sshnpd.svg)](https://badge.fury.io/py/sshnpd)

# SSHNPD Python (beta)

SSH No Ports provides a way to ssh to a remote linux host/device without that
device or the client having any open ports (not even 22) on external
interfaces. All network connectivity is outbound and there is no need to
know the IP address the device has been given. As long as the device and
client has an IP address (public or private 1918), DNS and Internet access,
you will be able to connect to it.

This version is SSHNP Daemon written in Python, it is still in its beta
stage of developement.

## Prerequisites

SSHNPD Python requires the following:

* Python 3.10 or later on a system where the following packages containing
native code are available[1]:
  * bcrypt
  * cffi
  * charset-normalizer
  * cryptography
* Two atSigns, one for the client and one for the device
  * The device atSign keys file should be placed in ~/.atsign/keys
* An sshd bound to (at least) localhost
  * Port 22 is the assumed default, but can be overridden

[1] A common problem with installation is that native packages for a given
architecture or libc aren't available. Pip will then download the source
and try to compile that, which usually fails because the required toolchain
isn't present.

## Installation

This package can be installed from PyPI with:

```sh
pip install sshnpd
```

Though some systems will need `pip3` rather than `pip`:

```sh
pip3 install sshnpd
```

### Python virtual environments (venv)

Recent Linux distributions such as Debian 12 and derivatives (including
Ubuntu 24.04 and Rapberry Pi OS 'Bookworm') no longer allow the installation
of packages from PyPI into the system Python. It's therefore necessary to
use a virtual environment (venv).

First ensure that pip and the venv module are available:

```sh
sudo apt install -y python3-pip python3-venv
```

Then create and activate a venv:

```sh
python3 -m venv sshnpd
. sshnpd/bin/activate
```

The daemon can then be installed as before:

```sh
pip install sshnpd
```

Just remember to activate the venv first whenever using the daemon.

### Installing from source

Alternatively clone this repo and from the repo root:

```sh
cd packages/python/sshnpd
pip install -r requirements.txt
pip install .
```

## Running the daemon

```sh
sshnpd -m @{clientAtsign} -a @{deviceAtsign} -d {deviceName} -u
```

e.g.

```sh
sshnpd -m @zaphod -a @heartofgold -d eddie -u
```

### Connecting to the daemon

The Python version of SSHNPD presently implements v4 functionality, so it's
a little behind the Dart implementation, and the latest client needs some
flags to ensure compatibility:

```sh
sshnp -f @{clientAtsign} -t @{deviceAtsign} -d {deviceName} \
-r @{rvPoint} -u {user} --no-ad --no-et
```

e.g.

```sh
sshnp -f @zaphod -t @heartofgold -d eddie -r @rv_am -u ubuntu --no-ad --no-et
```
