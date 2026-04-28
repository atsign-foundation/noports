# policy_tests

Client: current
Daemons: current
npp_atserver: v5.13.0
npp: current

test01_basic_test.dart
0. Set up actors
0a. Run `npp_atserver|npp -a <policy_atsign> -v`
0b. Run `sshnpd -a <atsign> -p <policy_atsign> --permit-open "localhost:22"`
0c. Tear down `npp_atserver|npp` rules

1. try a session with no rules in place for the client - verify denied
1a. Run `npt`
1b. Verify fail

2. try a session with rules in place for the client but not for the required port - verify denied
2a. Place policy rules for @client, but for localhost:222
2b. Run `npt --rp 22`
2c. Verify fail

3. try a session with rules in place for the client which cover the required port - verify permitted
3a. Place policy rules for @client, but for localhost:22
3b. Run `npt --rp 22`
3c. Verify success

4. try a session where allowed by policy but restricted by daemon's permitOpen - verify denied
4a. Place policy rules for @client, but for localhost:2233
4b. Run `npt --rp 2233`
4c. Verify fail

5. Tear down `npp_atserver|npp` rules

regarding 2a, 3a, and 4a:
- depending on if we're running `npp_atserver` or `npp`, there is a different way of putting policy rules in place.


```bash
docker stop $(docker ps -q) 2>/dev/null ; \
    rm -rf npe2e_policy/ && \
    dart run tests/e2e_all_v2/bin/policy_tests.dart \
        --client-atsign "@client_jttest" \
        --daemon-atsign "@device_jttest" \
        --relay-atsign "@rv_am" \
        --npp-atsign "@policy01_jttest" \
        --npp-atserver-atsign "@policy02_jttest" \
        --base-directory "npe2e_policy" \
        --root-domain "root.atsign.org:64" \
        --batch-size 3
```
