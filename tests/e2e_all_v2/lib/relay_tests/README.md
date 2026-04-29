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
