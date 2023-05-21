<img width=250px src="https://atsign.dev/assets/img/atPlatform_logo_gray.svg?sanitize=true" alt="The atPlatform logo">

[![GitHub License](https://img.shields.io/badge/license-BSD3-blue.svg)](./LICENSE)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/atsign-foundation/sshnoports/badge)](https://api.securityscorecards.dev/projects/github.com/atsign-foundation/sshnoports)

# SSH! No ports

ssh no ports provides a way to ssh to a remote linux host/device without that
device or the client having any open ports (not even 22) on external interfaces. All
network connectivity is out bound and there is no need to know the IP
address the device has been given. As long as the device and client has an IP address (public or private 1918),
DNS and Internet access, you will be able to connect to it.

## Quick demo
![sshnp](https://github.com/atsign-foundation/sshnoports/assets/6131216/4ff005f1-230e-4621-9b33-f834caa9a1d1)


There are five binaries:-

`at_activate`  : Command line tool to "cut" your atSigns cryptographic keys an place them in ~/.atsign/keys with .atKeys extension

`sshnpd` : The daemon that runs on the remote device

`sshnp`  : The client that sets up a connection to the device which you
can then ssh to via your localhost interface

`sshrvd` : This daemon acts as a rendezvous service and provides Internet routable IP/Ports for sshnpd and sshrv to connect to

`sshrv`  : This client is called by sshnp to connect the local sshd to the rendezvous point

To get going you just need two (or three if you want to use your own sshrvd service) atSigns and their .atKeys files and the
binaries (from the 
[latest release](https://github.com/atsign-foundation/sshnoports/releases)).
Once you have the atSigns (free or paid atSigns from [atsign.com](https://atsign.com)), drop the binaries in place
on each machine and put the keys in `~/.atsign/keys` directory. You will need
a device atSign and a manager atSign, but each device can also have a unique
device name using the --device argument.

Once in place you can start up the daemon first on the remote device.
Remember to start the daemon on start up using rc.local script or similar, examples can be found in the scripts directory in this repo and in the release tar files.

`sshnpd.sh` : bash script
`tmux-sshnpd.sh` : bash script that uses `tmux` to provide realtime logging/view of the running daemon

```
./sshnpd --atsign <@your_devices_atsign> --manager <@your_manager_atsign> \
--device <iot_device_name> -u -s
```

Once that has started up you can run the client code from another machine.

```
./sshnp --from <@your_manager_atsign> --to <@your_devices_atsign>  \
--host <atSign of sshrvd or FQDN/IP of client machine>  --device <iot_device_name> -s <>
```

The --host specifies the atSign of the sshrvd or the DNS name of the openssh server of the client machine that the remote device can connect to. If everything goes to plan the client
will complete and tell you how to connect to the remote host for example.

Example command would be:-
```
./sshnp -f @cconstab -t @ssh_1 -d orac  -h @stream -s id_ed25519.pub
```
Which would output 
```
ssh -p 39011 cconstab@localhost -i /home/cconstab/.ssh/id_ed25519
```

Atsign provides a sshrvd service but if you want to run your own `sshrvd` you will need a machine that has an internet IP and all ports 1024-65535 unfirewalled and an atSign for the daemon to use.


When you run this you will be connected to the remote machine via a reverse
ssh tunnel from the remote device. 

If you want to do this in a single command use `$(<command>)` for example, note you can specify a ssh public key so you do not get asked for passwords. Use `ssh-keygen` to generate a new ssh key if you do not have one already to access the remote sshd.

```
$(./sshnp -f @myclient -t @myserver -d mymachine -h @myrz -s id_ed25519.pub)
```

If you can now login using sshnp then you can now turn off sshd from listening on all external interfaces, and instead have ssh listen only on 127.0.0.1.

That is easily done by editing `/etc/ssh/sshd_config`  

```
#Port 22
#AddressFamily any
ListenAddress 127.0.0.1
#ListenAddress ::
```

And restarting the ssh daemon. Please make sure you start the sshnpd on
startup and reboot and check. As this is beta code it is suggested to
wrap the daemon in a shell script or have sysctld make sure it is running. 

My preference whilst testing was to run the daemon in TMUX so that it is easy
to see the logs (-v).


### sshnpd (daemon) in a docker container

The daemon can also be deployed as part of a pre-built docker container,
that also has a number of networking tools installed. The container image
is located on Dockerhub as `atsigncompany/sshnpd:latest` or you can build
your own using the Dockerfile in the root of the project.

The image expects to have the atKeys for the atSign being used in the
`/atsign/.atsign/keys` directory, this can be mounted as a volume at startup
of the docker run command using `-v $(pwd):/atsign/.atsign/keys/` assuming
you are in the directory where the atKeys file is located. The full command
to start the container would be something like this:-

```
docker run -v <location of atKeys>:/atsign/.atsign/keys/ atsigncompany/sshnpd "-a <atSign> -m <atSign> -d <device name> -v -u -s"
```

Once the container is running to log into the container the sshnp command
would be used as normal, but you will log into the container not the host,
from the container you could then log into the host or any other local
network hosts you have access to.

Docker is very well documented and if you want to keep the container running
after a reboot if for some reason the container crashes is all easily achieved.


## TWO Ways to run SSH! no ports daemons (root access NOT required)

### `sshnpd.sh` and `sshrvd.sh` - plain old shell scripts and log file

The scripts directory of this repo contains an example `sshnpd.sh` that can
be run in a user's home directory (and assumes that the release has been
`untar`'d there too). 
Copy the file of interest to your home directory, so the next release does not over write your config e.g.

`cp ~/sshnp/sshnpd.sh ~/sshnpd.sh`

Make sure to replace the placeholders for sending <atSign> receiving <atSign>
and <devicename>.

You might also want to add a crontab entry to run the script on reboot:

```
@reboot /home/<username>/sshnpd.sh > ~/sshnpd.log 2>&1
```

### `tmux-sshnpd.sh` and `tmux-sshrvd.sh` - the power of tmux, highly recommended if tmux is installed `sudo apt install tmux`

This runs the daemon inside a tmux session, which can be connected to in order
to see logs.

Copy the file of interest to your home directory, so the next release does not over write your config, e.g.

`cp ~/sshnp/tmux-sshnpd.sh ~/tmux-sshnpd.sh`

Once again, ensure that the placeholders are replaced, and this can be run
by cron using:

```
@reboot /home/<username>/tmux-sshnpd.sh > ~/sshnpd.log 2>&1
```

### systemd units

The systemd directory contains an example unit file with its own
[README](systemd/README.md).

## Maintainers

Created by Atsign 

Thoughts/bugs/contributions via PR all very welcome!


Original code by [@cconstab](https://github.com/cconstab)

