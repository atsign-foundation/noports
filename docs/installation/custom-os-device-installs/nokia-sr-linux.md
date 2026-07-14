---
description: NoPorts as a native feature of the Nokia SR Linux network OS
icon: router
---

# Nokia SR Linux

NoPorts runs on Nokia [SR Linux](https://learn.srlinux.dev) routers as a
**native application**, built with the SR Linux NetOps Development Kit
(NDK) and listed in Nokia's official
[NDK App Catalog](https://learn.srlinux.dev/ndk/apps/noports/). Unlike a
generic Linux install, everything is managed the way router operators
expect:

* Configuration lives in the **router's own config tree** (CLI, gNMI, or
  JSON-RPC) with candidate/commit/rollback semantics — no env files, no
  hand-managed daemons
* Operational state (`oper-state`, PID, daemon version) is published into
  the state tree and streams over gNMI telemetry
* Device keys are cut **on the router** with APKAM enrollment — no atKeys
  files are ever copied to the device
* The daemon runs in the management VRF and is supervised (restarted,
  reconfigured on commit) by the NDK agent

Source, releases and full documentation:
[atsign-foundation/noports-srlinux](https://github.com/atsign-foundation/noports-srlinux).

### Requirements

* SR Linux 24.3.1 or later (Debian-based releases); amd64 or arm64
* Two Atsigns: one for the router, one for the operator — see
  [noports.com](https://noports.com)
* The NoPorts client installed on your machine (see
  [Client Installation](../advanced-installation-guides/client-installation-sshnp.md))

{% hint style="info" %}
No router hardware? The
[repo quickstart](https://github.com/atsign-foundation/noports-srlinux/blob/trunk/QUICKSTART.md)
includes two free virtual labs using Nokia's public SR Linux container
image: a [containerlab](https://containerlab.dev) topology, and a
standalone plain-Docker variant that runs natively on Apple Silicon.
{% endhint %}

### Install

Download the `.deb` (amd64 and arm64) from the
[releases page](https://github.com/atsign-foundation/noports-srlinux/releases),
copy it to the router, then from the SR Linux CLI drop to the shell with
`bash`:

```bash
sudo dpkg -i noports-srlinux_*.deb   # postinstall reloads app_mgr
```

### Configure from the SR Linux CLI

```
enter candidate
set / noports device-atsign @mydevice
set / noports access managers [ @manager ]
set / noports device name srl-router-1
set / noports admin-state enable
commit now
save startup
```

Check what the agent thinks:

```
info from state / noports state
```

Until the router is onboarded it reports `oper-state awaiting-onboarding`.
The full command surface — policy Atsigns for fleet-scale access control,
device groups, permit-open lists for `npt`, sshd options — is documented in
the repo's
[CLI reference](https://github.com/atsign-foundation/noports-srlinux/blob/trunk/docs/cli-reference.md).

### Onboard the router (APKAM)

Enrollment cuts new, scope-limited APKAM keys on the router itself, using
a one-time passcode; the device Atsign's full keys never leave your
custody.

On your machine:

```bash
at_activate otp -a @mydevice
```

On the router (bash shell):

```bash
sudo /opt/noports/onboard-noports.sh <passcode>
```

While it waits, approve from your machine:

```bash
at_activate approve -a @mydevice --arx noports --drx srl-router-1
```

The agent detects the new keys within about 15 seconds and starts the
daemon — `info from state / noports state` shows `oper-state running`.

### Connect

```bash
sshnp -f @manager -t @mydevice -d srl-router-1 -u admin
```

You can also tunnel gNMI (or NETCONF/JSON-RPC) without SSH — add the port
to the permit-open list first
(`set / noports access permit-open [ localhost:22 localhost:57400 ]`):

```bash
npt -f @manager -t @mydevice -d srl-router-1 -r localhost -p 57400 -l 57400
gnmic -a localhost:57400 -u admin --skip-verify capabilities
```

### Networks that only allow outbound 443

Management VRFs are often restricted to well-known outbound ports. Both
sides of NoPorts can be pinned to 443 — this exact combination is verified
end-to-end on SR Linux:

On the router (before onboarding, so enrollment uses it too):

```
set / noports root-server proxy:proxy0001.atsign.org:443
```

On the client, add `--443` so the relay data path also uses 443:

```bash
sshnp -f @manager -r @rv_oc -t @mydevice -d srl-router-1 -u admin \
  --443 --relay-auth-mode escr \
  --root-domain "proxy:proxy0001.atsign.org:443"
```

{% hint style="info" %}
NoPorts device packages also exist for **Cisco IOS-XE** app hosting
([noports-iosxe](https://github.com/atsign-foundation/noports-iosxe)) and
**Junos OS Evolved** containers
([noports-junos-evolved](https://github.com/atsign-foundation/noports-junos-evolved)).
{% endhint %}
