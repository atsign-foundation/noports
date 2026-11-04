Feature: npp_client says why the policy atSign could not be opened

  npp_client opens the atSign -a names from its atKeys file as the other
  NoPorts CLIs do, and when it cannot, says which it was: the atServer
  refused the keys, naming the cause from at_client's fixed set (revoked,
  enrollmentDenied, invalidEnrollment, unauthenticated, ...) followed by the
  atServer's error; the atDirectory has no atServer for the atSign; or the
  atServer could not be reached within the budget. It exits 1 and stops any
  client it opened.

  Races: none; one open per run.
  Replay: none; nothing is sent but the authentication.
  DoS: the unreachable path waits at most the budget, as sshnp does.
  Forgery: the cause is a name from at_client's fixed set, answered by the
  atSign's own atServer over verified TLS; the atServer's text follows the
  cause on the same line and is never printed as npp_client's own words.
  Impersonation: only the atSign -a names is opened; nothing acts on a
  refused client.

  Scenario: An atSign the atServer refuses after it has been online is reported refused
    Given a store for @policy that has been online, and an enrollment the atServer now reports revoked
    When npp_client -a @policy runs
    Then stderr says "Unable to authenticate @policy: the atServer refused it (revoked): " followed by the atServer's error, and it exits 1

  Scenario: An atSign the atServer refuses on this device's first open is reported refused
    Given no store for @policy on this device, and keys the atServer refuses
    When npp_client -a @policy runs
    Then stderr says the atServer refused @policy, naming the cause, and it exits 1

  Scenario: An atSign with no atServer in the atDirectory is reported as not found
    Given an atDirectory with no atServer for @policy
    When npp_client -a @policy runs
    Then stderr says "@policy is not in the atDirectory at <root>: check the atSign, and that it has been activated", not that it was refused, and it exits 1

  Scenario: An atSign whose atServer cannot be reached is reported unreachable
    Given an atServer for @policy that cannot be reached
    When npp_client -a @policy runs
    Then stderr says "@policy could not connect to its atServer within 15 seconds: offline (unreachable)" followed by the error, not that it was refused, and it exits 1
