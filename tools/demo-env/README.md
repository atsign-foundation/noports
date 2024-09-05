# Demo Environment

This directory will contain a completely local end-to-end demo environment of
NoPorts using docker containers and networks to isolate various components.

## atSigns

<!-- markdownlint-disable md013 -->

| Purpose / Usage                        | Atsign    | Assigned Ports                  |
| -------------------------------------- | --------- | ------------------------------- |
| atDirectory                            | N/A       | 64                              |
| Supervisord (infrastructure dashboard) | N/A       | 9001                            |
| atServers                              | N/A       | 25000-25019                     |
| Relay 1                                | @jagan🛠  | 20000-20099                     |
| Relay 2                                | @ashish🛠 | 20100-20199                     |
| Device 1                               | @alice🛠  | 20200-20299                     |
| Device 2                               | @bob🛠    | 20300-20399                     |
| Device 3 (with APKAM)                  | @srie🛠   | 20400-20499                     |
| Policy 1                               | @kevin🛠  | 3000 (dashboard), 20500-20599   |
| Policy 2 (in a future version)         | @eve🛠    | 9003 (dashboard), 20600-20699   |
| Client 1 (manager)                     | @colin🛠  | N/A (no container, use on host) |
| Other clients (configure in policy)    | any       | N/A (no container, use on host) |

### Dashboard Links

1. [Supervisord](http://localhost:9001)
2. [Policy Kevin](http://localhost:3000)

<!-- markdownlint-enable md013 -->

> Note: there are many assigned ports for this demo because we are using the
> ephemeral port range, and docker is not designed well for use with ephemeral
> ports... In the real world, you wouldn't have to do this kind of garbage.

## Usage

There are two services running inside each of the device containers:

1. openssh server
2. nginx server

The @bob🛠 container also supports remote desktop passthrough back to the host.

### Setup

Add the following entries to `/etc/hosts` on your host machine:

```txt
# Hostnames in docker that we want to loop back to
127.0.0.1 vip.ve.atsign.zone
127.0.0.1 relay1.atsign.zone
127.0.0.1 relay2.atsign.zone
```

Setup docker environment with docker compose:

```sh
docker compose up -d
```

Source the client utility file:

> Do this step every time you open a new shell

```sh
source client.sh
```

### Run client

Then run `noports` to see the usage. Change the atSigns in the input to
`noports` as needed, refer to table above for options.

> `noports` will not run commands for you, but it will print commands to the
> terminal which you may copy/paste, or wrap with `$()` to run automatically  
> e.g. `$(noports @colin @alice @jagan ssh)`
