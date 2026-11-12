Feature: srvd re-checks the keys of the sessions it reports every few seconds

  srvd re-checks, from each key's own atServer, the client data signing keys
  its sessions' sockets were accepted with, and ends a session once one of
  them has been withdrawn: its enrollment was revoked, superseded or
  deleted, or has expired and been removed. Every session's keys are
  re-checked every 300 seconds by default. The keys of a session srvd
  reports to a collector Atsign are re-checked every 3 seconds as well, each
  lookup given 2 seconds, so such a session ends within 10 seconds of the
  atServer withdrawing a key, while that atServer answers within a second.
  Whether a session is reported is decided once, at its first pair. A lookup
  that fails, or is not answered in time, keeps the session. A key whose
  re-check fails, or whose atServer takes more than a second to answer, is
  re-checked less and less often, down to once a minute, until it is
  answered promptly again. A session ended for a withdrawn key has the
  sockets of every connection it has not yet closed destroyed at once, a
  connection whose close has begun among them, so no side is given time to
  take data the relay still holds for it; what the operating system has
  already accepted for sending may still arrive. A relay that stops still
  gives each side that time.

  The unit tests prove the scenarios against a stand-in lookup, under
  controlled time. The scenario about many slow atServers runs over HTTP, at
  a fifth of its times, and those about closing sockets run on real sockets.

  Races: a key has one re-check under way at most on each timer, and the two
  timers never wait on each other; a key revoked and reinstated between two
  re-checks keeps its session, including one the re-check found missing and
  that is reinstated before the lookup that confirms its withdrawal. An end
  that reaches a worker after its session has finished, or after a stop has
  closed it, does nothing; a socket still authenticating or waiting to pair
  when the end arrives is closed with the connector, holding no data for its
  far side.
  Replay: none; srvd sends and accepts no message for this.
  DoS: one lookup per reported key every 3 seconds, on a kept connection,
  and two more when the key is no longer published, with at most 64 lookups
  at once and 8 for any one Atsign. An atServer that fails or is slow has
  its keys re-checked less often, so it holds few of those lookups. The re-
  check of a key waits for a free lookup of its own Atsign and then for one
  of the 64, which goes to the waiting lookup whose Atsign has the fewest in
  flight and, among those with as few, to the Atsign served least recently.
  So Atsigns with many keys cannot hold up another Atsign's re-check, which
  waits for at most one turn for each other Atsign with as few in flight,
  and no Atsign's lookups wait forever. Many Atsigns with one slow key each
  are served in turn as equals, so enough of them answering just under a
  second can still delay another's re-check. An Atsign with more keys than
  8 lookups at a time can serve in 3 seconds has them re-checked in turn,
  less often; 64 keys on an atServer answering in 0.75
  seconds are all re-checked within 10 seconds, and many more are not. A
  key's failures are logged once a minute at most.
  Forgery: a withdrawal is read only from the key's own atServer, at the
  address the atDirectory gives, over TLS.
  Impersonation: nothing a client, daemon or collector sends ends a session
  or keeps one.

  Background:
    Given a relay that sends telemetry to a collector
    And it re-checks client data signing keys every 300 seconds, and those of the sessions it reports every 3 seconds, giving each lookup 2 seconds
    And a live session between client-side Atsign @alice and device-side Atsign @bob, each socket accepted with an enrollment signature

  Scenario: A reported session ends within 10 seconds of its device-side enrollment being revoked
    Given the session is reported
    When @bob's atServer revokes the enrollment the device-side socket signed with
    Then the relay closes both of the session's sockets within 10 seconds
    And its session.ended carries the reason signingKeyWithdrawn

  Scenario: A reported session ends within 10 seconds of its client-side enrollment being revoked
    Given the session is reported
    When @alice's atServer revokes the enrollment the client-side socket signed with
    Then the relay closes both of the session's sockets within 10 seconds

  Scenario: A session that is not reported is re-checked every 300 seconds
    Given the session is not reported
    When @bob's atServer revokes the enrollment the device-side socket signed with
    Then the relay ends the session at its next 300-second re-check, and not before

  Scenario: A relay that sends no telemetry re-checks every session every 300 seconds
    Given a relay started with no collector and no other option changed
    And a live session between @alice and @bob, each socket accepted with an enrollment signature
    When @bob's atServer revokes the enrollment the device-side socket signed with
    Then the relay ends the session at its next 300-second re-check

  Scenario: A session that started before its Atsigns opted in keeps the 300-second re-check
    Given the session started while neither @alice nor @bob was on the opted-in list
    When @bob is added to the opted-in list
    Then the session's keys are still re-checked every 300 seconds
    And a session @bob starts afterwards has its keys re-checked every 3 seconds

  Scenario: A reported session whose atServer does not answer in time carries on
    Given the session is reported and @bob's atServer does not answer
    When a re-check of the device-side key reaches its 2 seconds
    Then the session carries on and the relay logs that it could not re-check the key
    And the key is re-checked again at the next 3-second re-check

  Scenario: The faster re-check can be turned off on its own
    Given the relay was started with the faster re-check set to 0
    Then the keys of the sessions it reports are re-checked every 300 seconds

  Scenario: Turning the 300-second re-check off turns every re-check off
    Given the relay was started with --signing-key-check-secs 0
    Then no session's keys are re-checked, reported or not

  @race
  Scenario: A re-check still waiting when the next is due is not started twice
    Given the session is reported and a re-check of the device-side key has not finished
    When the next 3-second re-check is due
    Then the relay starts no second lookup for that key

  @race
  Scenario: A key revoked and reinstated between two re-checks keeps its session
    Given the session is reported
    When @bob's atServer revokes the device-side enrollment and reinstates it before the next re-check
    Then the session carries on

  @race
  Scenario: A key a re-check finds missing, and that is reinstated before the lookup that confirms its withdrawal, keeps its session
    Given the session is reported and @bob's atServer takes 0.5 seconds to answer
    When a re-check finds the device-side enrollment revoked and the atServer reinstates it before the lookup that confirms the withdrawal
    Then the session carries on

  @dos
  Scenario: A slow atServer delays only the re-checks of its own keys
    Given 100 reported sessions on 100 Atsigns, one of whose atServers takes 2 seconds to answer
    When a key on another of those Atsigns is revoked
    Then the relay ends that session within 10 seconds

  @dos
  Scenario: A key that keeps failing its re-check is re-checked less often
    Given the session is reported and @bob's atServer does not answer
    When its re-checks go on failing
    Then they come 3, 6, 12, 24 and 48 seconds apart, then once a minute
    And the key is still re-checked every 300 seconds, like any other session's

  @dos
  Scenario: A key whose atServer answers promptly again goes back to every 3 seconds
    Given the session is reported and its device-side key is re-checked once a minute
    When @bob's atServer answers a re-check within 1 second
    Then the key is re-checked 3 seconds later

  @dos
  Scenario: An Atsign with 64 reported keys has a revoked one ended within 10 seconds
    Given 64 reported sessions on one Atsign, whose atServer takes 0.75 seconds to answer
    When one of those keys is revoked
    Then the relay ends that session within 10 seconds
    And it ends no other

  @dos
  Scenario: Many slow atServers do not hold up another key's re-check
    Given 80 reported sessions on 80 Atsigns whose atServers each take 1.8 seconds to answer
    And one more reported session whose atServer answers at once
    When that session's key is revoked
    Then the relay ends it within 10 seconds

  Scenario: A session ended for a withdrawn key has its sockets closed at once
    Given a live session whose device side has stopped reading, with data waiting for it
    When the relay ends the session because a client data signing key was withdrawn
    Then both of the session's sockets are closed within 1 second
    And the data the relay still holds for the device side is dropped

  Scenario: A single-port session ended for a withdrawn key has its sockets closed at once
    Given two live sessions on the relay's single port, one of whose device sides has stopped reading
    When the relay ends that session because a client data signing key was withdrawn
    Then both of that session's sockets are closed within 1 second
    And the other session carries on

  Scenario: A session ended for a withdrawn key is reported complete within a second
    Given a live session whose device side has stopped reading, with data waiting for it
    When the relay ends the session because a client data signing key was withdrawn
    Then the worker reports the session complete within 1 second, with its byte counts

  @dos
  Scenario: Many busy Atsigns do not hold up a quiet Atsign's re-check
    Given 96 Atsigns each with 24 reported sessions, whose atServers each take 0.75 seconds to answer
    And one more reported session on another Atsign, whose atServer answers at once
    When that session's key is revoked
    Then the relay ends it within 10 seconds

  @dos
  Scenario: A busy Atsign's keys are still re-checked while quiet Atsigns are served first
    Given one Atsign with 24 reported sessions and 96 Atsigns with one reported session each, all answering in 0.75 seconds
    When the busy Atsign's last key is revoked
    Then the relay ends that session within 10 seconds

  Scenario: One Atsign's lookups are served in the order they asked
    Given one Atsign with more lookups waiting than its 8 slots
    When its slots free one at a time
    Then its lookups are made in the order they were asked for
