# policy_tests

Client: v5.11.2, v5.13.0, v5.15.0, current
Daemons: v5.11.2, v5.13.0, v5.15.0, current
Policy: v5.13.0 (npp_atserver), current (npp)

1. try a session with no rules in place for the client - verify denied
2. try a session with rules in place for the client but not for the required port - verify denied
3. try a session with rules in place for the client which cover the required port - verify permitted
4. try a session where allowed by policy but restricted by daemon's permitOpen - verify denied

