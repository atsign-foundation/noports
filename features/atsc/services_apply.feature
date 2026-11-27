Feature: atsc services apply runs an endpoint's services as its document says

  `atsc services apply` is the reconciler. It runs once at install and then
  every 5 minutes, with up to 60 seconds of jitter, from a systemd timer. It
  reads the endpoint's services document, renders sshnpd's configuration and
  one npt@ instance per tunnel, and starts, stops or restarts only the units
  whose settings changed. systemd supervises every service; nothing the
  reconciler starts stays under its control once it exits.

  It runs on the account sshnpd and every npt@ unit run on, never as root.
  sshnpd must share that account, since the reconciler writes sshnpd's whole
  configuration file. Installing a managed endpoint creates the account: it
  has no sudo and is in no root-equivalent group, and it keeps a login shell,
  so "sshnp -s" still lands callers on it. Status reports the account, any
  root-equivalent group it is in, and whether "sudo -n true" succeeds for it.
  A polkit rule installed with atsc lets that account start, stop and restart
  sshnpd.service and npt@*.service, and nothing else.

  Files on the endpoint. The install settings file, written at install, names
  the endpoint's Atsign and device, the public keys that may sign its
  documents, each with its key id, the policy Atsign, whether remote changes
  are on, and the revision the endpoint starts from; replacing a key takes a
  new install settings file. In file mode no install settings file is
  needed: the Atsign, device and policy Atsign come from the base file. The
  reconciler applies nothing while sshnpd runs under a device name other
  than the install settings file's. The base file is sshnpd's existing configuration; a
  document adds exposed services to it and never removes or replaces anything
  in it, so the managers in the base file are a break-glass list no document
  can change. The local limits file is owned by root, lists the addresses any
  document may expose and the most tunnels it may run, and requires sshnpd
  to use a policy Atsign. Each entry is host:port, where port may be "*", or
  "tunnels" and a number; entries are matched as text, as sshnpd matches
  them, except that 127.0.0.1 and localhost are one host; the file is at
  most 16 KiB. It is required when remote changes are on, and enforced in
  file mode too when it exists. With remote changes on, install writes a
  default when there is none, allowing 127.0.0.1 and localhost on any port
  and 64 tunnels (a placeholder, not measured), and never overwrites one
  that exists. A document can use only part of what the file allows, never
  more.

  What the reconciler renders. sshnpd's configuration always has an explicit
  permit-open list: the base file's entries and the document's, with a
  document's service on 127.0.0.1 or localhost under both spellings, and an
  empty list when there are none, never a key with no value, which sshnpd
  reads as unset and so as "*:*" when a policy Atsign is set. sshnpd carries
  each session in a separate srv process, which a restart of sshnpd leaves
  running, and the reconciler never makes it carry sessions in its own
  process. Each npt@ unit runs npt with --local-host 127.0.0.1, --keep-alive
  and -T 0, so a tunnel listens on loopback only and keeps its session until
  it is stopped; with --keep-alive and no -T, npt would end an idle session
  after 24 hours and listen again 5 seconds later. Each npt@ unit stops
  everything it started when it stops, unlike the npt.service.template
  packaged today. Until npt reports its own session state, a tunnel's state
  is its unit's: Running means the unit runs, not that its session is up.

  At boot. The timer also runs shortly after boot. That run verifies the
  saved signed document again, checks it against the local limits as any run
  does, and applies it when the atServer cannot be reached, so tunnels are
  down from boot until it runs.

  The document comes from a local file, or, when the install settings file
  turns remote changes on, from the self record services_config.<device>.sshnp
  on the endpoint's atServer, inside an envelope signed over the Atsign,
  device, revision, key id and document, over the exact bytes carried, with
  a context string and an envelope version inside them; the reconciler
  verifies the signature before it parses anything else. A revision is a
  whole number from 1 to 2^53 - 1. The reconciler records a revision as
  accepted before it restarts any unit, which is the floor every later
  document must pass, and as applied once every restart it needs has been
  attempted, a unit that failed being reported in status. A run that finds
  the accepted revision not yet applied restarts every unit that differs
  from the last applied revision's rendering, whatever the files on disk
  say. Both marks are written to a temporary file and renamed.

  Races: two runs at once hold a lock, so the second waits for the first, and
  a run that cannot take the lock within 60 seconds exits and logs it; a
  document arriving during a run is read at the next one; the local limits
  file is opened once, and its owner checked on what was opened; a run that
  stops between accepting a revision and applying it leaves the next run to
  finish it.
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
  Forgery: a document not signed by a key in the install settings file is
  refused whole; documents carry typed fields only, so nothing in one reaches
  a unit file as a command line. The signer is the management backend, which
  holds the Atsign's master keys; what bounds a document it signs is the
  local limits file.
  Impersonation: the signing keys and the policy Atsign come only from files
  written at install, never from a document; the reconciler refuses a local
  limits file its own account could rewrite, and applies nothing while sshnpd
  runs under another device name. The install settings file and the
  recorded revision need no such check: the account sshnpd runs on already holds
  the endpoint's keys and writes sshnpd's rendered configuration.

  Background:
    Given an endpoint @site1 device pump, installed with an install settings file, a base file and a local limits file
    And the install settings file names policy Atsign @policy1
    And the local limits file allows 127.0.0.1:8554, 127.0.0.1:502 and 127.0.0.1:22, and 8 tunnels

  # Applying a document

  Scenario: Applying a document renders sshnpd's exposed services and starts it
    Given a document exposing 127.0.0.1:8554
    When "atsc services apply" runs
    Then sshnpd's configuration has the base file's settings, permit-open 127.0.0.1:8554 and localhost:8554, and policy-manager @policy1
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
      | not set      | an empty list                  |
      | localhost:22 | localhost:22, and nothing else |

  Scenario: A document never changes the base file's managers
    Given the base file's managers are @admin
    When a document is applied
    Then sshnpd's managers are still @admin

  Scenario: A document exceeding the local limits is refused whole
    When a document exposing 127.0.0.1:3306 is applied
    Then nothing changes, and the status reports the document refused for exposing a service outside the local limits

  Scenario: The local limits file is matched as text
    Given the local limits file allows 192.168.1.10:502 and not plc.site1.example:502
    When a document exposing plc.site1.example:502 is applied
    Then nothing changes, and the status reports the document refused for exposing a service outside the local limits

  Scenario Outline: 127.0.0.1 and localhost are one host in the local limits file
    Given the local limits file allows <entry> and nothing else
    When a document exposing <exposed> is applied
    Then sshnpd's configuration has permit-open 127.0.0.1:8554 and localhost:8554

    Examples:
      | entry          | exposed        |
      | localhost:8554 | 127.0.0.1:8554 |
      | 127.0.0.1:8554 | localhost:8554 |
      | localhost:*    | 127.0.0.1:8554 |

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

  Scenario: A device whose sshnpd runs under another device name is left alone
    Given the base file names device pump2
    When "atsc services apply" runs
    Then nothing is applied, and the status reports that sshnpd runs as device pump2 while the install settings file names pump

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
    Then sshnpd's configuration has permit-open 127.0.0.1:8554 and localhost:8554

  Scenario: With remote changes off, a local limits file that exists is enforced
    Given remote changes are off, the local limits file allows 127.0.0.1:8554 only, and a local document exposes 192.168.1.10:502
    When "atsc services apply" runs
    Then nothing changes, and the status reports the document refused for exposing a service outside the local limits

  Scenario: File mode needs no install settings file
    Given no install settings file, and a base file naming @site1, device pump and policy Atsign @policy1
    When "atsc services apply" runs with a local document
    Then the local document is applied for @site1 device pump

  Scenario Outline: A local limits file the reconciler's user could rewrite is refused
    Given <what>
    When "atsc services apply" runs
    Then nothing is applied, and the status reports that the local limits file must be writable only by root

    Examples:
      | what                                                                   |
      | the local limits file is writable by the account sshnpd runs on        |
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
    When atsc is installed with remote changes on
    Then the local limits file allows 127.0.0.1 and localhost on any port, and 64 tunnels
    And a document exposing 192.168.1.10:502 is refused for exposing a service outside the local limits

  Scenario: Install in file mode writes no local limits file
    Given an endpoint with no local limits file
    When atsc is installed with remote changes off
    Then there is still no local limits file

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

  Scenario: A document not signed by a pinned key is refused
    Given remote changes are on
    When services_config.pump.sshnp holds a document signed by any other key
    Then it is refused, and the status reports a signature that does not verify

  Scenario: A document signed by any pinned key is applied
    Given remote changes are on, and the install settings file pins keys k1 and k2
    When services_config.pump.sshnp holds revision 15, signed by k2 and naming key id k2
    Then revision 15 is applied

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
      | an alg other than the named key's algorithm  |
      | a key id that is not pinned                  |
      | another context string                       |
      | an envelope version this agent does not read |
      | no signature                                 |
      | revision "x"                                 |
      | revision 0                                   |
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
      | 2130706433  |

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

  Scenario: Booting with no network applies the last applied document
    Given remote changes are on, revision 15 is applied, and tunnels a and b are switched on
    When the endpoint boots with no network
    Then the run shortly after boot verifies the saved revision 15 again and starts npt@a and npt@b

  Scenario: A saved document that no longer fits the local limits is not applied at boot
    Given revision 15, which exposes 127.0.0.1:502, is applied
    And the site has since changed the local limits file to allow 127.0.0.1:8554 only
    When the endpoint boots
    Then revision 15 is refused, and the status reports it refused for exposing a service outside the local limits

  Scenario: A run that stopped after accepting a revision finishes it at the next run
    Given a run accepted revision 16, which changes tunnel a, and stopped before restarting npt@a
    When "atsc services apply" runs
    Then npt@a is restarted with revision 16's settings, and revision 16 is reported applied

  Scenario: A unit that fails to restart does not hold the others back
    Given revision 16 changes tunnels a and b, and npt@a fails to start
    When "atsc services apply" runs
    Then npt@b is restarted, revision 16 is reported applied, and the status reports npt@a failed to start
    And the next run does not restart npt@b again

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

  Scenario: Installing a managed endpoint creates the services account
    When atsc is installed with remote changes on, on a machine with no services account
    Then sshnpd, every npt@ unit and "atsc services apply" run on a new account with a login shell, no sudo and no root-equivalent group

  Scenario: The reconciler is not root, and controls only its own units
    Given atsc was installed with sshnpd running on account noports
    Then "atsc services apply" runs as noports
    And noports can start, stop and restart sshnpd.service and npt@*.service, and no other unit
