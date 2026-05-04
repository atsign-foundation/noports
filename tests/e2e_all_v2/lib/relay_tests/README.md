# relay_tests

Client: v5.11.2, v5.13.0, v5.15.0, current
Daemons: v5.11.2, v5.13.0, v5.15.0, current
Relay: v5.15.0, current

- npt to daemon through prod relay (verify pass)
- npt to daemon through self-ran relay (verify pass)
- npt to daemon through prod relay using new ESCR auth mechanism (verify pass)
- npt to daemon through self-ran relay using new ESCR auth mechanism (verify pass)

Self-run relay cases must use distinct relay atSigns because each `srvd`
subscribes to request notifications for its atSign. Pass them with
`--self-relay-atsigns`; each self relay version consumes three atSigns:
payload, ESCR, and ESCR over `--443`.

Example:

```sh
--self-relay-versions d:current \
--self-relay-atsigns @relay_payload,@relay_escr,@relay_escr443
```

## Command to run

```bash
dart run tests/e2e_all_v2/bin/relay_tests.dart \
    --client-atsign "@client_jttest" \
    --daemon-atsign "@daemon_jttest" \
    --prod-relay-atsign "@rv_am" \
    --self-relay-atsigns "@qt_app,@qt_app_2,@qt_plant,@qt_beer" \
    --root-domain "root.atsign.org" \
    --base-directory "npe2e_relay" \
    --client-versions "d:curent" \
    --daemon-versions "d:current" \
    --self-relay-versions "d:v5.10.0,d:current" \
    --batch-size 2
```
