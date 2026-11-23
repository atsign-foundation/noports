Feature: The relay takes each socket's relay auth mode from what the client told it
  The relay decides how to authenticate each socket of a session from the
  session request and, where the request defers side B, from the requesting
  client's auth_modes notification. It never decides from how long a socket
  stays silent.

  @race: the auth_modes notification and the daemon's socket travel by
  different transports. A socket that arrives first waits for the client's
  word; arrival order never changes the mode, and a socket that has already
  committed to a mode keeps it.
  @replay: every ESCR socket gets its own challenge, as before. A legacy
  envelope is the same for every socket of its session; that is legacy's own
  property, and the relay accepts legacy only on a side the client named or
  deferred.
  @dos: a socket waiting for the client's word is held no longer than the
  relay's authentication limit and is sent nothing. A stranger's socket on a
  session port cannot take the client's word from the daemon's socket. A
  request naming ESCR without a relayAuthAesKey, or with an invalid
  relayAuthModes, is refused before any port is allocated.
  @forgery: only the session's requester can set a mode, in its request or in
  its auth_modes notification; the relay checks the sender of both. A
  malformed request is refused before its sender is checked, and the refusal
  goes only to that sender.
  @impersonation: a mode decides how a socket proves its Atsign, never which
  Atsign it must prove.

  Scenario Outline: A request that names both sides' modes is applied as given
    Given a session request whose relayAuthModes names <sideA> for side A and <sideB> for side B
    When the client and the daemon each connect and authenticate by the mode named for their side
    Then the relay verifies the client's socket by <sideA> and the daemon's socket by <sideB>

    Examples:
      | sideA  | sideB  |
      | ESCR   | ESCR   |
      | ESCR   | legacy |
      | legacy | legacy |
      | legacy | ESCR   |

  Scenario: The relay says when it applied relayAuthModes
    Given a session request whose relayAuthModes names ESCR for both sides
    When the relay answers it
    Then its response has appliedRelayAuthModes true
    And its response has autoDetectsRelayAuth true

  Scenario: A request without relayAuthModes gets no appliedRelayAuthModes
    Given a session request with no relayAuthModes
    When the relay answers it
    Then its response has no appliedRelayAuthModes
    And its response has autoDetectsRelayAuth true

  @dos
  Scenario Outline: A request with an invalid relayAuthModes is refused before any port is allocated
    Given a session request whose relayAuthModes is <invalid>
    When the relay receives it
    Then the relay allocates no ports for it
    And sends a NACK if the request accepts one

    Examples:
      | invalid                                         |
      | not a map                                       |
      | missing sideB                                   |
      | naming a mode that does not exist for side A    |
      | naming ESCR for a side, with no relayAuthAesKey |

  Scenario Outline: A request without relayAuthModes is applied to both sides
    Given a session request with relayAuthMode <relayAuthMode>, <key>, and no relayAuthModes
    When the client and the daemon each connect and authenticate by <mode>
    Then the relay verifies both sockets by <mode>

    Examples:
      | relayAuthMode | key                | mode   |
      | payload       | no relayAuthAesKey | legacy |
      | escr          | a relayAuthAesKey  | ESCR   |

  @race
  Scenario: A request for payload without a key accepts slow legacy envelopes on both sides
    Given a session request with relayAuthMode payload, no relayAuthAesKey, and no relayAuthModes
    When the client's socket and the daemon's socket each send their signed envelope 5 seconds after connecting
    Then the relay verifies both sockets as legacy
    And has sent neither socket anything before its envelope

  Scenario: A request for ESCR whose daemon sends a legacy envelope has that socket refused
    Given a session request with relayAuthMode escr, a relayAuthAesKey, and no relayAuthModes
    When the daemon's socket connects and sends a signed legacy envelope
    Then the relay refuses the daemon's socket

  Scenario: A request for payload with a key has its client's socket challenged at once
    Given a session request with relayAuthMode payload, a relayAuthAesKey, and no relayAuthModes
    When the client's socket connects
    Then the relay sends it a challenge without waiting

  @impersonation
  Scenario: A legacy envelope on a client socket the request makes ESCR is refused
    Given a session request with relayAuthMode payload, a relayAuthAesKey, and no relayAuthModes
    When the client's socket connects and sends a signed legacy envelope
    Then the relay refuses the client's socket

  Scenario: The daemon's silent socket is challenged only once the client says ESCR
    Given a session request with relayAuthMode payload, a relayAuthAesKey, and no relayAuthModes
    And the daemon's socket has connected and sent nothing
    When the client's auth_modes notification for the session names ESCR for side B
    Then the relay sends the daemon's socket a challenge

  @race
  Scenario: A legacy daemon whose envelope is slow is still verified as legacy
    Given a session request with relayAuthMode payload, a relayAuthAesKey, and no relayAuthModes
    And the client's auth_modes notification has named legacy for side B
    When the daemon's socket connects and sends its signed envelope 5 seconds later
    Then the relay verifies the daemon's socket as legacy
    And has sent it nothing before the envelope

  Scenario: A daemon's envelope that arrives before the client's word is verified as legacy
    Given a session request with relayAuthMode payload, a relayAuthAesKey, and no relayAuthModes
    And no auth_modes notification has arrived
    When the daemon's socket connects and sends its signed envelope
    Then the relay verifies the daemon's socket as legacy

  @race
  Scenario: The client's word does not re-mode a socket that has already committed
    Given a session request with relayAuthMode payload, a relayAuthAesKey, and no relayAuthModes
    And the daemon's socket has sent its signed envelope
    When the client's auth_modes notification names ESCR for side B
    Then the relay sends the daemon's socket no challenge
    And verifies it as legacy

  Scenario: A daemon socket whose first byte is neither silence nor an envelope is refused
    Given a session request with relayAuthMode payload, a relayAuthAesKey, and no relayAuthModes
    When the daemon's socket connects and sends a first byte that is not "{"
    Then the relay refuses the daemon's socket

  @dos
  Scenario: A daemon socket the client never speaks for is never challenged
    Given a session request with relayAuthMode payload, a relayAuthAesKey, and no relayAuthModes
    And no auth_modes notification arrives
    When the daemon's socket connects and sends nothing
    Then the relay sends it nothing
    And closes it when the authentication limit expires

  @race @dos
  Scenario: The client's word reaches every socket waiting on that side
    Given a session request with relayAuthMode payload, a relayAuthAesKey, and no relayAuthModes
    And two sockets have connected to the daemon's port and sent nothing
    When the client's auth_modes notification names ESCR for side B
    Then the relay sends a challenge to both sockets

  Scenario: A socket that connects after the client's word gets its mode at once
    Given a session request with relayAuthMode payload, a relayAuthAesKey, and no relayAuthModes
    And the client's auth_modes notification has named ESCR for side B
    When the daemon's socket connects
    Then the relay sends it a challenge without waiting

  Scenario: An auth_modes notification does not change a mode the request set
    Given a session request whose relayAuthModes names ESCR for both sides
    And the client's auth_modes notification has named legacy for side B
    When the daemon's socket connects and sends nothing
    Then the relay sends it a challenge

  @impersonation
  Scenario: A legacy envelope on a side named ESCR is refused
    Given a session request whose relayAuthModes names ESCR for side B
    When the daemon's socket connects and sends a signed legacy envelope
    Then the relay refuses the socket

  @forgery
  Scenario Outline: An auth_modes notification the relay cannot tie to the requester's session is ignored
    Given a session request with relayAuthMode payload, a relayAuthAesKey, and no relayAuthModes
    And the daemon's socket has connected and sent nothing
    When an auth_modes notification naming ESCR for side B arrives <defect>
    Then the relay sends the daemon's socket nothing

    Examples:
      | defect                                          |
      | from an Atsign other than the requester         |
      | with an rvdNonce that is not this relay's       |
      | for a session id this relay does not know       |

  @replay
  Scenario: Each ESCR socket of a session gets its own challenge
    Given a session request whose relayAuthModes names ESCR for side A
    When two client sockets connect
    Then the relay sends each a different challenge

  Scenario: A 443 request that names ESCR for both sides is accepted
    Given a session request for the 443 path whose relayAuthModes names ESCR for both sides
    When the relay receives it
    Then the relay accepts the request

  @dos
  Scenario: A 443 request that names legacy for a side is refused
    Given a session request for the 443 path whose relayAuthModes names legacy for side B
    When the relay receives it
    Then the relay refuses the request
