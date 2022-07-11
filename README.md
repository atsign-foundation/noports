<img width=250px src="https://atsign.dev/assets/img/atPlatform_logo_gray.svg?sanitize=true">

# Ssh! No ports

ssh no ports provides a way to ssh to a remote linux host/device without that
device having any open ports (not even 22) on external interfaces. All
network connectivity is out bound and there is no need to know the IP
address the device has been given. As long as the device has an IP address,
DNS and Internet access, you will be able to connect to it.

## Quick demo
[![asciicast](https://asciinema.org/a/496148.svg)](https://asciinema.org/a/496148)

There are two binaries:-

`sshnpd` : The daemon that runs on the remote device

`sshnp`  : The client that sets up a connection to the device which you
can then ssh to via your localhost interface

To get going you just need two Atsigns and their .atKeys files and the
binaries (from latest 
[release](https://github.com/atsign-foundation/sshnoports/releases)).
It's also possible to run from the source here using `dart run`. Once you have
the Atsigns (free or paid Atsigns from atsign.com), drop the binaries in place
on each machine and put the keys in `~/.atsign/keys` directory. You will need
a device Atsign and a manager Atsign, but each device can also have a unique
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

The --host specifies a DNS name of the openssh server of the client machine
that the remote device can connect to. If everything goes to plan the client
will complete and tell you how to connect to the remote host for example.

```
ssh -p 3456 cconstab@localhost
```

When you run this you will be connect to the remote machine via a reverse
ssh tunnel from the remote device. Which means you can now turn off ssh from
listening all all interfaces instead have ssh listen just on 127.0.0.1.

That is easily done by editing `/etc/ssh/sshd_config`  

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

## Usage

### sshnpd (daemon)
Run the daemon binary file or the dart file:
```
./sshnpd <args|flags>
```
``` 
dart run bin/sshnpd.dart <args|flags>
```

| Argument  | Abbreviation | Mandatory | Description                                                                         | Default   |
|-----------|--------------|-----------|-------------------------------------------------------------------------------------|-----------|
| --keyFile | -k           | false     | Sending atSign's keyFile if not in `~/.atsign/keys/`                                |
| --atsign  | -a           | true      | atSign of this device                                                               |
| --manager | -m           | true      | manager atSigns, that this device will accept triggers from                         |
| --device  | -d           | false     | send a trigger to this device, allows multiple devices share an atSign              | "default" |

| Flags               | Abbreviation | Description                                                                     |
|---------------------|--------------|---------------------------------------------------------------------------------|
| --[no-]sshpublickey | -s           | Update authorized_keys to include public key from sshnp                         |
| --[no-]username     | -u           | send username to the manager to allow sshnp to display username in command line |
| --[no-]verbose      | -v           | More logging                                                                    |

### sshnp (client)
Run the binary file or the dart file:
```
./sshnp <args|flags>
```
```
dart bin/sshnp.dart <args|flags>
```
| Argument         | Abbreviation | Mandatory | Description                                                                           | Default   |
|------------------|--------------|-----------|---------------------------------------------------------------------------------------|-----------|
| --key-file       | -k           | false     | Sending atSign's atKeys file if not in `~/.atsign/keys/`                              |
| --from           | -f           | true      | Sending atSign                                                                        |
| --to             | -t           | true      | Send a notification to this atSign                                                    |
| --device         | -d           | false     | Send a notification to this device                                                    | "default" |
| --host           | -h           | true      | FQDN Hostname e.g. example.com or IP address to connect back to                       |
| --port           | -p           | false     | TCP port to connect back to                                                           | 22        |
| --local-port     | -l           | false     | Reverse ssh port to listen on, on your local machine                                  | 2222      |
| --ssh-public-key | -s           | false     | Public key file from `~/.ssh` to be appended to authorized_hosts on the remote device | false     |

| Flags          | Abbreviation | Description  |
|----------------|--------------|--------------|
| --[no-]verbose | -v           | More logging |

## Using Ngrok to avoid open ports at the admin end

The instructions above work for a system where the person doing the admin of
the machine connected to by sshnp is able to run an SSH daemon that's open
to the Internet. But that's often not practical for many of the same reasons
why the device can't/won't be reachable directly with an open port. To get
around this issue it's possible to use the [Ngrok](https://ngrok.com/)
service as a proxy for the inbound SSH connection.

### Get an Ngrok account

From their [signup page](https://dashboard.ngrok.com/signup)

### Add your SSH public key

From the system you're using for admin:

```
cat ~/.ssh/id_rsa.pub
```

Then copy the key and paste it into the `New SSH Key` box on the
[SSH Public Keys page](https://dashboard.ngrok.com/tunnels/ssh-keys).

### Configure a local SSH server

Such as OpenSSH. It can run on any port, and only needs to be bound to
localhost. The following example illustrates the use of an SSH server
bound to port 2222. So the example `/etc/ssh/sshd_config` above becomes:

```
Port 2222
#AddressFamily any
ListenAddress 127.0.0.1
#ListenAddress ::
```

### Start a reverse tunnel to Ngrok

It may be useful to do this in a `screen` or `tmux` session
as another terminal will be needed for `sshnp` later.

```
ssh -R 0:localhost:2222 tunnel.us.ngrok.com tcp
```

This will initialise a connection showing something like:

```
Allocated port 12357 for remote forward to localhost:2222

ngrok (via SSH) (Ctrl+C to quit)

Account     Demo McDemoname (Plan: Free)
Region      us
Forwarding  tcp://6.tcp.ngrok.io:12345
```

### Then invoke sshnp to connect via Ngrok

Command line form:

```
sshnp -f <@your_manager_atsign> -t <@your_devices_atsign> \
--device <iot_device_name> -h 6.tcp.ngrok.io -p 12345 -l 3456
```

NB: Ngrok is likely to provide a different tunnel server and port
each time. So substitute the values from the actual connection for
`-h 6.tcp.ngrok.io` and `-p 12345`

E.g.

```
sshnp -f @happyadmin -t @moresecurething \
--device demothing -h 4.tcp.ngrok.io -p 10646 -l 3456
```

### The tunnel inside a tunnel will now be ready

Connect to it with something like:

```
ssh -p 3456 -i ~/.ssh/key_for_device.key deviceuser@localhost
```

Where:

* `-p 3456` corresponds to `-l 3456` from the `sshnp` invocation
* `-i ~/.ssh/key_for_device.key` is presenting a private key that's trusted
by the device in its `~/.ssh/authorized_keys`
* `deviceuser` is the username for the device

### Tunnels in tunnels, an illustration

First a tunnel from Ngrok back to admin_PC:

```
ssh -R 0:localhost:2222 tunnel.us.ngrok.com tcp

                    admin_PC                Ngrok
                    2222<-------------------12345


                    <----------------------------
```

Then a tunnel initiated by `sshnp` from the device, through Ngrok to the
admin_PC:

```
sshnp -f @happyadmin -t @moresecurething \
--device demothing -h 0.tcp.ngrok.io -p 12345 -l 3456

                    admin_PC                Ngrok
          admin_PC  2222<-------------------12345    Device
          3456<----/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\-------22

          <------------------------------------------------
                    <----------------------------
```

Finally an SSH connection through those tunnels from the admin_PC
to the device:

```
ssh -p 3456 -i ~/.ssh/key_for_device.key deviceuser@localhost

                    admin_PC                Ngrok
          admin_PC  2222<-------------------12345    Device
SSH------>3456<----/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\-------22-------->SSHD
          \______________________________________________/

          <------------------------------------------------
                    <----------------------------
```

Of course that final SSH connection can also be used as a tunnel...

## Who is this tool for?

System Admins  
Network Admins  
IoT Manufacturers  
Anyone running ssh where they don't want it to be open to a hostile network!  

## Maintainers

Created by Atsign 

Original code by [@cconstab](https://github.com/cconstab)

