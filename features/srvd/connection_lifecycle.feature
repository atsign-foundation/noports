Feature: srvd reports each connection's life to its main isolate and stops in bounded time

  srvd carries each session in a worker isolate: one per port-pair session,
  and one shared worker for every port-443 session. A worker tells the main
  isolate when a connection pairs, when both its sides are destroyed, every
  15 minutes while the session runs, and when the session is complete, with
  every time taken in the worker at the event. Main records the device name
  from the session request's key. A stop closes every connection, waits for
  each worker's completion report, and exits within 12 seconds. None of this
  sends anything outside the process; it is what a telemetry sink can be
  built on.

  Vocabulary. A session is one request_ports answered by this relay. A
  connection is one pair of sockets the session's connector joined, numbered
  from 1 in the order they paired. A worker's report is one message on its
  port to main.

  Races: a close reported after its session's completion (the worker waits
  for every close, bounded, and for at most 4 seconds once a stop begins,
  inside main's 5-second kill); a stop racing a session that is starting (the
  start is refused once stopping); a stop racing a worker that never
  completes (killed at the bound).
  Replay: a request_ports naming a session id that is live or starting is
  refused, as today; nothing here adds a message that can be resent.
  DoS: a peer that stops reading holds a side for at most socket_connector's
  close flush bound once a side closes, and for at most its stall bound
  before that; a worker that has not exited 5 seconds after a stop asks it
  to is killed; a stop takes at most 12 seconds whatever the sessions do. A
  refused request costs each srvd instance at most one NACK, sent to its
  sender, and a relay with a manager reads and answers no one else's
  request.
  Forgery: the device name is text the client chose; it is kept only when
  it matches the device-name pattern in full and is lower-cased as the key
  is, and a session whose name does not match starts without one. A request
  whose atSignA or atSignB is not a valid Atsign is refused, and a session
  holds both canonical, so every session has a client-side and a
  device-side Atsign; the device-side one is the client's claim unless the
  device side authenticates. A refusal names the field and why in a fixed
  text that never repeats the field's value, and a session id that is not a
  UUID is neither logged nor used in a NACK.
  Impersonation: the name is recorded against a session whose sender was
  checked as atSignA, as today; a NACK goes to the request's sender, never
  to the atSignA it named; nothing here changes who may start a session.

  Background:
    Given a relay @relay with a port-pair worker for session S between @alice and @bob

  # What a worker reports

  Scenario: A worker reports a connection when its sides pair
    When a client socket and a device socket pair on S's ports
    Then main receives newConnection for S with index 1, the time the worker saw the pair, and each side's IP and port

  Scenario: A worker reports a connection when both its sides are destroyed
    Given connection 1 of S has carried 10 bytes from client to device and 20 bytes from device to client
    When both sides of connection 1 are destroyed
    Then main receives connectionClosed for S with index 1, the pair time, the later of the two sides' close times, 10 bytes client to device and 20 bytes device to client

  Scenario: Connections are numbered in the order they pair and an end names its own start
    Given connections 1 and 2 of S are open
    When connection 1 ends
    Then main receives connectionClosed for S with index 1, and connection 2 stays open

  Scenario: A peer socket_connector did not record is left out of the report
    Given a connection whose client side was recorded with no address
    When it pairs
    Then main receives newConnection with the device's IP and port and no client IP or port

  Scenario: Event times are taken in the worker, not when main reads them
    Given main does not read its port for 2 seconds
    When a connection pairs and ends during those 2 seconds
    Then the pair and close times in the reports are inside those 2 seconds, not after them

  Scenario: A worker reports progress every 15 minutes
    Given S has 2 open connections that have carried 100 bytes each way so far
    When 15 minutes pass since S's first pair
    Then main receives progress for S with 2 open connections, 2 connections so far, and 100 bytes each way

  Scenario: The port-443 worker reports the same messages for each of its sessions
    Given the shared port-443 worker carries sessions S1 and S2
    When a connection pairs and ends on each
    Then main receives newConnection and connectionClosed for S1 and for S2, each naming its own session

  # Completion follows every close

  Scenario: sessionComplete follows the last connectionClosed once the connector's grace period has passed
    Given S's 3 connections have all ended
    When the connector's grace period has passed, so it finishes
    Then main receives connectionClosed three times and then sessionComplete for S with 3 connections, the byte totals, and 0 connections unclosed

  Scenario: sessionComplete is sent at the bound when a close is never reported
    Given a connector that never reports the close of one of S's 2 connections
    When the connector finishes
    Then main receives sessionComplete within 4 seconds, with 2 connections and 1 connection unclosed, and the worker logs a warning

  Scenario: A side whose peer has stopped reading is destroyed within the flush bound when the relay closes the connector
    Given connection 1 of S has unsent data for a device peer that has stopped reading
    When the relay closes the session's connector
    Then both sides are destroyed within socket_connector's close flush bound and main receives connectionClosed for S

  # The device name

  Scenario: The device name comes from the session request's key
    When @alice sends request_ports to @relay under the key gateway-1.request_ports.sshrvd
    Then session S records the device name gateway-1 and every later report of S can carry it

  Scenario: A device name that does not match the pattern is not recorded
    When @alice sends request_ports under the key x.request_ports.sshrvd
    Then session S starts with no device name

  Scenario: The device name is lower-cased as the key is
    When @alice sends request_ports under the key Gateway-1.request_ports.sshrvd
    Then session S records the device name gateway-1

  # The session's Atsigns

  Scenario: A session request whose device-side Atsign is not a valid Atsign is refused
    When @alice requests a session whose atSignB is "@a@b", with authenticateSocketB false
    Then srvd sends @alice no ports, records no session, and logs a refusal naming @alice, atSignB and why

  Scenario: A session request whose client-side Atsign is not a valid Atsign is refused
    When @alice requests a session whose atSignA is "@a@b"
    Then srvd sends @alice no ports, records no session, and logs a refusal naming @alice, atSignA and why

  Scenario: A refused session request is sent a NACK saying why when its client takes NACKs
    When @carol requests a session whose atSignB is "@a@b", with multipleAcksOk true
    Then srvd sends @carol one NACK for the session, saying atSignB is not a valid Atsign and why, and no ports

  Scenario: A NACK that cannot be sent is logged at srvd's default level
    When @carol's refused request takes a NACK and the notification fails
    Then srvd logs at shout that the NACK for the session to @carol was not sent, and why

  Scenario: A refused session request whose session id is not a UUID is sent nothing, and its id is not logged
    When @alice requests a session whose id is not a UUID and whose atSignB is "@a@b", with multipleAcksOk true
    Then srvd sends @alice nothing, and its refusal log says the id is not a UUID without repeating it

  Scenario: On a relay with a manager, a session request from another Atsign is refused before it is read, and sent nothing
    Given a relay whose manager is @manager
    When @carol requests a session whose atSignB is "@a@b", with multipleAcksOk true
    Then srvd sends @carol nothing and logs that only the manager may request sessions

  # Stopping

  Scenario: A stop closes every connection, waits for each completion, and returns within 12 seconds
    Given two live sessions, each with an open connection
    When srvd is stopped
    Then no new session request is taken from that moment
    And every connector is closed, so each listener is gone, and each worker exits or is killed within 5 seconds
    And main receives sessionComplete for each session before it forgets the sessions
    And every worker isolate has exited and the stop returns within 12 seconds

  Scenario: A worker that never completes is killed and the stop still returns within 12 seconds
    Given a worker that ignores its stop message
    When srvd is stopped
    Then that worker is killed, the stop returns within 12 seconds, and a warning names the worker

  Scenario: A session whose device stops reading is reported complete before its worker is killed
    Given a session whose device has stopped reading while data for it is still queued
    When the relay is stopped
    Then its worker reports the session complete within 4 seconds, with the bytes each way so far and the open connection counted as unclosed
    And the stop returns within 12 seconds

  Scenario: A session request arriving during a stop is refused
    Given srvd is stopping
    When @alice sends request_ports
    Then no session starts

  Scenario: The first signal stops srvd gracefully and the second exits at once
    Given srvd running as a process with a live session
    When it receives SIGTERM
    Then it stops as above and exits within 12 seconds
    When it receives a second SIGTERM before that
    Then it exits at once
