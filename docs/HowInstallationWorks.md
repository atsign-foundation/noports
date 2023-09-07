# How Installation Works

Installation spec for sshnp and sshnpd.

Note: throughout this document anywhere referred to as the daemon side is where
sshnpd is installed, and anywhere referred to as the client side is where sshnp
is installed.

- [How Installation Works](#how-installation-works)
  - [Shared](#shared)
    - [Directories](#directories)
      - [sshnp (~/.sshnp)](#sshnp-sshnp)
      - [sshnp config (~/.sshnp/config)](#sshnp-config-sshnpconfig)
      - [sshnpd (~/.sshnpd)](#sshnpd-sshnpd)
      - [temp (~/.atsign/temp)](#temp-atsigntemp)
      - [keys (~/.atsign/keys)](#keys-atsignkeys)
      - [local bin (~/.local/bin)](#local-bin-localbin)
    - [Release Format](#release-format)
    - [Sourcing binaries](#sourcing-binaries)
    - [Putting binaries in place](#putting-binaries-in-place)
      - [Custom binaries and templates](#custom-binaries-and-templates)
      - [Custom services and templates](#custom-services-and-templates)
  - [SSHNP (client) Specific](#sshnp-client-specific)
    - [Config Files](#config-files)
  - [SSHNPD (daemon) Specific](#sshnpd-daemon-specific)
    - [Daemon background service/startup](#daemon-background-servicestartup)
      - [Installation methods](#installation-methods)
        - [tmux Installation](#tmux-installation)
        - [cron Installation](#cron-installation)
      - [Restarting the daemon](#restarting-the-daemon)
      - [Killing the daemon](#killing-the-daemon)
    - [Running sshnpd in Docker](#running-sshnpd-in-docker)
      - [sshnpd image](#sshnpd-image)
      - [activate\_sshnpd image](#activate_sshnpd-image)
      - [docker compose orchestration](#docker-compose-orchestration)
        - [Local build images](#local-build-images)
        - [Dockerhub published images](#dockerhub-published-images)

## Shared

### Directories

Each of the following directories in this document are significant and have
their own "nickname" used to reference them.

#### sshnp (~/.sshnp)

For both the client and daemon, this directory contains the local storage
required to run the atClient used by sshnp and sshnpd, each subdirectory in this
directory is named after the atSign for the particular atClient. For the client
side, there is another layer of subdirectories which indexes the storage for
each session created.

On the daemon side, the storage will be contained at ~/.sshnp/storage.
On the client side, the storage will be contained at ~/.sshnp/\<client-id\>/storage

#### sshnp config (~/.sshnp/config)

Standard directory which contains the config files for sshnp (used by the GUI).

#### sshnpd (~/.sshnpd)

Stores non-atClient storage for the daemon side, including:
- logs
- service list file (.service_list)

#### temp (~/.atsign/temp)

A temporary folder used for downloading necessary assets used during the installation process.

#### keys (~/.atsign/keys)

Standard directory which stores the private encryption keys used for the atClient.

#### local bin (~/.local/bin)

Local directory which contains the built binaries and custom scripts.

### Release Format

Releases are contained in a zip file on macOS and tgz on linux.
macOS releases have all binaries notarized.

Binaries included in the release:
- at_activate
- sshnp
- sshnpd
- sshrv
- sshrvd

```
archive root
├── LICENSE
├── <binaries>
└── templates
    └── ...
```

### Sourcing binaries

Both of the sshnp and sshnpd installers source their binaries similarly. By
default they both will download to the temp directory. With sshnpd generating a
subfolder within to download to (i.e. ~/.atsign/temp/unique-subfolder).

The options `-r` and `-l` alter the default source behaviour. `-r` or
`--repo` accepts the root of the repo to be passed in, and instead the installer
will build the binaries from source (still placing them into the temp folder).

`-l` or `--local` accepts a path to a release archive which is then
unarchived by the installer and used to source the binaries. The installer
expects that the archive file matches the release format mentioned above.

### Putting binaries in place

Binaries are simply copied from the temp directory over to the local bin
(~/.local/bin) directory. It's recommended that this directory is included in
the PATH.

#### Custom binaries and templates

A custom binary with the name `sshnp@<device atSign>` is added to the local bin. This custom binary is a bash wrapper around the main sshnp binary, this custom script prepopulates the device atSign and host.

Arguments passed to this script will be passed down to the sshnp binary, duplicate arguments such as host or device atSign will be overridden by the values passed to the script.

#### Custom services and templates

Similar to the custom binaries for sshnp, there are custom services for sshnpd
that get added to the local bin at install time. These scripts follow the name
format of `sshnpd@<client atSign>`.

This script is meant to be run in the background, so in most environments it's
difficult to pass arguments to it. To solve this issue, the script contains a
number of variable definitions for the required arguments, as well as a catch
all variable `ARGS`.

To set the arguments at install time, pass `--args` with the additional args to
pass. If you want to reconfigure, simply reinstall and pass the new arguments.

Recommended args to pass: `--args "-s -u -v"`

## SSHNP (client) Specific

### Config Files

Config files are a relatively new addition, the standard folder is the sshnp
config folder (~/.sshnp/config), but this is subject to change for sandboxed
GUI applications (currently in development).

A template config file can be found in the `templates/config` folder. The
config file uses the same arguments as the sshnp program, however they are
converted to a bash name (Uppercase & replace "-" with "_"). Template config
files use the .env file extension, and should be named uniquely with a profile
name. The file name will be used in GUI applications as the profile name, the
only difference is that where the file name contains "_", the UI will use spaces
instead.

Examples:
```
~/.sshnp/config/playpen.env = "playpen" profile
~/.sshnp/config/My_Custom_Profile.env = "My Custom Profile" profile
```

## SSHNPD (daemon) Specific

### Daemon background service/startup

#### Installation methods

There are currently two ways that the background daemon is installed:
- tmux
- cron

When the background daemon is installed, an entry is added to the service list file with the installation method, and name of the custom service script.

##### tmux Installation

If tmux is installed, the daemon will automatically be installed in tmux session
with the same name as the created custom service: `sshnpd@<client atSign>`. The
tmux session will automatically run the custom script in the background,
automatically restarting the sshnpd process whenever it crashes.

A cron reboot service is automatically installed which restarts the tmux session
on reboot of the machine.

##### cron Installation

If tmux is not installed it will use the "cron" installation which relies on the following dependencies:
- cron - used to schedule the background process
- logrotate - used to rotate the log files created by the background process
- nohup - used to run the service in the background

#### Restarting the daemon

To restart the daemon, the easiest way is to kill all sshnpd instances. The
command used by the installer to do this after an update looks similar to this:

```sh
killall -u "$USER" -r "sshnpd$"
```

Note that this will restart all sshnpd daemons for the current user, to truly
target a particular instance, you will have to trace the child process from the
custom background script (`sshnpd@<client atSign>`).

#### Killing the daemon

To restart the daemon, the easiest way is to kill all custom script processes.
The command used by the installer looks similar to this:

```sh
killall -u "$USER" -r "sshnpd$CLIENT_ATSIGN$"
```

Where CLIENT_ATSIGN is a complete atSign (including the "@" prefix)

### Running sshnpd in Docker

Under the docker templates folder (templates/docker), two Dockerfiles along with
associated docker-compose files are located.

- Dockerfile generates the sshnpd image.
- Dockerfile.activate generates the activate_sshnpd image.

#### sshnpd image

This is the main sshnpd image intended to be used in a docker environment.
It can be found on [dockerhub](https://hub.docker.com/r/atsigncompany/sshnpd),
but can also be built from source, we recommend using
[docker compose to run a container](#docker-compose-orchestration).

#### activate_sshnpd image

This is imageis used to activate new atSigns to be used in an sshnpd container.
It will soon be found on
[dockerhub](https://hub.docker.com/r/atsigncompany/activate_sshnpd),
but can also be built from source, we recommend using
[docker compose to run a container](#docker-compose-orchestration).

#### docker compose orchestration

Alongside the two docker-compose files is a .env.template, which can be copied
to a .env file to specify the arguments for the environment.

##### Local build images

This configuration will (by default) mount the keys directory of the containers
to your local keys directory. When you run the containers, if the atSign hasn't
been activated, the container will expect a valid TO_CRAM which can be retrieved
on [your dashboard](https://my.noports.com/). If the atSign is already
activated, this container will do nothing and exit, so make sure your .atKeys
file is properly mounted in this case.

Then the sshnpd container will startup and run with the settings specified in
the .env file (these parameters are identical to the ones used by config files
with the exception of TO_CRAM).

To customize the sshnpd arguments, modify the "command" for the sshnpd container
in the docker compose file services.

##### Dockerhub published images

This configuration will create a new local mount for the keys directory of the
containers When you run the containers, if the atSign hasn't been activated, the
container will expect a valid TO_CRAM which can be retrieved on
[your dashboard](https://my.noports.com/). If the atSign is already activated,
this container will do nothing and exit, so make sure your .atKeys file is
properly mounted in this case.

Then the sshnpd container will startup and run with the settings specified in
the .env file (these parameters are identical to the ones used by config files
with the exception of TO_CRAM).

To customize the sshnpd arguments, modify the "command" for the sshnpd container
in the docker compose file services.
