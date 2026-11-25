---
icon: upload
---

# NoPorts Daemon Upgrade

### Upgrade the sshnpd binary

Upgrading to the latest version of sshnpd follows the same process as installation, as the installer automatically replaces existing binaries with the new ones.

To upgrade, follow the [installation guide](../advanced-installation-guides/device-installation-sshnpd/) up to **Step 3**, then return to this page to complete the process.

For a headless or tmux job, each install sets `binary_path` in the job script to the directory it installs the programs into, replacing any value you set there by hand.

### Headless or tmux jobs installed with sudo

A headless or tmux job runs as the user who installs it, so `./install.sh headless sshnpd` and `./install.sh tmux sshnpd` run without `sudo`. If the job was installed earlier with `sudo`, the job script, its log directory or `~/.local` can belong to root, and the job is in root's crontab. The installer then stops before changing anything, lists what you do not own, and prints the steps to clean up that install. When `~/.local` and `~/.sshnpd` belong to root, the steps for sshnpd are:

```sh
sudo sh -c 'crontab -l | grep -v -F -- "$1" | crontab -' sh "$HOME/.local/bin/sshnpd.sh"
script=$(printf '%s\n' "$HOME/.local/bin/sshnpd.sh" | sed 's/[[\.*^$+?(){|]/\\&/g')
sudo sh -c 'for p in $(pgrep -u 0 -f -- "^[^ ]*sh $1\$"); do c=$(pgrep -P "$p"); kill "$p"; [ -z "$c" ] || kill $c; done' sh "$script"
mv "$HOME/.local" "$HOME/.local.old" && cp -R "$HOME/.local.old" "$HOME/.local"
mv "$HOME/.sshnpd" "$HOME/.sshnpd.old" && cp -R "$HOME/.sshnpd.old" "$HOME/.sshnpd"
```

Run them as the user who will run the daemon:

* the first, which needs an admin who can use `sudo`, removes the job's line from root's crontab;
* the next two stop the job that root started from that line, and the sshnpd it runs: the `script=` line writes the job script's path as a pattern that matches only that path, and the `sudo` line stops each root process running that script, and its child, leaving your own processes alone (the installer prints this step with the pattern written out);
* the others move each directory aside and copy it back, so that you own the copy (a tmux job has no `~/.sshnpd`, so leave that line out).

When only `~/.local/bin`, the job script or `~/.sshnpd/logs` belongs to root, the installer prints the same steps for that path instead, and when a `.old` name is taken it uses the next free one, such as `.old.2`. Then run the installer again.

### Headless or tmux jobs installed with universal.sh and sudo

If you installed a headless or tmux job by running an earlier `universal.sh` with `sudo` on a host without systemd, the job is started from root's crontab, and the installer cannot see that line. Before you run the installer, remove that line and stop the job root started from it, as the user who will run the daemon:

```sh
sudo sh -c 'crontab -l | grep -v -F -- "$1" | crontab -' sh "$HOME/.local/bin/sshnpd.sh"
script=$(printf '%s\n' "$HOME/.local/bin/sshnpd.sh" | sed 's/[[\.*^$+?(){|]/\\&/g')
sudo sh -c 'for p in $(pgrep -u 0 -f -- "^[^ ]*sh $1\$"); do c=$(pgrep -P "$p"); kill "$p"; [ -z "$c" ] || kill $c; done' sh "$script"
```

Then run the installer without `sudo`.

### Verify the Upgrade

To check the current version of sshnpd installed on your machine, simply run it:

{% tabs %}
{% tab title="Linux" %}
```sh
$HOME/.local/bin/sshnpd
```

Or, if you installed as root:

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

The first line of output should contain the version information:

```sh
Version : x.x.x
```
{% endtab %}
{% endtabs %}

### Reload the sshnpd service

After upgrading sshnpd, we must restart the sshnpd service so that it runs using the new version. How you proceed is dependent upon the original installation method you used:

1. [Systemd unit](device-upgrade-sshnpd.md#systemd-unit)
2. [Tmux session](device-upgrade-sshnpd.md#tmux-session)
3. [Headless (cron + nohup)](device-upgrade-sshnpd.md#headless-cron--nohup)

### Systemd unit

The `universal.sh`installer script will automatically restart the `sshnpd.service`unit.

Any existing config will be preserved.

### Tmux session

The installer automatically restarts your tmux session, no other steps required!

### Headless (cron + nohup)

The installer stops the running job and its sshnpd. Start the job again with the command the installer prints, which is the command in Step 4 of the [headless installation guide](../advanced-installation-guides/device-installation-sshnpd/headless.md):

```bash
nohup $HOME/.local/bin/sshnpd.sh > $HOME/.sshnpd/logs/sshnpd.log 2> $HOME/.sshnpd/logs/sshnpd.err &
```

Sessions that are already open are not ended.
