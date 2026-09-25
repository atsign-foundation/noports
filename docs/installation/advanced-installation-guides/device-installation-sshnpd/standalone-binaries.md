---
description: The NoPorts daemon doesn't have to be run by systemd
layout:
  width: default
  title:
    visible: true
  description:
    visible: true
  tableOfContents:
    visible: true
  outline:
    visible: true
  pagination:
    visible: false
  metadata:
    visible: true
  tags:
    visible: true
  actions:
    visible: true
---

# Running without systemd

Once NoPorts is installed with a `/etc/noports/sshnpd.yaml` config and an atKeys file all that's needed to start the daemon is to run `sshnpd` .

But... without systemd there's nothing to restart `sshnpd` if it exits, and there's nothing capturing logs (and compressing, rotating and pruning them).

At the most basic level a simple script will restart the daemon if it fails:

```bash
#!/bin/bash
BACKOFF_INTERVAL=10
while true; do
  sshnpd
  sleep "$BACKOFF_INTERVAL"
done
```

Whatever runs `sshnpd` should be some kind of background task (so it doesn't exit when the session launching it is disconnected). For example redirect logs and run in background with:

```
nohup sshnpd > sshnpd.log 2> sshnpd.err < /dev/null &
```

A similar effect can be achieved by running `sshnpd` inside a terminal multiplexer such as [GNU Screen](https://www.gnu.org/software/screen/) or [Tmux](https://en.wikipedia.org/wiki/Tmux).
