<img width=250px src="https://atsign.dev/assets/img/atPlatform_logo_gray.svg?sanitize=true" alt="The atPlatform logo">

[![GitHub License](https://img.shields.io/badge/license-BSD3-blue.svg)](./LICENSE)


# SSHNPD Python

ssh no ports provides a way to ssh to a remote linux host/device without that
device or the client having any open ports (not even 22) on external interfaces. All
network connectivity is out bound and there is no need to know the IP
address the device has been given. As long as the device and client has an IP address (public or private 1918),
DNS and Internet access, you will be able to connect to it.

This version is SSHNP Daemon written in Python, it is still in it's beta stage of developement.

# Installation

We need to manually install the at_python package as it is not yet available on pypi.

```
1. git clone https://github.com/atsign-foundation/sshnoports.git

2.  cd sshnoports/packages/sshnpdpy
    pip install -r requirements.txt

    *You should do this step outside the repo*
3.  git clone https://github.com/atsign-foundation/at_python.git
    cd at_python
    pip install .
```


# Running the program

```
1. cd packages/sshnpdpy
2. ./sshnpd.py -m @{clientAtsign} -a @{deviceAtsign} -d {deviceName} -u
```


# No Ports SDK Python (experimental)
There is a simple python SDK which allows you to create scripts for common administrative patterns via SSH No Ports. 

