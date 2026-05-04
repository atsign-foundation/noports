# policy_tests

Client: current
Daemons: current
npp_atserver: v5.13.0
npp: current

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
   2c. Verify failed because because permitOpen is localhost:22 and also policy rule is for localhost:222 (wrong port)

3. try a session with rules in place for the client which cover the required port - verify permitted
   3a. Place policy rules for @client, but for localhost:22
   3b. Run `npt --rp 22`
   3c. Verify success because there's policy in place for localhost:22 for @client, and also sshnpd has permit open localhost:22

4. try a session where allowed by policy but restricted by daemon's permitOpen - verify denied
   4a. Place policy rules for @client, but for localhost:2233
   4b. Run `npt --rp 2233`
   4c. Verify fail because the policy rules are localhost:22, localhost:222, and lolcahost:2233, but permitOpen is only localhost:22 on sshnpd

5. Tear down `npp_atserver|npp` rules

regarding 2a, 3a, and 4a:

- depending on if we're running `npp_atserver` or `npp`, there is a different way of putting policy rules in place.

## Placing policy rules for npp_atserver

Hints:

~/GitHub/policy_temp/npp_atserver

## Placing policy rules for npp

Hints:

~/GitHub/policy_temp/npp

- manage a living document of context , a plan a record, shows current state, weaknesses, comparisons and similarities
- assessments
- virtualenv
- ~/AGENTS.md
