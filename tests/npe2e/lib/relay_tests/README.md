# relay_tests

Client: v5.11.2, v5.13.0, v5.15.0, current
Daemons: v5.13.0, v5.14.13, current
Relay: v5.15.0, current

- one daemon container is started per daemon version
- two relay containers are started per relay version:
  one normal `srvd`, and one `srvd --443`
- each daemon is bootstrapped once with `001_minus_s_flag`, using a `d:current`
  client and the first normal self-run relay
- each client/daemon/relay version permutation runs four fixed `npt` cases:
  normal to normal (pass), 443 to normal (fail), 443 to 443 (pass), and
  normal to 443 (pass)
- shared startup and client execution logic lives in `relay_test_flow_shared.dart`;
  each fixed case is defined in its own file under `tests/`

Self-run relay cases must use distinct relay atSigns because each `srvd`
subscribes to request notifications for its atSign. Pass them with
`--self-relay-atsigns`; each self relay version consumes two atSigns:
one for `srvd`, and one for `srvd --443`.

Example:

```sh
--self-relay-versions d:current \
--self-relay-atsigns @relay_payload,@relay_escr443
```

## Command to run

```bash
docker stop $(docker ps -q) 2>/dev/null ; rm -rf npe2e_relay/ &&  dart run tests/npe2e/bin/relay_tests.dart \
    --client-atsign "@client_jttest" \
    --daemon-atsign "@device_jttest" \
    --prod-relay "@rv_am" \
    --self-relay-atsigns "@soccer0,@soccer99,@qt_app,@qt_app_2,@qt_plant,@qt_beer" \
    --root-domain "root.atsign.org" \
    --base-directory "npe2e_relay" \
    --client-versions "d:v5.13.0,d:v5.14.13,d:current" \
    --daemon-versions "d:v5.13.0,d:v5.14.13,d:current" \
    --self-relay-versions "d:v5.10.0,d:v5.14.13,d:current" \
    --batch-size 5
```
