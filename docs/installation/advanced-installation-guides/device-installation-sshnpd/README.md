---
icon: server
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

# Device Installation

There are three steps to getting a device installed:

### 1. Install binaries

As described in [Installation Explained](../) this can be done using the `universal.sh` install script, installing  from a package manager (e.g. apt or dnf for Linux or brew for MacOS), or simply downloading the binary archive from [GitHub releases](https://github.com/atsign-foundation/noports/releases) and expanding it to your preferred destination.

### 2. Provide config

The NoPorts daemon `sshnpd` will look for config in `/etc/noports/sshnpd.yaml`. The `universal.sh` script will set this up for you in response to prompts, or it can be edited manually.

Config can also be provided in a different file location using the `--config` flag.

Or config options can be passed directly to `sshnpd` using [command line flags](../../../usage/sshnpd-configuration/)

### 3. Provide device atKeys file

The NoPorts address used by a device (say `@exampledevice_np`) is held in a file that defaults to `$HOME/.atsign/keys/@exampledevice_np.atKeys`

The `at_activate` command is used to create the atKeys file.

Usually atKeys on a device are created by performing an enrollment operation `at_activate enroll ...` , but it's also possible to activate an atKey directly on a device using `at_activate ...`
