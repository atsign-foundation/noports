# Example commands to build and run this program in a docker container:


## Build

Run this from the root of the repository:

```sh
docker build -f packages/go/trynoports/Dockerfile . --platform linux/amd64 -t trynoports:0.0.1
```

## Setup

Run this from the directory where this markdown file is located:

Copy the atkeys for the sshnpd instance into the container:
```sh
mkdir -p .atsign/keys
cp ~/.atsign/keys/@device_key.atKeys .atsign/keys/
```

Generate host keys for the go program:
```sh
mkdir -p .ssh
ssh-keygen -t ed25519 -f .ssh/id_ed25519
```

## Run

Lowercase flags are for the go program.
Capital flags are passed to the child sshnpd program.

-h is the nmap host (not working in this container yet)
-f will make you use ifconfig instead of ip
-k path to the ssh key, you shouldn't need to change this if you followed along correctly

Some arguments for sshnpd use the capital letter to represent their sshnpd equivalent (amdsuvk),
the rest of the arguments for sshnpd may be passed via the ARGS flag (';' delimited).
For example: `-ARGS "--ssh-client;dart"`
```sh
docker run trynoports:7 -h 192.168.1.74 -f -k /atsign/.ssh/id_ed25519 \
  -A @device -M @client -D trynoports -S -U -V -K /atsign/.atsign/keys/@device_key.atKeys
```

