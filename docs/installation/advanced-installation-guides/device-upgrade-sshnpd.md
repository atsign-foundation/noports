---
icon: upload
---

# Device Upgrade

## Upgrade the sshnpd binary

Upgrading to the latest version of sshnpd is identical to the installation process.

Please see the [installation guide](device-upgrade-sshnpd.md#upgrade-the-sshnpd-binary) to proceed.

### Verify the Upgrade

To check the current version of sshnpd installed on your machine simply execute the binary:

{% tabs %}
{% tab title="Linux" %}
```sh
$HOME/.local/bin/sshnpd
```

Or if you installed as root:

```
/usr/local/bin/sshnpd
```

The first line of output should contain the version information:

```sh
Version : x.x.x
```
{% endtab %}

{% tab title="macOS" %}
```sh
$HOME/.local/bin/sshnpd
```

Or if you installed as root:

```
/usr/local/bin/sshnpd
```

The first line of output should contain the version information:

```sh
Version : x.x.x
```
{% endtab %}
{% endtabs %}

## Reload the sshnpd service

After upgrading the sshnpd binary, we must restart the sshnpd service so that it runs using the new version. How you proceed is dependent on the original installation method you used:

1. [Systemd unit](device-upgrade-sshnpd.md#systemd-unit)
2. [Tmux session](device-upgrade-sshnpd.md#tmux-session)
3. [Headless (cron + nohup)](device-upgrade-sshnpd.md#headless-cron--nohup)

### Systemd unit

We simply need to restart the systemd service:

```bash
sudo systemctl restart sshnpd.service
```

The service will restart using the new binary that has been put in place.

### Tmux session

The installer automatically restarts your tmux session, no other steps required!

### Headless (cron + nohup)

#### Retrieve the Process ID

To safely restart the headless service, we must be slightly more careful with the headless installation. First we must grab the process id of sshnpd:

```bash
pgrep -f "$(eval echo \"$( cat $HOME/.local/bin/sshnpd.sh | grep /sshnpd | awk '{$1=$1};1')\" )"
```

<details>

<summary>If you're curious how this command works</summary>

```bash
cat $HOME/.local/bin/sshnpd.sh | grep /sshnpd | awk '{$1=$1};1'
```

Print out the contents of the sshnpd.sh service file, then extract the line where we execute the sshnpd program.

```bash
eval echo \"$(...)\"
```

Resolve any variables in place for the output of the previous expression.

```bash
pgrep -f "$(...)"
```

Find the process id of the program which was started using the command matching the output of the previous expression.

</details>

You should get a single number as output, this is the process ID of the sshnpd process.&#x20;

**Example:**

```
atsign@sshnpd-test:~# pgrep -f "$(eval echo \"$( cat $HOME/.local/bin/sshnpd.sh | grep /sshnpd | awk '{$1=$1};1')\" )"
289
```

#### Verify the Process ID

Before we continue, it is good practice to make sure that we have the correct ID:

```bash
ps -fp <process ID>
```

**Example:**

```
atsign@sshnpd-test:~# ps -fp 289
UID            PID    PPID  C STIME TTY          TIME CMD
atsign         289     114  0 11:10 ?        00:00:00 /home/atsign/.local/bin/sshnpd -a @atsign_device -m @atsign_client -d mydevice -suv
```

As you can see, under `CMD` we have `/home/atsign/.local/bin/sshnpd -a @atsign_device -m @atsign_client -d mydevice -suv`. This is the command inside our sshnpd.sh service which used to start sshnpd. This is the correct process that we want to kill in order to restart sshnpd.

#### Killing the process

Now that we have retrieved and verified the process ID, we can use the kill command to kill the process:

```bash
kill -9 <process ID>
```

Example:

```
root@sshnpd-test:~# kill -9 289
```

#### Verify the Process has been killed

Use the same verification command from before:

```bash
ps -fp <process ID>
```

**Example:**

```
root@sshnpd-test:~# ps -fp 289
UID          PID    PPID  C STIME TTY          TIME CMD
```

As you can see, there are no entries anymore. This means process 289 has been killed, sshnpd should automatically restart under a new process ID.
