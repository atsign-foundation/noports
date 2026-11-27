Feature: atsc services apply runs an endpoint's services as its document says

  `atsc services apply` is the reconciler. It runs once at install and then
  every 5 minutes, with up to 60 seconds of jitter, from a systemd timer. It
  reads the endpoint's services document, renders sshnpd's configuration and
  one npt@ instance per tunnel, and starts, stops or restarts only the units
  whose settings changed. systemd supervises every service; nothing the
  reconciler starts stays under its control once it exits.

  It runs as the user sshnpd runs as, never as root. A polkit rule installed
  with atsc lets that user start, stop and restart sshnpd.service and
  npt@*.service, and nothing else.

  Files on the endpoint. The install settings file, written at install, names the
  endpoint's Atsign and device, the public key that signs its documents, the
  policy Atsign, and whether remote changes are on. The base file is
  sshnpd's existing configuration; a document adds exposed services to it
  and never removes or replaces anything in it, so the managers in the base
  file are a break-glass list no document can change. The ceiling file is
  owned by root, lists the services any document may expose and the most
  tunnels it may run, and requires sshnpd to use a policy Atsign.

  The document comes from a local file, or, when the install settings file turns
  remote changes on, from the self record services_config.<device>.sshnp on
  the endpoint's atServer, inside an envelope signed over the Atsign, device,
  revision and document.

  Races: two runs at once hold a lock, so the second waits for the first; a
  document arriving during a run is read at the next one.
  Replay: a document whose revision is lower than the last one applied is
  refused and reported; one equal to it changes nothing; the signature
  covers the device, so a document for another device on the same Atsign is
  refused.
  DoS: a document over 64 KiB is refused before it is parsed; a document is
  applied at most once every 60 seconds; a document can never exceed the
  ceiling.
  Forgery: a document not signed by the key in the install settings file is refused
  whole; documents carry typed fields only, so nothing in one reaches a unit
  file as a command line.
  Impersonation: the signing key and the policy Atsign come only from files
  written at install, never from a document; the reconciler refuses a
  ceiling file its own user could rewrite.

  Background:
    Given an endpoint @site1 device pump, installed with an install settings file, a base file and a ceiling file
    And the install settings file names policy Atsign @policy1
    And the ceiling file allows 127.0.0.1:8554, 127.0.0.1:502 and 127.0.0.1:22, and 8 tunnels

  # Applying a document

  Scenario: Applying a document renders sshnpd's exposed services and starts it
    Given a document exposing 127.0.0.1:8554
    When "atsc services apply" runs
    Then sshnpd's configuration has the base file's settings, permit-open 127.0.0.1:8554, and policy-manager @policy1
    And sshnpd.service is running

  Scenario: Each tunnel switched on becomes a running npt@ instance
    Given a document with tunnels a and b switched on and tunnel c switched off
    When "atsc services apply" runs
    Then npt@a and npt@b are running and npt@c is not

  Scenario: Applying an unchanged document restarts nothing
    Given the document was applied, and nothing has changed since
    When "atsc services apply" runs
    Then no unit is started, stopped or restarted

  Scenario: Changing one tunnel restarts only that tunnel
    Given tunnels a and b are running
    When a document changing only tunnel a's local port is applied
    Then npt@a is restarted with the new port, and npt@b is untouched

  Scenario: Switching a tunnel off drops its connections at once
    Given tunnel a is running and carrying a connection
    When a document switching tunnel a off is applied
    Then npt@a is stopped, and its connection is closed

  Scenario: A change to exposed services restarts sshnpd and leaves its sessions running
    Given a session to 127.0.0.1:502 is running through sshnpd
    When a document no longer exposing 127.0.0.1:502 is applied
    Then sshnpd is restarted without 127.0.0.1:502 in permit-open
    And the running session carries on until it ends

  Scenario: A document exposing nothing leaves sshnpd exposing nothing
    Given a document with no exposed services
    When "atsc services apply" runs
    Then sshnpd refuses a session to 127.0.0.1:22, whoever asks for it

  Scenario: A document never changes the base file's managers
    Given the base file's managers are @admin
    When a document is applied
    Then sshnpd's managers are still @admin

  Scenario: A document exceeding the ceiling is refused whole
    When a document exposing 127.0.0.1:3306 is applied
    Then nothing changes, and the status reports the document refused for exposing a service outside the ceiling

  Scenario: Too many tunnels are refused whole
    When a document with 9 tunnels is applied
    Then nothing changes, and the status reports the document refused for exceeding 8 tunnels

  Scenario: No policy Atsign means nothing is applied
    Given the install settings file names no policy Atsign
    When "atsc services apply" runs
    Then nothing is applied, and the status reports that a policy Atsign is required

  Scenario Outline: A device whose sshnpd names another policy Atsign is left alone
    Given <where> names policy Atsign @other
    When "atsc services apply" runs
    Then nothing is applied, and the status reports that sshnpd names @other while the install settings file names @policy1

    Examples:
      | where                         |
      | the base file                 |
      | the sshnpd unit's command line |

  Scenario: A device whose sshnpd names no policy Atsign takes the install settings file's
    Given the base file names no policy Atsign
    When a document is applied
    Then sshnpd runs with policy-manager @policy1

  Scenario: Without a ceiling file, nothing is applied
    Given the ceiling file is missing
    When "atsc services apply" runs
    Then nothing is applied, and the status reports that the ceiling file is missing

  Scenario: A ceiling file the reconciler's user can write is refused
    Given the ceiling file is writable by the user sshnpd runs as
    When "atsc services apply" runs
    Then nothing is applied, and the status reports that the ceiling file must be writable only by root

  Scenario: Missing keys fail every service, which stays stopped
    Given the endpoint's keys file is missing
    When "atsc services apply" runs
    Then no service is started, and "atsc services status" reports each failed for missing keys
    And none is started again until the keys file exists and "atsc services apply" runs again

  # Remote changes

  Scenario: A newer signed document on the atServer is applied at the next run
    Given remote changes are on, and revision 14 is applied
    When services_config.pump.sshnp holds revision 15, signed by the install settings file's key
    Then the next run applies revision 15

  Scenario: A document not signed by the pinned key is refused
    Given remote changes are on
    When services_config.pump.sshnp holds a document signed by any other key
    Then it is refused, and the status reports a signature that does not verify

  Scenario Outline: A document signed for another endpoint is refused
    Given remote changes are on
    When services_config.pump.sshnp holds a document signed for <atsign> device <device>
    Then it is refused, and the status reports the wrong <what>

    Examples:
      | atsign | device | what   |
      | @site1 | valve  | device |
      | @site2 | pump   | Atsign |

  Scenario: A lower revision is refused
    Given remote changes are on, and revision 15 is applied
    When services_config.pump.sshnp holds revision 14, correctly signed
    Then it is refused, and the status reports a revision lower than the one applied

  Scenario: An unknown field or schema version is refused whole
    Given remote changes are on
    When services_config.pump.sshnp holds a document with a field its schema does not define
    Then it is refused, and the status names the field

  Scenario: An oversized document is refused before it is parsed
    Given remote changes are on
    When services_config.pump.sshnp holds more than 64 KiB
    Then it is refused, and the status reports its size

  Scenario: Documents are applied at most once a minute
    Given revision 15 was applied 20 seconds ago
    When revision 16 arrives and "atsc services apply" runs
    Then revision 16 is applied at the first run 60 seconds or more after revision 15

  Scenario: An unreachable atServer leaves the last applied state running
    Given remote changes are on, and revision 15 is applied
    When "atsc services apply" runs and cannot reach the atServer
    Then every service keeps running as revision 15 says
    And the next status it writes reports the failure

  Scenario: With remote changes off, the atServer's record is ignored
    Given remote changes are off, and a local document file
    When services_config.pump.sshnp holds a newer signed document
    Then the local document is the one applied

  Scenario: Hand edits are replaced in remote mode
    Given remote changes are on
    When someone edits npt@a's settings file by hand
    Then the next run puts the document's settings back, restarts npt@a, and the status reports the replacement and its time

  Scenario: Hand edits are reported in file mode
    Given remote changes are off
    When someone edits npt@a's settings file by hand
    Then the next run leaves it, and the status reports that the rendered files differ from the document

  Scenario: Two runs at once do not interleave
    When two runs of "atsc services apply" start together
    Then the second waits for the first to finish before it reads the document

  Scenario: The reconciler is not root, and controls only its own units
    Given atsc was installed with sshnpd running as user noports
    Then "atsc services apply" runs as noports
    And noports can start, stop and restart sshnpd.service and npt@*.service, and no other unit
