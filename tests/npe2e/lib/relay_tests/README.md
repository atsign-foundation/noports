# relay_tests

## Test Coverage

Daemon remains the same sshnpd -a @daemon -m @client -s -v

(Client, Relay)

1. Case 1: normal to normal (expect success)
`npt -f client -t daemon -r relay --rp 22`
`srvd -a relay -v --ip <Ip>`

2. Case 2: 443 to normal (expect failure, relay does not support 443 mode)
`npt -f client -t daemon -r relay --rp 22 --443 --ram escr`
`srvd -a relay -v --ip <Ip>`

3. Case 3: 443 to 443 (expect success)
`npt -f client -t daemon -r relay --rp 22 --443 --ram escr`
`srvd -a relay -v --ip <Ip> --443`

4. Case 4: normal to 443 (expect success, relay still supports non-standard ports)
`npt -f client -t daemon -r relay --rp 22`
`srvd -a relay -v --ip <Ip> --443`

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
