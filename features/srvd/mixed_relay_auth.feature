Feature: srvd verifies each side of a tunnel in the relay auth mode that side speaks

  A relay that auto-detects verifies each socket in the mode its sender speaks:
  ESCR for a current client, legacy for a daemon released before v5.10.0, which
  predates ESCR. e2e_all runs both through a relay built from the branch and
  reads the relay's own log of each socket it verified.

  Races: the client's auth-modes hint and each socket race to the relay; the
  scenarios assert the mode each side was verified in, whichever settled it,
  and the test logs which did. Replay: unchanged; each connection's challenge
  is fresh, which the unit tests pin. DoS: none added; the test reads a log
  file. Forgery and impersonation: unchanged; the test reads what the relay
  recorded about sockets it had already verified, and adds nothing the relay
  trusts.

  Scenario: A current client and a daemon that predates ESCR are each verified in their own mode
    Given a relay built from the branch, which auto-detects relay auth
    And a Dart daemon from release v5.9.4
    When the current npt client opens a tunnel to that daemon through the relay
    Then the relay has verified at least one socket on each side of the session
    And every client-side socket by ESCR, and every daemon-side socket by legacy

  Scenario Outline: A current client and a daemon that supports ESCR are both verified by ESCR
    Given a relay built from the branch, which auto-detects relay auth
    And a <daemon> daemon
    When the current npt client opens a tunnel to that daemon through the relay
    Then the relay has verified at least one socket on each side of the session
    And every one of them by ESCR

    Examples:
      | daemon                     |
      | Dart v5.11.2               |
      | Dart v5.13.0               |
      | Dart built from the branch |
      | C built from the branch    |
