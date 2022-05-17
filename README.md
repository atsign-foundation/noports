<img src="https://atsign.dev/assets/img/@dev.png?sanitize=true">

### Now for a little internet optimism

# Ssh! No ports

ssh no ports provides a way to ssh to a remote linux host/device without that
device having any open ports (not even 22) on external interfaces. All
network connectivity is out bound and there is no need to know the IP
address the device has been given. As long as the device has an IP address,
DNS and Internet access, you will be able to connect to it.

## Quick demo
[![asciicast](https://asciinema.org/a/nhcExPw1MZnn7sKEK6gJTJEkR.svg)](https://asciinema.org/a/nhcExPw1MZnn7sKEK6gJTJEkR)

There are two binaries:-

`sshnpd` : The daemon that runs on the remote device

`sshnp`  : The client that sets up a connection to the device which you
can then ssh to via your localhost interface

To get going you just need the binaries (from latest 
[release](https://github.com/atsign-foundation/sshnoports/releases))
or run them with dart and two @signs and the .atKeys files. Once you have the
@atsigns (atsign.com for free or paid @signs), drop the binaries in place on
each machine(s) and put the keys in `~/.atsign/keys` directory. You will need
a device @sign and a manager @sign, but each device can also have a unique
device name using the --device argument.

Once in place you can start up the daemon first on the remote device.
Remember to start the daemon on start up using rc.local script or similar.

```
./sshnpd --atsign <@your_devices_atsign> --manager <@your_manager_atsign> \
--device <iot_device_name> -u
```

Once that has started up you can run the client code from another machine.

```
./sshnp --from <@your_manager_atsign> --to <@your_devices_atsign>  \
--host <example.com>  -l --local-port --device <iot_device_name>
```

The --host specifies a DNS name of the openssh sever of the client machine
that the remote device can connect to. If everything goes to plan the client
will complete and tell you how to connect to the remote host for example.

```
ssh -p 2222 cconstab@localhost
```

When you run this you will be connect to the remote machine via a reverse
ssh tunnel from the remote device. Which means you can now turn off ssh from
listening all all interfaces instead have ssh listen just on 127.0.0.1.

That is easily done by editing `/etc/ssh/sshd.config`  

```
#Port 22
#AddressFamily any
ListenAddress 127.0.0.1
#ListenAddress ::
```

And restarting the ssh daemon. Please make sure you start the sshnpd on
startup and reboot and check.. As this is beta code it is suggested to
wrap the daemon in a shell script or have sysctld make sure it is running. 

My preference whilst testing was to run the daemon in TMUX so it is easy
to see the logs (-v).

Thoughts/bugs/contributions via PR all very welcome!

## Who is this tool for?

System Admins  
Network Admins  
IoT Manufacturers  
Anyone running ssh open to a hostile network!  

## Maintainers

Created by The @ Company 

Original code by [@cconstab](https://github.com/cconstab)

