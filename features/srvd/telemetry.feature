Feature: srvd reports its sessions to a collector Atsign, for the parties that opted in

  Given a collector Atsign, srvd sends telemetry about the sessions it
  carries as notifications to that Atsign, batched by at_telemetry's
  notification exporter. A session is reported only when its client Atsign,
  or its verified device Atsign, is on the opted-in list, the collection the
  collector shares with the relay; the decision is taken once, at the
  session's first pair, and never revisited. A reported session gets a record
  at first pair, a record of its connection events whenever some happen,
  coalesced over a short window, a still-running record every 15 minutes,
  and a record at its end. The relay itself sends
  a lifecycle record at start, every 60 seconds, and at stop, whatever the
  list says. Without a collector Atsign srvd sends nothing and reads nothing.

  The unit tests prove the records against a fake exporter and a fake list
  source; the local rig proves the notification exporter and the collection
  on real atServers.

  Vocabulary. The session set is the attributes every session record
  carries: the relay session id and a per-session sequence number, both
  Atsigns, whether each was verified, the port mode, the request and
  establishment times, and the device name when the request named one. A
  connections record's body is a list of open and close entries in time
  order. The window is the time from a session's first pending entry to the
  record that carries it.

  Races: the decision reads the list once, synchronously, at first pair; a
  pending window flushes before the session's end record, with nothing
  awaited between them; an end during a stop is reported once.
  Replay: every session record carries a sequence number, so each record is
  identified exactly, and a notification delivered twice repeats records that
  name the same session and connections; a client reusing
  its session id gets a new relay session id.
  DoS: nothing is sent for a session that never pairs; a session churning
  connections costs at most one record per window or per 100 entries; while
  the exporter holds more than 10 unsent batches every window doubles, to at
  most 60 seconds; the exporter keeps at most 100 unsent batches and drops
  the oldest beyond that, each drop counted and reported once a minute; a
  list read is bounded by its chunk count and refused whole when
  inconsistent.
  Forgery: srvd sends only what it observed; the Atsigns it reports are the
  session's as the relay checked them, with the device marked verified only
  when every device-side socket passed its check; the collector stamps who
  each record is about and strips any stamp a sender supplies.
  Impersonation: srvd sends as its own Atsign; it reports only sessions it
  paired itself, never a request a sibling instance answered; it reads only
  the list copies the collector shared with it.

  Background:
    Given a relay @relay started with the collector Atsign @telemetry
    And the collector has shared an opted-in list naming @alice and @bob

  # Configuration and lifecycle

  Scenario: srvd without a collector Atsign sends no telemetry
    Given a relay started without a collector Atsign
    When it carries a session between @alice and @bob
    Then no record is produced and no list is read

  Scenario: srvd sends lifecycle records whatever the list says
    When the relay has loaded its telemetry
    Then it sends noports.relay.lifecycle.started, then noports.relay.lifecycle.heartbeat every 60 seconds, each carrying the open-session count and the list's age and no Atsign, address or name
    And every record names the service srvd, the relay's version, and an instance id minted at this start

  Scenario: Records go to the collector as batched notifications
    When records are produced
    Then they are sent to @telemetry under the exporter's existing key logs.at_telemetry, at most 50 to a notification and at most a second after the first in it

  # The opted-in list

  Scenario: The list is read from the collection at start and every 15 minutes
    When the relay starts, and when 15 minutes pass
    Then it reads the manifest and every chunk it names from its own atServer, and holds the union as the list

  Scenario: Nothing is reported before the first good read
    Given the collection cannot be read yet
    When a session between @alice and @bob pairs
    Then the session is never reported, and the relay retries the read with backoff until it succeeds

  Scenario: An inconsistent read is refused and the previous list kept
    Given the relay holds a list, and the manifest now names 2 chunks but only 1 can be read
    When the next read runs
    Then the relay keeps the list it held and warns

  Scenario: A list holding an entry that is not a canonical Atsign is refused whole
    Given a chunk holds "Alice"
    When the read runs
    Then the whole read is refused, the previous list kept, and the relay warns

  Scenario: A list older than a day stops new sessions being reported
    Given the manifest's builtAt is 25 hours ago and every read since has failed
    When a session between @alice and @bob pairs
    Then it is not reported, the relay warns once on the change and then once an hour, and reporting resumes with the next good read

  # The decision

  Scenario: A session whose client is listed is reported from first pair to end
    When a session S between client @alice and device @carol pairs, carries one connection, and ends
    Then the relay sends noports.relay.session.started, noports.relay.session.connections and noports.relay.session.ended for S, each with the session set, @alice and @carol, and both peers' addresses

  Scenario: A session whose verified device is listed is reported with both parties' details
    When a session between client @dave and verified device @bob pairs
    Then it is reported, carrying @dave's and @bob's Atsigns, addresses and ports

  Scenario: A session whose device is listed but not verified is not reported
    When a session between client @dave and unverified device @bob pairs
    Then no record is sent for it

  Scenario: A session with neither party listed is not reported
    When a session between @dave and @erin pairs
    Then no record is sent for it

  Scenario: The decision is taken once, at first pair
    Given a session between @dave and @erin paired and was not reported
    When a later read lists @dave
    Then the session stays unreported to its end
    And a session reported under an earlier list keeps reporting after a read drops its client

  Scenario: A session that never pairs gets no records
    When @alice's request is answered but no socket ever connects
    Then no record is sent for it

  # The records

  Scenario: session.started carries the session set
    When a session pairs whose request named the device gateway-1 and the client session id abc-123
    Then noports.relay.session.started carries a fresh relay session id, sequence number 1, @alice and @bob, their verified flags, the port mode, the request and establishment times, the device name gateway-1 and the client session id

  Scenario: A client session id outside the allowed shape is left out
    When a session pairs whose client session id is 70 characters long
    Then the records carry no client session id and everything else

  Scenario: Connections that open together are reported in one record a window later
    Given a reported session
    When 6 connections pair within 100 milliseconds
    Then one noports.relay.session.connections record goes out about 2 seconds after the first pair, its body listing the 6 opens in order with index, time and both peers' address and port, and its attributes counting 6 opens, 0 closes and 6 open connections

  Scenario: Connections that close together are reported in one record a window later
    Given a reported session with 6 open connections
    When all 6 close within 100 milliseconds
    Then one connections record goes out about 2 seconds after the first close, its body listing the 6 closes with index, time, duration and bytes each way, and its attributes counting 0 opens, 6 closes, 0 open connections and the bytes so far

  Scenario: A window is not extended by later entries
    Given a reported session
    When connections pair steadily, one every 500 milliseconds
    Then a connections record goes out every 2 seconds, each carrying the entries of its window

  Scenario: A window closes at 100 entries
    Given a reported session
    When 150 connections pair within a second
    Then the first connections record carries 100 entries and goes out at once, and the second carries the other 50 at the window's end

  Scenario: Windows widen while the exporter is backed up
    Given a reported session and an exporter holding more than 10 unsent batches
    When connections pair steadily
    Then each window is twice the last, up to 60 seconds, and the next window after the backlog clears is 2 seconds again

  Scenario: still_running goes out every 15 minutes while the session is open
    Given a reported session with 2 open connections
    When two 15-minute ticks pass
    Then noports.relay.session.still_running goes out at each, with 2 open connections, 2 connections and the bytes so far

  Scenario: still_running goes out at the tick even when a connections record went out in the window
    Given a reported session
    When a connection pairs 5 minutes before the 15-minute tick
    Then still_running goes out at that tick

  Scenario: session.ended carries the totals and the reason
    Given a reported session with 3 connections, one still open
    When the session completes on its own
    Then any pending entries go out first, then noports.relay.session.ended with the end time, duration, bytes each way, 3 TCP connections, 1 connection unclosed, the reason connectionsClosed, and the next sequence number

  Scenario: A session ended for a withdrawn client data signing key says so
    Given a reported session
    When the relay ends it because a client data signing key was withdrawn
    Then its session.ended carries the reason signingKeyWithdrawn

  Scenario: Live sessions are reported as ended when srvd stops
    Given two reported sessions with open connections
    When the relay is stopped
    Then each session's pending entries and session.ended with the reason relayStopping go out as its worker reports completion, then noports.relay.lifecycle.stopped, and the exporter is given at most 5 seconds to send what remains

  Scenario: Sequence numbers count every record of a session
    Given a reported session
    When it sends started, two connections records, a still_running and ended
    Then their sequence numbers are 1, 2, 3, 4 and 5

  Scenario: Dropped records are counted and reported once a minute
    Given the relay's atServer refuses notifications until the exporter holds 100 unsent batches
    When more records are produced
    Then the oldest batch is dropped, and the relay logs one warning a minute with the number of records lost

  Scenario: Only the instance that paired a session reports it
    Given two relay instances share @relay and both answer a request
    When the client connects to the first instance's ports
    Then only the first instance sends records for the session
