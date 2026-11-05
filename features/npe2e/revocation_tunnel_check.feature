Feature: The revocation pack's checks reach the npt they started

  Every npt the pack starts is told to listen on 127.0.0.1, and every check
  connects there, so a check reaches npt even when another listener, such as
  one of srvd's, holds the same port number on another address. npt's own
  default, localhost, resolves to ::1 first on macOS, where a check connecting
  to localhost lands on 127.0.0.1 and reads whatever holds that port there.
  Where the platform refuses npt's stand-in the port beside srvd's, a scenario
  is skipped and says so, never passed on another port.

  Races: none; each listener holds its port for the scenario's life.
  Replay: none; nothing is sent but a banner.
  DoS: two loopback listeners per scenario.
  Forgery: the check accepts only a chunk carrying "SSH-", which srvd's relay
  auth challenge never carries; the stand-in writes that challenge.
  Impersonation: none; every connection is loopback.

  Scenario: The banner check reaches npt when srvd holds the same port number on IPv4
    Given a stand-in for srvd listening on every IPv4 address on port P, and a stand-in for npt listening where the pack tells npt to listen, on P
    When the pack checks the banner on P
    Then it reads sshd's banner from npt, never srvd's challenge

  Scenario: The banner check reaches npt when srvd holds the same port number on IPv6
    Given a stand-in for srvd listening on ::1 only on port P, and a stand-in for npt listening where the pack tells npt to listen, on P
    When the pack checks the banner on P
    Then it reads sshd's banner from npt, never srvd's challenge
