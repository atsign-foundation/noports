<h1><a href="https://atsign.com#gh-light-mode-only"><img width=250px src="https://atsign.com/wp-content/uploads/2022/05/atsign-logo-horizontal-color2022.svg#gh-light-mode-only" alt="The Atsign Foundation"></a><a href="https://atsign.com#gh-dark-mode-only"><img width=250px src="https://atsign.com/wp-content/uploads/2023/08/atsign-logo-horizontal-reverse2022-Color.svg#gh-dark-mode-only" alt="The Atsign Foundation"></a>

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

## No Ports SDK Python (experimental)

There is a simple python SDK which allows you to create scripts for common
administrative patterns via SSH No Ports.
