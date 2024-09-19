---
description: Installation of sshnpd on the IPFire.org firewall
icon: block-brick-fire
---

# IPFire

{% embed url="https://youtu.be/6PzJqeI5g9g" %}

## Install IPFire

IPFire provides a solid Firewall and uses a base Linux OS. The installation of the OS itself is well documented at ipfire.org. X64 and Arm devices like Raspberry PI's are well supported.

\
Make sure to configure the network interfaces and ensure you can get to the Web Interface on&#x20;

```
https://<GREEN Interface IP>:444
```

## Installing sshnpd the SSH No Ports Daemon

#### Web UI Setup

SSH No Ports relies on the SSH daemon and so the first step is to enable it on the IPFire Web interface, under System.



<figure><img src="../../.gitbook/assets/Screenshot from 2024-04-29 18-05-59.png" alt=""><figcaption><p>Enable all options</p></figcaption></figure>

We will also need to add the TMUX package via the web interface under the IPFire section click Pakfire, then add TMUX.

<figure><img src="../../.gitbook/assets/Screenshot from 2024-04-29 18-09-27.png" alt=""><figcaption></figcaption></figure>

#### Linux Setup

#### Add non root user

IPFire only has a root user after installation so the first step is to set up a non privileged account in this example we will use `atsign` but feel free to pick your own. Login to the console or via SSH as root and type:

```
useradd -d /home/atsign -m -U atsign
```

#### Non root user environment

The next step is su to the user you just created and setup the directories sshnpd will need

```
su - atsign
mkdir -p ~/.atsign/keys ~/.ssh
chmod 700 ~/.atsign ~/.atsign/keys ~/.ssh
touch ~/.ssh/authorized keys
chmod 600 ~/.ssh/authorized keys
```

#### Adding sudo access (if you want to) to the new user account

Using `sudo` allows you to get access to the root account if you need it but keep at a non root shell when you do not, its a good practice but optional.

As root you will need to edit the /etc/sudoers file and uncomment the line below as show by removing the #. Note you may need to use `w!` in vi to force the update of the file.

```
## Uncomment to allow members of group sudo to execute any command
%sudo	ALL=(ALL:ALL) ALL
```

Once done then you can add the sudo group and then add the username atsign to the group with the following commands as root.

```
groupad sudo
usermod -a -G sudo atsign
```

Then add a password to the atsign account again as root

```
passwd atsign
```

Once completed then check everything is working by su - to atsign the using sudo -s to get back to root.

```
su - atsign
sudo -s 
```

#### Installing sshnpd&#x20;

As atsign (not root!) download the SSH No Ports software, which we can do with curl and then unpack the archive with tar. The curl command below brings in the x64 CPU architecture file if you are using Arm/Arm64 then curl down the right option by picking the right link from:-

{% content-ref url="../advanced-installation-guides/" %}
[advanced-installation-guides](../advanced-installation-guides/)
{% endcontent-ref %}

```
curl -L https://github.com/atsign-foundation/noports/releases/latest/download/sshnp-linux-x64.tgz -o sshnp.tgz
tar zxvf sshnp.tgz
```

To install the software just cd and run the install command

```
cd sshnp
./install.sh tmux sshnpd
```

You will see some errors at this stage as IPFire uses fcron not cron which needs root powers to install fcron jobs which we will handle soon.&#x20;

#### Configuring the sshnpd.sh file

The sshnpd is started via a script and that script and that script needs some simple edits. You will need to know your atSign for the device (\_device) and manager (\_client). to edit use nano/vi on this file.

```
~/.local/bin/sshnpd.sh
```

Then edit the lines as below with **your** details.

```
manager_atsign="@cconstab" # MANDATORY: Manager/client address/Comma separated addresses (atSign/s)
device_atsign="@ssh_1"     # MANDATORY: Device address (atSign)
device_name="ipfire01"     # Device name

```

#### Certificate Authority public certificates

IPFire has non standard base certificates but we can install the latest versions from Mozilla so the sshnpd daemon can use TLS, by using these commands.

```
sudo mkdir -p /etc/pki/tls/certs
curl --etag-compare etag.txt --etag-save etag.txt --remote-name https://curl.se/ca/cacert.pem && sudo mv cacert.pem /etc/pki/tls/certs/ca-bundle.crt
```

#### Put your atSign atKeys file in place

If you have not got your atKeys file you will need to use at\_activate to get them as explained in the the advanced installation guide. If you do have the keys for your device then they need to be in the \~/.atsign/keys directory. You can scp them over for instance. Its a good idea to chmod them to 600.

```
chmod 600 ~/.atsign/keys/*
```

#### Adding the fcron entries

As mentioned above fcron is used not cron so a couple of extra steps are required. First add your username to the /etc/fcron.allow file.

```
sudo vi /etc/fcron.allow
```

Then add your username ours looks like this

```
root
atsign
```

Once that is completed then you can add an entry to atsign's fcron, this can only be done as root and uses vi to edit by default.

```
sudo fcrontab -u atsign -e
```

Then you will need to add the following line

```
@reboot tmux new-session -d -s sshnpd && tmux send-keys -t sshnpd /home/atsign/.local/bin/sshnpd.sh C-m
```

That's it you are done!

To test you can reboot or as atsign run the command below and try and log in using sshnp

```
@reboot tmux new-session -d -s sshnpd && tmux send-keys -t sshnpd /home/atsign/.local/bin/sshnpd.sh C-m &
```

#### Logging in from a remote machine

At this point you will be able to log in remotely using sshnp. The first time you will need to specify a ssh key using the -i and -s arguments. This will put the public key into the authorized\_hosts file on the IPFire machine.  In my case I would use.

```
sshnp -f @cconstab -t @ssh_1 -h @rv_am -d ipfire01 -i ~/.ssh/id_rsa -s
```

your will look like something similar depending on your SSH Key pair (you can generate one if you do not have one with ssh-keygen) and your client/device atsigns.

When you get logged in you can remove the -s and the -i flags and login on subsequent logins as the public key will be in place on the IPFire machine. You will have to put the keys you want to use in \~/.ssh/config also on the machine you are ssh'ing from, in my case I use a single line.

```
IdentityFile ~/.ssh/id_rsa
```

Remember to keep your SSH and  Atsign keys safe and make a copy offline.

You are now able to login from anywhere as long as the firewall and you have Internet access. Congrats!&#x20;

#### For the paranoid

If you would like to remove the ssh daemon from the GREEN side as well then you can edit the `/etc/ssh/sshd_config` file to only bind on localhost but updating this line.

```
ListenAddress 0.0.0.0
```

to&#x20;

```
ListenAddress localhost
```

and then reboot or restart the sshd daemon.
