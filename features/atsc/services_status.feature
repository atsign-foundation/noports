Feature: Every reconciler run reports what the endpoint runs

  Every run of `atsc services apply` writes the self record
  services_status.<device>.sshnp on the endpoint's atServer, signed with the
  endpoint enrollment's client data signing key. It holds the applied
  revision (in file mode, the applied document itself), a digest of the
  rendered files, whether they had been edited by hand, each service's state
  and last error, the time of the run, whether the clock is synced, the agent
  version, the document schema versions the agent reads, and the reason any
  document was refused. `atsc services status` prints the same comparison on
  the endpoint.

  Races: a status written by one run is replaced by the next, and each
  carries its run time.
  Replay: only holders of the endpoint's Atsign keys can write the record
  back, and they already hold more; a reader treats a status whose run time
  is more than 20 minutes old as unknown, whatever it says.
  DoS: a status record is at most 256 KiB: the document it may carry is at
  most 64 KiB, and it has one entry for sshnpd and for each of at most 64
  tunnels, each error cut to 1 KiB.
  Forgery: the signature lets a reader tell the endpoint's own status from a
  record anyone else wrote under its key name.
  Impersonation: the status names the Atsign and device it is about inside
  the signed content, so one device's status cannot pass as another's.

  Background:
    Given an endpoint @site1 device pump with tunnels a and b

  Scenario: Each run writes a signed status record
    When "atsc services apply" runs and applies revision 15
    Then services_status.pump.sshnp holds revision 15, the rendered digest, each service's state and the run time
    And it is signed with @site1 device pump's enrollment's client data signing key

  Scenario: A failing tunnel reports its last error
    Given npt@b keeps failing with "connection refused on 127.0.0.1:8554"
    When "atsc services apply" runs
    Then the status reports tunnel b failing, with that error

  Scenario: A refused document is reported while the last applied keeps running
    Given revision 15 is applied
    When revision 16 is refused because its signature does not verify
    Then the status reports revision 15 applied and revision 16 refused, with the reason

  Scenario: In file mode the status carries the applied document
    Given remote changes are off
    When "atsc services apply" applies a local document
    Then the status holds that document

  Scenario: The status says which schema versions the agent reads
    When "atsc services apply" runs
    Then the status lists the document schema versions this agent reads

  Scenario: atsc services status prints the comparison locally
    Given revision 15 is applied and tunnel b is failing
    When "atsc services status" runs on the endpoint
    Then it prints the endpoint's Atsign and device, the mode, the applied revision, the exposed services, the policy Atsign, each tunnel's state, and the time of the next run

  Scenario: The status lists sshnpd's managers as access outside policy
    Given the base file's managers are @admin and @ops
    When "atsc services apply" runs
    Then the status lists @admin and @ops as managers, whose sessions the policy service does not decide
