Feature: atsc services generate makes each endpoint's services document from a fleet file

  A fleet file describes endpoints, each keyed by an Atsign and a device
  name; the services on each endpoint, as a name and an address; and access
  lines, each naming a caller (an endpoint in the file, or any other Atsign),
  a reached endpoint, the services the caller may reach, and the caller's
  local port for each. `atsc services generate` turns it into one services
  document per endpoint, a rules file for the npp_file policy program, and a
  preview of the systemd files each document renders to, made by the same
  rendering function `atsc services apply` uses. The generator is a pure
  function in the services config package: it uses no network, no keys and
  no clock, and the same function serves any management service that holds a
  fleet plan.

  An access line becomes both of its ends: the reached endpoint's document
  exposes the service, the policy rules let the caller reach that service on
  that endpoint and nothing else, and a caller that is an endpoint in the file
  gets one tunnel per service.

  An address is typed: tcp, a host and a port, and no other kind in this
  version. A host is an IPv4 address in dotted-quad form or a host name of
  letters, digits, "-" and ".", at most 253 characters, whose last label is
  not all digits, so never "*", "," or ":", and never a number a resolver
  might read as an address; a port is 1 to 65535. Service and tunnel names
  are lowercase letters, digits and "-", 1 to 63 characters. A device name
  matches the daemon's own rule, [a-z0-9_][a-z0-9_-]{1,35}, so it is 2 to 36
  characters. An Atsign is never empty or "*". The generator writes an
  address with the same spelling in every place it appears, since sshnpd
  matches permitted addresses as text; a service on 127.0.0.1 or localhost
  is also permitted under the other of those two spellings, in the policy
  rules and in the rendered permit-open, because callers ask for either:
  npt's default remote host is localhost, and an sshnp session always asks
  for localhost at the port sshd listens on, which the endpoint's base file
  sets. A tunnel names only its local port;
  where it listens is the endpoint's business. Local ports that the file does
  not give are assigned from 18000 to 18999 unless the file names another
  range.

  Races: generation reads one file and writes a fresh output directory, so
  two runs never share state; assign-ports replaces the fleet file whole, by
  rename.
  Replay: no message crosses the network; a document is signed for delivery
  elsewhere, never by the generator.
  DoS: a fleet file whose document for any endpoint would exceed 64 KiB, or
  64 tunnels, is refused with the endpoint named; the file's author could
  make it as large as they like, and holds more than a bound would deny them.
  Forgery: the generator writes only typed fields whose characters are fixed
  above, never a command line, so no text in a fleet file can add a permitted
  address, reach a unit file's command line or name a path.
  Impersonation: an access line grants a caller only the services it names,
  on the endpoint it names, through the policy rules.

  Background:
    Given a fleet file with @site1 device pump, with service sensors on 127.0.0.1:8554 and service plc on 127.0.0.1:502
    And @hq1 device hq, with no services

  Scenario: An access line becomes the reached endpoint's exposed service
    Given the fleet file has an access line from @hq1 device hq to @site1 device pump's sensors, local port 18554
    When "atsc services generate" runs on the fleet file
    Then @site1 device pump's document exposes 127.0.0.1:8554 and nothing else

  Scenario: An access line becomes a tunnel on the caller
    Given the fleet file has an access line from @hq1 device hq to @site1 device pump's sensors, local port 18554
    When "atsc services generate" runs on the fleet file
    Then @hq1 device hq's document has one tunnel, switched on, from local port 18554 to @site1 device pump's 127.0.0.1:8554

  Scenario: An access line becomes a policy rule for that caller alone
    Given the fleet file has an access line from @hq1 device hq to @site1 device pump's sensors, local port 18554
    When "atsc services generate" runs on the fleet file
    Then the rules file lets @hq1 reach 127.0.0.1:8554 and localhost:8554 on @site1 device pump
    And lets no other Atsign reach anything on @site1 device pump

  Scenario: An outside Atsign gets a policy rule and no tunnel
    Given the fleet file has an access line from @oncall, which is not an endpoint in the file, to @site1 device pump's plc
    When "atsc services generate" runs on the fleet file
    Then @site1 device pump's document exposes 127.0.0.1:502
    And the rules file lets @oncall reach 127.0.0.1:502 and localhost:502 on @site1 device pump
    And no document has a tunnel for @oncall

  Scenario: The same fleet file always gives the same bytes
    When "atsc services generate" runs twice on the same fleet file
    Then every document and the rules file are byte-for-byte the same both times

  Scenario: The order of entries in the fleet file does not change the output
    When "atsc services generate" runs on the fleet file, and on a copy with its endpoints, services and access lines in another order
    Then every document and the rules file are byte-for-byte the same for both

  Scenario: A problem is reported with its line, and nothing is written
    Given the fleet file has an access line to @site1 device pump's service camera, which it does not have
    When "atsc services generate" runs on the fleet file
    Then it exits non-zero, naming the line and that @site1 device pump has no service camera
    And no output is written

  Scenario: An unknown key is a problem
    Given the fleet file has a key its schema does not define
    When "atsc services generate" runs on the fleet file
    Then it exits non-zero, naming the line and the key
    And no output is written

  Scenario Outline: A field outside its allowed form is a problem
    Given the fleet file has <field> of <value>
    When "atsc services generate" runs on the fleet file
    Then it exits non-zero, naming the line and the field
    And no output is written

    Examples:
      | field           | value           |
      | a service host  | *               |
      | a service host  | 127.0.0.1,*     |
      | a service host  | ::1             |
      | a service host  | an empty string |
      | a service host  | 254 characters  |
      | a service host  | 2130706433      |
      | a service host  | 127.1           |
      | a service port  | 0               |
      | a service port  | 70000           |
      | a local port    | 0               |
      | a service name  | a/b             |
      | a service name  | 64 characters   |
      | a tunnel name   | ..              |
      | a device name   | Pump 1          |
      | a device name   | p               |
      | a device name   | 37 characters   |
      | a caller Atsign | *               |

  Scenario: An address of a kind this version does not support is a problem
    Given @site1 device pump has service db at unix:/run/postgresql/.s.PGSQL.5432
    When "atsc services generate" runs on the fleet file
    Then it exits non-zero, naming the line and that only tcp addresses are supported

  Scenario Outline: Duplicates are a problem
    Given the fleet file has <duplicate>
    When "atsc services generate" runs on the fleet file
    Then it exits non-zero, naming both lines

    Examples:
      | duplicate                                                |
      | two services named sensors on @site1 device pump         |
      | two endpoints with @site1 and device pump                |
      | two access lines from @hq1 device hq to the same service |

  Scenario: An endpoint cannot be its own caller
    Given the fleet file has an access line from @site1 device pump to @site1 device pump's sensors
    When "atsc services generate" runs on the fleet file
    Then it exits non-zero, naming the line and that an endpoint cannot be its own caller

  Scenario: Two tunnels on one endpoint cannot share a local port
    Given the fleet file gives two access lines from @hq1 device hq local port 18554
    When "atsc services generate" runs on the fleet file
    Then it exits non-zero, naming both lines and the port

  Scenario Outline: An endpoint may not expose an address that reaches one of its own tunnels
    Given @hq1 device hq has service web on <address>
    And the fleet file has an access line from @hq1 device hq to @site1 device pump's sensors, local port 18554
    When "atsc services generate" runs on the fleet file
    Then it exits non-zero, naming both lines and that <address> reaches the tunnel's local port

    Examples:
      | address         |
      | 127.0.0.1:18554 |
      | 127.0.0.2:18554 |
      | localhost:18554 |
      | 0.0.0.0:18554   |

  Scenario: An address keeps its spelling at both ends, and a loopback service is permitted in both spellings
    Given @site1 device pump's service sensors is on localhost:8554
    And the fleet file has an access line from @hq1 device hq to @site1 device pump's sensors, local port 18554
    When "atsc services generate --preview" runs on the fleet file
    Then @site1 device pump's document exposes localhost:8554
    And @hq1 device hq's tunnel reaches @site1 device pump's localhost:8554
    And the rules file lets @hq1 reach localhost:8554 and 127.0.0.1:8554 on @site1 device pump
    And the preview's permit-open for @site1 device pump has localhost:8554 and 127.0.0.1:8554

  Scenario: A service on another host is permitted only as written
    Given @site1 device pump's service plc is on 192.168.1.10:502
    And the fleet file has an access line from @hq1 device hq to @site1 device pump's plc, local port 18502
    When "atsc services generate --preview" runs on the fleet file
    Then the preview's permit-open for @site1 device pump has 192.168.1.10:502 and nothing else

  Scenario Outline: A document that would be too large is a problem
    Given the fleet file gives @site1 device pump <what>
    When "atsc services generate" runs on the fleet file
    Then it exits non-zero, naming @site1 device pump and <limit>
    And no output is written

    Examples:
      | what                                        | limit      |
      | 65 access lines from it, one tunnel each    | 64 tunnels |
      | services whose document would exceed 64 KiB | 64 KiB     |

  Scenario: A missing local port is assigned once and written into the file
    Given the fleet file has an access line from @hq1 device hq with no local port
    When "atsc services assign-ports" runs on the fleet file
    Then the access line has a local port from 18000 to 18999 that no other tunnel on @hq1 device hq uses
    And every other line of the file is byte-for-byte unchanged
    And running "atsc services assign-ports" again leaves the file unchanged

  Scenario: assign-ports with no free port left is a problem
    Given every port from 18000 to 18999 is used by a tunnel on @hq1 device hq, and one more access line from @hq1 device hq has no local port
    When "atsc services assign-ports" runs on the fleet file
    Then it exits non-zero, naming the line and that the range has no free port
    And the file is unchanged

  Scenario: The preview shows what each document renders to
    Given the fleet file has an access line from @hq1 device hq to @site1 device pump's sensors, local port 18554
    When "atsc services generate --preview" runs on the fleet file
    Then the output shows the permit-open @site1 device pump's document adds, and that the endpoint's base file entries are added on the endpoint
    And it shows @hq1 device hq's npt@ unit for the tunnel, byte-for-byte as "atsc services apply" would write it

  Scenario: Generating needs no network and no keys
    Given the machine has no network and no Atsign keys
    When "atsc services generate" runs on the fleet file
    Then it succeeds
