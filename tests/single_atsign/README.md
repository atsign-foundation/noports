# One atSign in every role

NoPorts lets one atSign be the client, the daemon, the policy service, the
relay and the events service at once. The unit harness checks this against a
fake atServer
(`packages/dart/noports_core/test/harness/single_atsign_test.dart`), asserting
the exact notifications the atSign receives at start-up and in a session. This
page does the same check by hand, with the compiled binaries and a local
atServer: worth doing after changing what any of them subscribes to or sends.

## What you need

- Docker, the Dart SDK, `curl` and `python3`.
- `127.0.0.1 vip.ve.atsign.zone` in `/etc/hosts`.
- A local virtual environment (VE): `tests/tools/ve/setup_ve.sh ve_single`
  starts one on host ports 64 and 25000 to 25039, so not beside another VE,
  and puts its demo atKeys in `~/.atsign/keys`, skipping any keyfile already
  there. The steps below use its `@colin`.

Run every command from the repo root.

## 1. Build the binaries

```bash
cd packages/dart/sshnoports
dart pub get
mkdir -p build/single
for b in sshnpd srv npt srvd npp_file npevents; do
  dart compile exe "bin/$b.dart" -o "build/single/$b"
done
cd ../../..
```

`sshnpd` starts `srv` from its own directory, so build them side by side.

## 2. Write a policy that lets `@colin` use its own device

Save this as `packages/dart/sshnoports/build/single/rules.yaml`:

```yaml
userGroups:
  "everyone":
    userAtSigns:
      - "@colin"
    permissions:
      daemonAtSigns:
        - "@colin"
      deviceNames:
        "single":
          - "127.0.0.1:8080"
```

## 3. Start every role as `@colin`

From here on, give each command a terminal of its own, since most run until
they are stopped, and in each one first set:

```bash
B=$PWD/packages/dart/sshnoports/build/single
```

An HTTP server, as something to reach through the tunnel:

```bash
mkdir -p /tmp/single_www && echo 'hello from @colin' > /tmp/single_www/index.html
python3 -m http.server 8080 --bind 127.0.0.1 --directory /tmp/single_www
```

The events service, which must log `Shared AtEventLogger config` before the
policy service starts, since `npp_file` reads that config when it starts and
exits if it isn't there yet:

```bash
$B/npevents -a @colin -A @colin --root-server vip.ve.atsign.zone -v
```

The policy service, the relay and the daemon:

```bash
$B/npp_file -a @colin -l @colin --yaml $B/rules.yaml \
  --root-server vip.ve.atsign.zone -v
```

```bash
$B/srvd -a @colin -i 127.0.0.1 --root-server vip.ve.atsign.zone -v
```

```bash
$B/sshnpd -a @colin -p @colin -d single --permit-open 127.0.0.1:8080 \
  --root-server vip.ve.atsign.zone -v
```

The steps name the HTTP server as `127.0.0.1` rather than `localhost`, because
`sshnpd`'s side of a session connects only to the first address a host name
resolves to, and for `localhost` that may be `::1`, where this server isn't
listening. Each binary keeps its local storage in its own directory under
`~/.atsign/storage/@colin/`, so they can run side by side.

## 4. Watch `@colin`'s notifications

In another terminal:

```bash
(cd tests/npe2e && dart pub get)
dart run tests/npe2e/bin/watch_notifications.dart -a @colin -s /tmp/watch_colin \
  --root-server vip.ve.atsign.zone --seconds 240 --interval 20
```

It prints each notification `@colin` receives, and how many arrived in each
20 seconds, counting from when it has connected. Started after the roles, it
misses most of their start-up notifications.

## 5. Open a session

In another terminal, with `B` set as in step 3:

```bash
$B/npt -f @colin -t @colin -d single -r @colin --rh 127.0.0.1 --rp 8080 \
  --lp 9090 --root-server vip.ve.atsign.zone
```

Once it prints `npt is listening on localhost:9090`, from another terminal:

```bash
curl http://localhost:9090/
```

`npt` listens on `localhost`, which may be `::1` rather than `127.0.0.1`. The
session ends 30 seconds after it starts, or when its last connection closes if
that is later, so run `curl` within those 30 seconds.

To compare with the counts in step 6, open a second session the same way about
20 seconds after the first ends. Sessions less than 15 seconds apart bring
fewer notifications, since the daemon reuses the policy service's answer for
15 seconds.

## 6. Read the result

`curl` printing the HTTP server's page shows the session carried data. With
no cascade, `@colin`'s count jumps while a session runs, then falls back to the
atServer's own `statsNotification`s, one or two every 20 seconds. A cascade
shows as a count that keeps climbing after the session ends, such as the same
key arriving again and again.

For comparison: two runs on a VE at `77c53e21d` (2026-10-15), each watching
for 240 seconds, with sessions opened 40 and 90 seconds after launching the
watcher, counted 56 notifications each. Per 20 seconds that was 1, 21, 1, 2,
21, 2, 1, 2, 1, 1, 2, 1 in the first run and 1, 20, 2, 2, 20, 3, 1, 1, 2, 1, 1,
2 in the second. Each session brought 18: 12 session messages and 6 on the
events topic. The other 20 were `statsNotification`s. With the policy service
also logging each policy check to the events topic, a session brings 19, 7 of
them on that topic.

## Tear down

Stop each process, then run `tests/tools/ve/teardown_ve.sh ve_single`. To
start again from nothing, also remove `~/.atsign/storage/@colin`,
`/tmp/watch_colin` and `/tmp/single_www`.
