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

4. Case 4: normal to 443 (expect success, relay still supports non-standard
   ports)
`npt -f client -t daemon -r relay --rp 22`
`srvd -a relay -v --ip <Ip> --443`

## Command to run

```bash
docker rm -f $(docker ps -aq --filter name=^npe2e_) 2>/dev/null
rm -rf npe2e_relay_tests/
dart run tests/npe2e/bin/relay_tests.dart \
    --client-atsign "@chris" \
    --daemon-atsign "@gareth" \
    --prod-relay "@relay1" \
    --self-relay-atsigns "@gary,@relay2,@policy2,@cloudvm1,@colin,@barbara" \
    --root-domain "vip.ve.atsign.zone" \
    --base-directory "npe2e_relay_tests" \
    --client-versions "d:v5.13.0,d:v5.14.13,d:current" \
    --daemon-versions "d:v5.13.0,d:v5.14.13,d:current" \
    --self-relay-versions "d:v5.10.0,d:v5.14.13,d:current" \
    --batch-size 5
```
