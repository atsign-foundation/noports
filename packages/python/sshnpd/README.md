<h1><img width=250px src="https://atsign.dev/assets/img/atPlatform_logo_gray.svg?sanitize=true" alt="The atPlatform logo"></h1>

[![GitHub License](https://img.shields.io/badge/license-BSD3-blue.svg)](./LICENSE)

# SSHNPD Python

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

* 2 atsigns, one for the client and one for the device
* any machine with sshd running and python3 installed
* atsdk installed

## Installation

This package can be installed from PyPI with:

```sh
pip install sshnpd
```

Alternatively clone this repo and from the repo root:

```sh
cd packages/python/sshnpd
pip install -r requirements.txt
pip install .
```

## Running the program

```sh
sshnpd -m @{clientAtsign} -a @{deviceAtsign} -d {deviceName}
```
