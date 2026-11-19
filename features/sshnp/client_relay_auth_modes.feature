Feature: The client tells the relay both sides' relay auth modes when it asks for ports
  npt, sshnp and NoPorts Desktop name both sides' relay auth modes in
  request_ports, in relayAuthModes. The client takes the daemon's ESCR support
  from a record of the daemon's last ping response on the client's own
  atServer; without one, it waits for the live ping before asking the relay.
  The live ping still runs on every session. When it contradicts the record
  in a way that matters, the client corrects the record and fails that
  attempt before the daemon is asked for anything; the next attempt uses the
  live answer.

  @race: the live ping and the relay request overlap only when a record
  exists. A contradiction between them ends the attempt before the daemon
  request is sent. Two of the client's installations writing the record at once both
  write a recent response.
  @replay: a record older than the daemon's current state is caught by the
  live ping on the same session. That the live ping reply carries no nonce
  predates this feature.
  @dos: a contradicted record costs one abandoned relay session, whose ports
  the relay releases at its own limit. A record is written at most once a week
  per daemon device unless the daemon's answer changes.
  @forgery: the record is a self record on the client's atServer, which only
  the holder of the client's keys can write; that holder already controls
  every session the record affects. The live ping is accepted only from the
  daemon's Atsign, as before.
  @impersonation: the record is keyed by the daemon's Atsign and device name,
  so one daemon's answer never decides another's mode.

  Scenario: With no record, the client asks the relay only after the ping returns
    Given no ping record for the device on the client's atServer
    And the daemon supports ESCR
    When the client starts a session with the default relay auth mode
    Then the client sends request_ports only after the daemon's ping response arrives
    And request_ports has relayAuthModes naming ESCR for side A and ESCR for side B

  Scenario: With no record and no ping response, the client never asks the relay
    Given no ping record for the device on the client's atServer
    And the daemon does not answer the ping
    When the client starts a session
    Then the session fails with the ping timeout
    And the client sends no request_ports

  Scenario: With a record, the client asks the relay without waiting for the ping
    Given a ping record for the device saying the daemon supports ESCR
    And the daemon's live ping agrees
    When the client starts a session with the default relay auth mode
    Then the client sends request_ports before the daemon's ping response arrives
    And request_ports has relayAuthModes naming ESCR for side A and ESCR for side B

  Scenario: The record's signing key URI still tells the relay what to prefetch
    Given a ping record for the device holding the daemon's publicSigningKeyUri
    When the client starts a session with the default relay auth mode
    Then request_ports has that publicSigningKeyUri in preFetch

  Scenario: A daemon without ESCR gets legacy on its side only
    Given a ping record for the device saying the daemon does not support ESCR
    And the daemon's live ping agrees
    When the client starts a session with the default relay auth mode
    Then request_ports has relayAuthModes naming ESCR for side A and legacy for side B
    And the session request to the daemon has relayAuthMode payload

  Scenario: A daemon whose ping names no features gets legacy on its side
    Given no ping record for the device on the client's atServer
    And the daemon's ping response has no supportedFeatures
    When the client starts a session with the default relay auth mode
    Then request_ports has relayAuthModes naming legacy for side B

  Scenario: An explicit ESCR request with a daemon without ESCR uses ESCR on the client's side only
    Given a ping record for the device saying the daemon does not support ESCR
    And the daemon's live ping agrees
    And the relay's response has appliedRelayAuthModes true
    When the client starts a session with --relay-auth-mode escr
    Then request_ports has relayAuthModes naming ESCR for side A and legacy for side B

  Scenario: An explicit payload request names legacy for both sides
    When the client starts a session with --relay-auth-mode payload
    Then request_ports has relayAuthModes naming legacy for both sides

  Scenario: A 443 request names ESCR for both sides
    When the client starts a session with --only-port 443
    Then request_ports has relayAuthModes naming ESCR for both sides

  Scenario: Every request still carries the mode for relays that apply one mode to both sides
    When the client starts a session with the default relay auth mode
    Then request_ports also has relayAuthMode payload

  Scenario: A relay that applies one mode to both sides gets it on both sides
    Given the relay's response has neither appliedRelayAuthModes nor autoDetectsRelayAuth
    When the client starts a session with the default relay auth mode
    Then the client authenticates its own socket as legacy
    And the session request to the daemon has relayAuthMode payload

  Scenario: A relay that applied relayAuthModes is sent no auth_modes notification
    Given the relay's response has appliedRelayAuthModes true
    When the daemon's ping response arrives
    Then the client sends the relay no auth_modes notification

  Scenario: A relay that auto-detects without applying relayAuthModes is still sent auth_modes
    Given a ping record for the device saying the daemon supports ESCR
    And the relay's response has autoDetectsRelayAuth true and no appliedRelayAuthModes
    When the daemon's ping response arrives
    Then the client sends the relay an auth_modes notification naming both sides' modes

  Scenario: The ping response is recorded on the client's own atServer
    Given no ping record for the device on the client's atServer
    When the daemon's ping response arrives
    Then the client writes the record cached.ping.<daemon>.<device>.sshnp on its own atServer
    And the record holds supportsRamEscr, publicSigningKeyUri and storedAt
    And has a 30-day ttl

  Scenario: An unchanged recent record is not rewritten
    Given a ping record for the device stored 2 days ago
    And the daemon's live ping gives the same supportsRamEscr and publicSigningKeyUri
    When the daemon's ping response arrives
    Then the client does not write the record

  Scenario Outline: A record is rewritten when it changed or is a week old
    Given a ping record for the device stored <age> ago
    And the daemon's live ping gives <answer>
    When the daemon's ping response arrives
    Then the client writes the record with the live answer

    Examples:
      | age    | answer                                           |
      | 2 days | a different publicSigningKeyUri                  |
      | 8 days | the same supportsRamEscr and publicSigningKeyUri |

  Scenario Outline: A record that cannot be used is treated as absent
    Given the ping record for the device <defect>
    When the client starts a session
    Then the client sends request_ports only after the daemon's ping response arrives

    Examples:
      | defect                                 |
      | cannot be read from the atServer       |
      | holds a value that cannot be decoded   |

  Scenario: No record is written after a failed read
    Given the client's atServer fails the read of the ping record
    When the daemon's ping response arrives
    Then the client does not write the record

  @impersonation
  Scenario Outline: Another daemon's record is not used
    Given a ping record for <other>
    And no ping record for this device
    When the client starts a session to this device
    Then the client sends request_ports only after this device's ping response arrives

    Examples:
      | other                                         |
      | a different device of the same daemon Atsign  |
      | the same device name under another Atsign     |

  Scenario: A record that undersells the daemon is corrected without asking the relay again
    Given a ping record for the device saying the daemon does not support ESCR
    And the daemon now supports ESCR
    When the client starts a session with the default relay auth mode
    Then request_ports has relayAuthModes naming legacy for side B
    And the client sends request_ports once
    And the record now says the daemon supports ESCR

  Scenario: A contradicted record causes no second request to a relay that did not apply relayAuthModes
    Given a ping record for the device saying the daemon supports ESCR
    And the daemon no longer supports ESCR
    And the relay's response has no appliedRelayAuthModes
    When the client starts a session with the default relay auth mode
    Then the client sends request_ports once
    And the record now says the daemon does not support ESCR

  Scenario Outline: A record the live ping contradicts fails the attempt before the daemon is asked
    Given a ping record for the device saying the daemon <recorded>
    And the daemon <now>
    And the relay's response has appliedRelayAuthModes true
    When the client starts a session with <mode>
    Then the session fails, saying the daemon's relay auth support changed since it was last seen
    And the daemon receives no session request
    And the record now says what the live ping said

    Examples:
      | recorded              | now                     | mode                        |
      | supports ESCR         | no longer supports ESCR | the default relay auth mode |
      | supports ESCR         | no longer supports ESCR | --relay-auth-mode escr      |
      | does not support ESCR | now supports ESCR       | --relay-auth-mode escr      |

  Scenario: The next attempt in the same process uses the live answer even if the record was not rewritten
    Given an attempt in this process failed because the record said the daemon supports ESCR and the live ping said not
    And the client's atServer refused the record's rewrite
    When the client starts the next session to the device
    Then request_ports has relayAuthModes naming legacy for side B
