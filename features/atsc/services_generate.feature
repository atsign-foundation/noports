Feature: atsc services generate makes each endpoint's services document from a fleet file

  A fleet file describes endpoints, each keyed by an Atsign and a device
  name; the services on each endpoint, as a name and a host:port; and access
  lines, each naming a caller (an endpoint in the file, or any other Atsign),
  a reached endpoint, the services the caller may reach, and the caller's
  local port for each. `atsc services generate` turns it into one services
  document per endpoint, a rules file for the npp_file policy program, and a
  preview of the systemd files each document renders to. The generator is a
  pure function in the services config package: it uses no network, no keys
  and no clock, and the same function serves any management service that
  holds a fleet plan.

  An access line becomes both of its ends: the reached endpoint's document
  exposes the service, the policy rules let the caller reach that service on
  that endpoint and nothing else, and a caller that is an endpoint in the file
  gets one tunnel per service.

  Races: generation reads one file and writes a fresh output directory, so
  two runs never share state.
  Replay: no message crosses the network; a document is signed for delivery
  elsewhere, never by the generator.
  DoS: a fleet file whose document for any endpoint would exceed 64 KiB, or
  64 tunnels, is refused with the endpoint named.
  Forgery: the generator writes only typed fields, never a command line, so
  no text in a fleet file reaches a unit file or a shell.
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
    Then the rules file lets @hq1 reach 127.0.0.1:8554 on @site1 device pump
    And lets no other Atsign reach anything on @site1 device pump

  Scenario: An outside Atsign gets a policy rule and no tunnel
    Given the fleet file has an access line from @oncall, which is not an endpoint in the file, to @site1 device pump's plc
    When "atsc services generate" runs on the fleet file
    Then @site1 device pump's document exposes 127.0.0.1:502
    And the rules file lets @oncall reach 127.0.0.1:502 on @site1 device pump
    And no document has a tunnel for @oncall

  Scenario: The same fleet file always gives the same bytes
    When "atsc services generate" runs twice on the same fleet file
    Then every document and the rules file are byte-for-byte the same both times

  Scenario: A problem is reported with its line, and nothing is written
    Given the fleet file has an access line to @site1 device pump's service camera, which it does not have
    When "atsc services generate" runs on the fleet file
    Then it exits non-zero, naming the line and that @site1 device pump has no service camera
    And no output is written

  Scenario: An unknown key is a problem
    Given the fleet file has a key its schema does not define
    When "atsc services generate" runs on the fleet file
    Then it exits non-zero, naming the line and the key

  Scenario: Two tunnels on one endpoint cannot share a local port
    Given the fleet file gives two access lines from @hq1 device hq local port 18554
    When "atsc services generate" runs on the fleet file
    Then it exits non-zero, naming both lines and the port

  Scenario: A missing local port is assigned once and written into the file
    Given the fleet file has an access line from @hq1 device hq with no local port
    When "atsc services assign-ports" runs on the fleet file
    Then the access line has a local port no other tunnel on @hq1 device hq uses
    And running "atsc services assign-ports" again leaves the file unchanged

  Scenario: The preview shows what each document renders to
    Given the fleet file has an access line from @hq1 device hq to @site1 device pump's sensors, local port 18554
    When "atsc services generate --preview" runs on the fleet file
    Then the output shows @site1 device pump's rendered sshnpd permit-open and @hq1 device hq's npt@ instance settings

  Scenario: Generating needs no network and no keys
    Given the machine has no network and no Atsign keys
    When "atsc services generate" runs on the fleet file
    Then it succeeds
