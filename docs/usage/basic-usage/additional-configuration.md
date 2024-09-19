---
icon: gear-complex-code
---

# Additional Configuration

## Options

<table><thead><tr><th width="172">Option</th><th width="99" data-type="checkbox">Required</th><th width="143">Default</th><th>Description</th></tr></thead><tbody><tr><td>-h, --remote-host, --rh</td><td>false</td><td>localhost</td><td>Used if you want to bind to another host on the remote machine. </td></tr><tr><td>-x, --exit-when-connected</td><td>false</td><td>false</td><td>Instead of running the srv in the same process, fork the srv, print the connected local port to stdout, and exit the program.</td></tr><tr><td>--[no-]pss, --[no-]per-session-storage</td><td>false</td><td>true</td><td>Use ephemeral local storage for each session. It enables you to run multiple local clients concurrently. However: if you wish to run just one client at a time, then you will get a performance boost if you negate this flag.</td></tr><tr><td>-k, --key-file, --keyFile</td><td>false</td><td>~/.atsign/keys</td><td>Path to this client's atsign key file.</td></tr></tbody></table>

## Examples

#### -h, --rh, --remote-host&#x20;

This argument is the remote host. It is **NOT** required, this options defaults to localhost.&#x20;

```bash
npt ... -h 192.168.x.x ...
```

#### -x,  --exit-when-connected

This argument, forks the srv when connected.&#x20;

```bash
npt ... -x ...
```

#### --\[no-]pps,  --\[no-]per-session-storage

This argument defaults to true. It is used for when you want to run only one client at a time.

```bash
npt ... --no-pps ...
```

#### -k, --keyFile, --key-file

This argument defaults to \~/.atsign/keys, where your keys are stored.&#x20;

```bash
npt ... -k /path/to/atKeys ...
```
