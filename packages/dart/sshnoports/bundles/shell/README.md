# SSH No Ports Suite

## Installation

To install a member of the SSH No Ports suite, use the `install.sh` script.
View the full usage of the installation script by running:

```sh
./install.sh --help
```

### Common install commands

To install the sshnp client:

```sh
./install.sh sshnp
```

To install the sshnpd daemon using systemd (must be run as root):

```sh
sudo ./install.sh systemd sshnpd
```

To install the sshnpd daemon using a headless cron job:

```sh
./install.sh headless sshnpd
```

To install the sshnpd daemon into a detached tmux session:

```sh
./install.sh tmux sshnpd
```
