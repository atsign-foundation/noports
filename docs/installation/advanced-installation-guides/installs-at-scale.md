---
description: Typing is less fun after a few devices.
icon: grid-horizontal
---

# Installs at scale

## Important Notes

This is an engineering guide, not a definitive solution, as every production environment is different. Feel free to borrow what is useful and ignore what is not. If you have better ideas or ways, please let us know!

### Other considerations

Each atSign has a reasonable maximum of 25 devices that it can manage, so keep that in mind as you use this script to roll out devices. By default, the hostname is used as the `-d`DEVICE\_NAME. Your hostnames may not match the requirements of the DEVICE\_NAME flag.

* Lowercase Alphanumeric max 15 Characters Snake Case before version 5.0.3
* Case insensitive Alphanumeric max 36 Chars Snake Case from version 5.0.3 onwards.
  * allows UUID snake cased device names.

## Install.sh

Cut and paste this script and tailor it to your needs. Do not forget to chmod 500 or else it will not run! More details below on how to set things up, and a demo run, too, using Docker.

```bash
#!/bin/bash
# Configure these variables to your liking or pass in args
if [ $# -ne 8 ]
then
# USERNAME & PASSWORD created with sudo priviledges by install.sh
export USERNAME="ubuntu"
export PASSWORD="changeme"
# URL of the config/sshnpd.sh file contained in this repo (this will change if repo is cloned)
export CONFIG_URL="https://gist.githubusercontent.com/cconstab/142c942ce0c8caa3348d0976a60fbfd1/raw/d243d64573bf2b7de5e827ff9b7b7f2f2413901b/gistfile1.txt"
# Remember to encrypt your keys!!!!
# Encrypt with
# openssl enc -aes-256-cbc -pbkdf2 -iter 1000000 -salt -in ~/.atsign/keys/@ssh_1_key.atKeys -out @ssh_1_key.atKeys.aes
# Test decrypt with
# openssl aes-256-cbc -d -salt -pbkdf2 -iter 1000000 -in ./@ssh_1_key.atKeys.aes -out ./@ssh_1_key.atKeys
export ATKEYS_URL="https://filebin.net/cpme4bhrqolyrnts/_ssh_1_key.atKeys.aes"
# This is the AES password you used to encrypt the above file
export ATKEY_PASSWORD="helloworld12345!"
# Manager atSign either a Single atSign or comma delimited list from sshnpd v5.0.3
export MANAGER_ATSIGN="@cconstab"
export DEVICE_ATSIGN="@ssh_1"
export DEVICE_NAME="$(hostname)"
else 
export USERNAME=$1
export PASSWORD=$2
export CONFIG_URL=$3
export ATKEYS_URL=$4
export ATKEY_PASSWORD=$5
export MANAGER_ATSIGN=$6
export DEVICE_ATSIGN=$7
export DEVICE_NAME=$8
fi
####################################################################
# Get machine updated and with the needed packages                 #
####################################################################
apt update
apt install tmux openssh-server curl cron sudo -y 
# create USERNAME with sudo priviledges
useradd -m -p $(openssl passwd -1 ${PASSWORD}) -s /bin/bash -G sudo ${USERNAME}
####################################################################
# start sshd listening on localhost only                           #
####################################################################
# Update the sshd config so it only runs on localhost
#sed -i 's/#ListenAddress 0.0.0.0/ListenAddress 127.0.0.1/' /etc/ssh/sshd_config
# restart sshd if your OS starts it on install
# e.g on Ubuntu/Debian
#systemctl restart ssh.service
# or Redhat/Centos
#systemctl restart sshd.service
####################################################################
# Start sshd Only needed if sshd is not started by default         #
# for example a docker container                                   #
# Remove these lines if the OS you are using starts up sshd itself #
####################################################################
# File needed for sshd to run
mkdir /run/sshd
# generate the sshd Keys
ssh-keygen -A
# Start sshd listening on localhost and with no password auth 
/usr/sbin/sshd -D -o "ListenAddress 127.0.0.1" -o "PasswordAuthentication no"  &
####################################################################
# Install sshnpd as the selected USERNAME                          #
####################################################################
su --whitelist-environment="MANAGER_ATSIGN,DEVICE_ATSIGN,ATKEY_PASSWORD,ATKEYS_URL,DEVICE_NAME" -c ' \
set -eux; \
    case "$(dpkg --print-architecture)" in \
        amd64) \
            SSHNPD_IMAGE="https://github.com/atsign-foundation/noports/releases/latest/download/sshnp-linux-x64.tgz" ;; \
        armhf) \
            SSHNPD_IMAGE="https://github.com/atsign-foundation/noports/releases/latest/download/sshnp-linux-arm.tgz" ;; \
        arm64) \
            SSHNPD_IMAGE="https://github.com/atsign-foundation/noports/releases/latest/download/sshnp-linux-arm64.tgz" ;; \
        riscv64) \
            SSHNPD_IMAGE="https://github.com/atsign-foundation/noports/releases/latest/download/sshnp-linux-riscv.tgz" ;; \
        *) \
            echo "Unsupported architecture" ; \
            exit 5;; \
    esac; \
cd ; \
mkdir -p ~/.local/bin ; \
mkdir -p ~/.atsign/keys ; \
curl -fSL ${ATKEYS_URL} -o atKeys.aes ; \
openssl aes-256-cbc -d -salt -pbkdf2 -iter 1000000 -in ./atKeys.aes -out ~/.atsign/keys/${DEVICE_ATSIGN}_key.atKeys --pass env:ATKEY_PASSWORD ; \
chmod 600 ~/.atsign/keys/${DEVICE_ATSIGN}_key.atKeys ; \
curl -fSL $SSHNPD_IMAGE -o sshnp.tgz ; \
tar zxvf sshnp.tgz ;\
sshnp/install.sh tmux sshnpd ;\
curl --output ~/.local/bin/sshnpd.sh ${CONFIG_URL} ; \
sed -i "s/MANAGER_ATSIGN/$MANAGER_ATSIGN/" ~/.local/bin/sshnpd.sh ; \
sed -i "s/DEVICE_ATSIGN/$DEVICE_ATSIGN/" ~/.local/bin/sshnpd.sh ; \
sed -i "s/DEVICE_NAME/$DEVICE_NAME/"  ~/.local/bin/sshnpd.sh ; \
# Uncomment this if you _want_ to use '-u' for sshnpd ; \
#sed -i "s/# u=\"-u\"/u=\"-u\"/" ~/.local/bin/sshnpd.sh ; \
# Uncomment this if you do _not_ want `-s` enabled (you would need to send ssh keys)
#sed -i "s/s=\"-s\"/# s=\"-s\"/"  ~/.local/bin/sshnpd.sh ; \
rm -r sshnp ; \
rm sshnp.tgz atKeys.aes' $USERNAME
####################################################################
# Start sshnpd, the crontab entry will do this on reboots          #
####################################################################
su - $USERNAME sh -c "/usr/bin/tmux new-session -d -s sshnpd && tmux send-keys -t sshnpd /home/ubuntu/.local/bin/sshnpd.sh C-m" 
# Helpful to sleep if using Docker so container stays alive.
# sleep infinity
```

### Set up your environment.

Each atSign has its own set of keys that are "cut" with at\_activate. This will cut the keys for the atSign and place them in `~/.atsign/keys`. Each machine requires the atKeys file to run sshnpd, so, we need to have a way to get them to each device. It is possible to ssh/scp them, but that becomes very cumbersome at scale. Instead, we encrypt the keys with AES256 and place them on a webserver. When the install script is run, it knows both the URL and the encryption password and can pull the atKeys file to the right place.

The steps are to (1) get the atKeys file as normal using at\_activate, then (2) encrypt them using a command like this:

```
mkdir enckeys
cd enckeys
openssl enc -aes-256-cbc -pbkdf2 -iter 1000000 -salt -in ~/.atsign/keys/@ssh_1_key.atKeys -out @ssh_1_key.atKeys.aes
```

This command will ask you for a password which you will put in the `install.sh` file as `ATKEY_PASSWORD`.

You can then set up a simple http (the file is encrypted) server to serve the keys with. For example, a Python single line of code:

`python3 -m http.server 8080 --bind 0`

Alternatively, you can put the keys file on filebin.net and it will locate the file in a random URL which you can put into the `install.sh` file. For example:

`https://filebin.net/s2w5r6gwemmz5kvi/_ssh_1_key.atKeys.aes`

It is worth noting that the `@` gets translated to a `_` but that does not effect the script. Using this site has the advantage that the URL is hidden, and it uses TLS—plus you can delete the files once completed.

At this point you can derive the URL of the encrypted atKeys file and put it in the `install.sh` file headers.

```
export ATKEYS_URL="http://192.168.1.61:8080/@ssh_1_key.atKeys.aes"
# This is the AES password you used to encrypt the above file
export ATKEY_PASSWORD="helloworld12345!"
```

The other variables should be straightforward enough.

```
export USERNAME=ubuntu
export PASSWORD="changeme"
export CONFIG_URL="https://raw.githubusercontent.com/cconstab/sshnpd_config/main/config/sshnpd.sh"
```

{% embed url="https://gist.githubusercontent.com/cconstab/142c942ce0c8caa3348d0976a60fbfd1/raw/d243d64573bf2b7de5e827ff9b7b7f2f2413901b/gistfile1.txt" %}
Gist for sshnpd config file
{% endembed %}

The other variables set up the atSigns for the manager and device and for the device name itself. The device name by default uses the `hostname` using the shell command `$(hostname)` , but that only works if the hostname is compliant with the `-d` format of sshnpd. You can pick another way to identify the host or just make sure the hostname is compliant.

## Running the install.sh (Note: Has to be run as root)

This is a simple matter now of getting the install.sh to the target device and running it. The needed files will be installed, the username name created, cronjobs put in place, and the 'sshnpd' will be started.

How you get the `install.sh` file to the target machine is going to vary depending on your environment. Using scp is a good option, as is using ssh or curl and pulling the file (using the same encryption method perhaps).

## Scaling things up

The install.sh script works fine on individual machines, but if you want to install on, say, 25 machines, this is how you do it.

First, you need to have ssh root access to the machines you want to install on. _This SSH access will be removed as you do the install with this line uncommented:_

```bash
#sed -i 's/#ListenAddress 0.0.0.0/ListenAddress 127.0.0.1/' /etc/ssh/sshd_config
```

If you pass 8 arguments into the install.sh they will be used rather than the hardcoded values. This allows you to pass in the values needed as the script is run QED.

For example:

`./install.sh ubuntu changeme https://raw.githubusercontent.com/cconstab/sshnpd_config/main/config/sshnpd.sh http://192.168.1.61:8080/@ssh_1_key.atKeys.aes helloworld @cconstab @ssh_1 $(hostname)`

## To test this

Using Docker is the simple way to test any options first before moving to production.

Something like this will mount the script and start a basic Linux build:

`docker run -it -v ./install.sh:/root/install.sh debian:trixie-slim`

You can then cd and run the `install.sh` script. For example:

```
╰$ docker run -it -v ./install.sh:/root/install.sh debian:trixie-slim
root@f5040633c8a0:/# cd
root@f5040633c8a0:~# ls
install.sh
root@f5040633c8a0:~# ./install.sh 
```

After the install has completed, you can su - to the USERNAME you chose and see tmux/sshnpd running.

```
root@f5040633c8a0:~# su - ubuntu
ubuntu@f5040633c8a0:~$ tmux ls
sshnpd: 1 windows (created Sun Mar  3 22:48:01 2024)
ubuntu@f5040633c8a0:~$ 
```

On another machine, you can log in to the container using the select MANAGER\_ATSIGN, remembering to give the daemon a ssh key and the username.

```
~/.local/bin/sshnp -f @cconstab -t @ssh_1  -h @rv_am -s -i ~/.ssh/id_ed25519 -u ubuntu  -d f5040633c8a0
2024-03-03 14:51:34.574057 : Resolving remote username for user session
2024-03-03 14:51:34.574107 : Resolving remote username for tunnel session
2024-03-03 14:51:34.574562 : Sharing ssh public key
2024-03-03 14:51:36.239757 : Fetching host and port from srvd
2024-03-03 14:51:39.239811 : Sending session request to the device daemon
2024-03-03 14:51:39.469112 : Waiting for response from the device daemon
2024-03-03 14:51:40.993543 : Received response from the device daemon
2024-03-03 14:51:40.994470 : Creating connection to socket rendezvous
2024-03-03 14:51:41.114766 : Starting tunnel session
2024-03-03 14:51:41.989428 : Starting user session
Linux f5040633c8a0 6.6.12-linuxkit #1 SMP Fri Jan 19 08:53:17 UTC 2024 aarch64

The programs included with the Debian GNU/Linux system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Debian GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law.
Last login: Sun Mar  3 22:51:42 2024 from 127.0.0.1
-bash: warning: setlocale: LC_ALL: cannot change locale (en_US.UTF-8)
ubuntu@f5040633c8a0:~$
```

You are now logged into the container. If you need root access, you can use the password you chose to `sudo -s`

{% embed url="https://asciinema.org/a/645698" %}

Feel free to adapt this outline to your specific needs and share your improvements back with the community.
