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

  Files on the endpoint. The install settings file, written at install, names
  the endpoint's Atsign and device, the public key that signs its documents,
  the policy Atsign, whether remote changes are on, and the revision the
  endpoint starts from. The base file is sshnpd's existing configuration; a
  document adds exposed services to it and never removes or replaces anything
  in it, so the managers in the base file are a break-glass list no document
  can change. The local limits file is owned by root, lists the addresses any
  document may expose and the most tunnels it may run, and requires sshnpd
  to use a policy Atsign. Each entry is host:port, where port may be "*", or
  "tunnels" and a number; entries are matched as text, as sshnpd matches
  them; the file is at most 16 KiB. It is required when remote changes are
  on. Install writes a default when there is none, allowing 127.0.0.1 and
  localhost on any port and 64 tunnels (a placeholder, not measured), and
  never overwrites one that exists. A document can use only part of what the
  file allows, never more.

  What the reconciler renders. sshnpd's configuration always has an explicit
  permit-open: the base file's entries and the document's, and none at all
  when both are empty, so that sshnpd allows nothing rather than falling back
  to "*:*", its default when a policy Atsign is set. sshnpd carries each
  session in a separate srv process, which a restart of sshnpd leaves
  running, and the reconciler never makes it carry sessions in its own
  process. Each npt@ unit runs npt with --local-host 127.0.0.1, --keep-alive
  and -T 0, so a tunnel listens on loopback only and keeps its session until
  it is stopped; with --keep-alive and no -T, npt would end an idle session
  after 24 hours and listen again 5 seconds later. Each npt@ unit stops
  everything it started when it stops.

  The document comes from a local file, or, when the install settings file
  turns remote changes on, from the self record services_config.<device>.sshnp
  on the endpoint's atServer, inside an envelope signed over the Atsign,
  device, revision and document. A revision is a whole number from 1 to
  2^53 - 1. The reconciler records a revision as applied before it restarts
  any unit, and reports it applied after.

  Races: two runs at once hold a lock, so the second waits for the first, and
  a run that cannot take the lock within 60 seconds exits and logs it; a
  document arriving during a run is read at the next one; the local limits
  file is opened once, and its owner checked on what was opened.
  Replay: a document whose revision is lower than the last one applied, or
  than the install settings file's starting revision, is refused and
  reported; one equal to the last applied with the same content changes
  nothing, and with different content is refused; the signature covers the
  device, so a document for another device on the same Atsign is refused.
  The party who could present an old document is the atServer's host, which
  does not hold the signing key.
  DoS: a document over 64 KiB is refused before it is parsed; a document is
  applied at most once every 60 seconds; a document can never exceed the
  local limits. The record is read whole before its size is checked, up to
  the client's limit of about 10 MB; whoever can write it already holds the
  endpoint's keys or its atServer.
  Forgery: a document not signed by the key in the install settings file is
  refused whole; documents carry typed fields only, so nothing in one reaches
  a unit file as a command line. The signer is the management backend, which
  holds the Atsign's master keys; what bounds a document it signs is the
  local limits file.
  Impersonation: the signing key and the policy Atsign come only from files
  written at install, never from a document; the reconciler refuses a local
  limits file its own user could rewrite. The install settings file and the
  recorded revision need no such check: the user sshnpd runs as already holds
  the endpoint's keys and writes sshnpd's rendered configuration.

  Background:
    Given an endpoint @site1 device pump, installed with an install settings file, a base file and a local limits file
    And the install settings file names policy Atsign @policy1
    And the local limits file allows 127.0.0.1:8554, 127.0.0.1:502 and 127.0.0.1:22, and 8 tunnels

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

  Scenario: A tunnel's unit listens on loopback and keeps its session
    Given a document with tunnel a switched on, local port 18554
    When "atsc services apply" runs
    Then npt@a's unit runs npt with --local-port 18554, --local-host 127.0.0.1, --keep-alive and -T 0

  Scenario: A tunnel no longer in the document is stopped and its settings removed
    Given tunnel a is running
    When a document without tunnel a is applied
    Then npt@a is stopped, and its settings file is removed

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
    Given a session to 127.0.0.1:502 is running through sshnpd, carried by an srv process
    When a document no longer exposing 127.0.0.1:502 is applied
    Then sshnpd is restarted without 127.0.0.1:502 in permit-open
    And the running session carries on until it ends

  Scenario Outline: A document exposing nothing leaves only the base file's entries
    Given the base file's permit-open is <base>
    When a document with no exposed services is applied
    Then sshnpd's configuration has permit-open <rendered>
    And sshnpd refuses a session to 127.0.0.1:8554, whoever asks for it

    Examples:
      | base         | rendered                       |
      | not set      | set, with no entries           |
      | localhost:22 | localhost:22, and nothing else |

  Scenario: A document never changes the base file's managers
    Given the base file's managers are @admin
    When a document is applied
    Then sshnpd's managers are still @admin

  Scenario: A document exceeding the local limits is refused whole
    When a document exposing 127.0.0.1:3306 is applied
    Then nothing changes, and the status reports the document refused for exposing a service outside the local limits

  Scenario: The local limits file is matched as text
    Given the local limits file allows localhost:8554 and not 127.0.0.1:8554
    When a document exposing 127.0.0.1:8554 is applied
    Then nothing changes, and the status reports the document refused for exposing a service outside the local limits

  Scenario: Too many tunnels are refused whole
    When a document with 9 tunnels is applied
    Then nothing changes, and the status reports the document refused for exceeding 8 tunnels

  Scenario Outline: A document may not expose an address that reaches one of its own tunnels
    Given the local limits file allows <address>
    When a document exposing <address> with tunnel a on local port 18554 is applied
    Then nothing changes, and the status reports that <address> reaches tunnel a's local port

    Examples:
      | address         |
      | 127.0.0.1:18554 |
      | localhost:18554 |
      | 0.0.0.0:18554   |

  Scenario Outline: A base file entry that reaches a tunnel is reported, not refused
    Given the base file's permit-open is <entry>
    When a document with tunnel a on local port 18554 is applied
    Then tunnel a runs
    And the status warns that the base file's <entry> lets managers reach tunnel a

    Examples:
      | entry           |
      | 127.0.0.1:18554 |
      | localhost:*     |
      | *:*             |

  Scenario: No policy Atsign means nothing is applied
    Given the install settings file names no policy Atsign
    When "atsc services apply" runs
    Then nothing is applied, and the status reports that a policy Atsign is required

  Scenario Outline: A device whose sshnpd names another policy Atsign is left alone
    Given <where> names policy Atsign @other
    When "atsc services apply" runs
    Then nothing is applied, and the status reports that sshnpd names @other while the install settings file names @policy1

    Examples:
      | where                          |
      | the base file                  |
      | the sshnpd unit's command line |

  Scenario: A device whose sshnpd unit sets permit-open on its command line is left alone
    Given the sshnpd unit's command line has --permit-open localhost:22
    When "atsc services apply" runs
    Then nothing is applied, and the status reports that the unit's command line sets permit-open, which would override the document's

  Scenario: A device whose sshnpd names no policy Atsign takes the install settings file's
    Given the base file names no policy Atsign
    When a document is applied
    Then sshnpd runs with policy-manager @policy1

  # The local limits file

  Scenario: With remote changes on and no local limits file, nothing is applied
    Given remote changes are on, and the local limits file is missing
    When "atsc services apply" runs
    Then nothing is applied, and the status reports that the local limits file is missing

  Scenario: With remote changes off, no local limits file is needed
    Given remote changes are off, the local limits file is missing, and a local document exposes 127.0.0.1:8554
    When "atsc services apply" runs
    Then sshnpd's configuration has permit-open 127.0.0.1:8554

  Scenario Outline: A local limits file the reconciler's user could rewrite is refused
    Given <what>
    When "atsc services apply" runs
    Then nothing is applied, and the status reports that the local limits file must be writable only by root

    Examples:
      | what                                                                   |
      | the local limits file is writable by the user sshnpd runs as           |
      | the directory that holds it is writable by that user                   |
      | a parent of that directory is writable by that user                    |
      | the file is writable by a group that user belongs to                   |
      | the file is a link to a file that user can write                       |
      | the file is owned by that user, though its mode allows nobody to write |

  Scenario: An empty local limits file allows nothing
    Given the local limits file is empty
    When a document exposing 127.0.0.1:8554 is applied
    Then nothing changes, and the status reports the document refused for exposing a service outside the local limits

  Scenario Outline: A local limits file that cannot be read refuses every document
    Given the local limits file <problem>
    When "atsc services apply" runs
    Then nothing is applied, and the status reports that the local limits file cannot be read

    Examples:
      | problem                        |
      | has an entry that is not valid |
      | is larger than 16 KiB          |

  Scenario: Install writes a default local limits file that allows loopback services only
    Given an endpoint with no local limits file
    When atsc is installed
    Then the local limits file allows 127.0.0.1 and localhost on any port, and 64 tunnels
    And a document exposing 192.168.1.10:502 is refused for exposing a service outside the local limits

  Scenario Outline: Reinstalling keeps the existing local limits file
    Given the local limits file <holds>
    When atsc is installed again
    Then the local limits file is unchanged

    Examples:
      | holds                   |
      | allows 192.168.1.10:502 |
      | is empty                |

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

  Scenario: With no document yet, sshnpd runs from the base file alone
    Given remote changes are on, nothing has been applied, and services_config.pump.sshnp does not exist
    When "atsc services apply" runs
    Then sshnpd runs with the base file's permit-open entries and nothing else
    And the status reports that no document has been written yet

  Scenario: A deleted record leaves the last applied state running
    Given remote changes are on, and revision 15 is applied
    When services_config.pump.sshnp is deleted
    Then every service keeps running as revision 15 says
    And the status reports that the record is missing

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

  Scenario Outline: An envelope that is not well formed is refused whole
    Given remote changes are on
    When services_config.pump.sshnp holds an envelope with <problem>
    Then it is refused, and the status names the field

    Examples:
      | problem                                      |
      | alg none                                     |
      | an alg other than the pinned key's algorithm |
      | no signature                                 |
      | revision "x"                                 |
      | revision -1                                  |
      | revision 9007199254740992                    |

  Scenario: A lower revision is refused
    Given remote changes are on, and revision 15 is applied
    When services_config.pump.sshnp holds revision 14, correctly signed
    Then it is refused, and the status reports a revision lower than the one applied

  Scenario: The applied revision with different content is refused
    Given remote changes are on, and revision 15 is applied
    When services_config.pump.sshnp holds a different document as revision 15, correctly signed
    Then it is refused, and the status reports revision 15 with content that differs from the one applied

  Scenario: A fresh install refuses a revision below its starting revision
    Given remote changes are on, and the install settings file names starting revision 15, and nothing has been applied
    When services_config.pump.sshnp holds revision 12, correctly signed
    Then it is refused, and the status reports a revision lower than the starting revision 15

  Scenario: An older install settings file never lowers the recorded revision
    Given remote changes are on, and revision 15 is applied
    When atsc is installed again with an install settings file naming starting revision 3
    And services_config.pump.sshnp then holds revision 12, correctly signed
    Then it is refused, and the status reports a revision lower than the one applied

  Scenario: An address of a kind this agent does not know is refused whole
    Given remote changes are on
    When services_config.pump.sshnp holds a document exposing an address of kind unix
    Then it is refused, and the status names the address kind

  Scenario Outline: An address outside its allowed form is refused whole
    Given remote changes are on
    When services_config.pump.sshnp holds a document exposing an address whose host is <host>
    Then it is refused, and the status names the address

    Examples:
      | host        |
      | *           |
      | 127.0.0.1,* |
      | ::1         |

  Scenario: An unknown field or schema version is refused whole
    Given remote changes are on
    When services_config.pump.sshnp holds a document with a field its schema does not define
    Then it is refused, and the status names the field

  Scenario: An oversized document is refused before it is parsed
    Given remote changes are on
    When services_config.pump.sshnp holds more than 64 KiB
    Then it is refused, and the status reports its size

  Scenario: Documents are applied at most once a minute
    Given revision 15 was applied 20 seconds ago, and services_config.pump.sshnp now holds revision 16
    When "atsc services apply" is run by hand
    Then revision 16 is not applied, and the status reports that it waits for the minute to pass
    And revision 16 is applied at the first run 60 seconds or more after revision 15

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

  Scenario: A run that cannot take the lock within a minute gives up
    Given a run of "atsc services apply" has held the lock for 60 seconds
    When another run starts
    Then the new run exits without applying anything, and logs that the lock was held

  Scenario: The reconciler is not root, and controls only its own units
    Given atsc was installed with sshnpd running as user noports
    Then "atsc services apply" runs as noports
    And noports can start, stop and restart sshnpd.service and npt@*.service, and no other unit
