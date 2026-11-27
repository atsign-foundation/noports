Feature: Every reconciler run reports what the endpoint runs

  Every run of `atsc services apply` writes the self record
  services_status.<device>.sshnp directly to the endpoint's atServer, signed
  with the endpoint enrollment's client data signing key. It holds the
  record's format version, the Atsign and device it is about, the mode, the
  applied revision (in file mode, the applied document itself), a digest of
  the rendered files, the time of the last hand-edit replacement, each
  service's state and last error, the time of the run, whether the clock is
  synced, the agent version, the document schema versions the agent reads,
  the local limits file's content and digest, the managers in the base file,
  whether the base file refuses unsigned session requests, the account the
  services run on with any root-equivalent group it is in and whether
  "sudo -n true" succeeds for it, the units that failed to start, and the
  reason any document was refused or nothing was applied. It is written on
  every run. `atsc services status` prints the same comparison on the
  endpoint.

  Each service's state is one of running, starting, failing, off, and off by
  schedule, with a reason where there is one, such as waiting for a
  synchronised clock; Control Center shows them as Running, Starting,
  Failing, Off and Off by schedule. A tunnel's state is its unit's until npt
  reports its own session state, which comes in the slice after the first:
  until then running means the unit runs, and failing, with npt's last
  error, is not reported. Failed for missing keys is shown only by
  `atsc services status`, since without keys no record can be written.

  Races: a status written by one run is replaced whole by the next, and each
  carries its run time.
  Replay: the atServer's host can present an old record again, but cannot
  sign a new one; a reader treats a status whose run time is more than 20
  minutes old as unknown, whatever it says, which bounds how long an old
  "healthy" record can stand.
  DoS: every part of the record is bounded, so it never passes 256 KiB as the
  atServer stores it: the document it may carry is at most 64 KiB, the local
  limits file at most 16 KiB, it has one entry for sshnpd and for each of at
  most 64 tunnels, every error and reason is cut to 1 KiB on a character
  boundary, and at most 64 managers are listed, with a count of any more.
  Forgery: the signature lets a reader tell the endpoint's own status from a
  record anyone else wrote under its key name.
  Impersonation: the status names the Atsign and device it is about inside
  the signed content, so one device's status cannot pass as another's.

  Background:
    Given an endpoint @site1 device pump with tunnels a and b

  Scenario: Each run writes a signed status record
    When "atsc services apply" runs and applies revision 15
    Then services_status.pump.sshnp on @site1's atServer holds revision 15, the rendered digest, each service's state and the run time
    And it is signed with @site1 device pump's enrollment's client data signing key

  Scenario: A failing tunnel reports its last error
    Given npt reports its session state, and npt@b keeps failing with "no answer from @site1 device pump within 15 seconds"
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

  Scenario: The status keeps the time of the last hand-edit replacement
    Given npt@a's settings file was edited by hand, and the run at 13:55 UTC put the document's settings back
    When "atsc services apply" runs again at 14:00 UTC
    Then the status still reports the replacement at 13:55 UTC

  Scenario: The status carries the local limits file
    When "atsc services apply" runs
    Then the status holds the local limits file's content and its digest

  Scenario: A long error is cut to 1 KiB on a character boundary
    Given npt reports its session state, and npt@b keeps failing with an error of 3 KiB of multibyte text
    When "atsc services apply" runs
    Then the status holds at most 1 KiB of that error, ending on a whole character

  Scenario: At most 64 managers are listed
    Given the base file lists 70 managers
    When "atsc services apply" runs
    Then the status lists 64 of them, and says that 6 more are not listed

  Scenario: Without keys no status is written, and the endpoint says why locally
    Given the endpoint's keys file is missing
    When "atsc services apply" runs
    Then no status record is written
    And "atsc services status" on the endpoint reports each service failed for missing keys

  Scenario: atsc services status prints the comparison locally
    Given revision 15 is applied and tunnel b is failing
    When "atsc services status" runs on the endpoint
    Then it prints the endpoint's Atsign and device, the mode, the applied revision, the exposed services, the policy Atsign, each tunnel's state, and the time of the next run

  Scenario: The status reports the account the services run on
    Given the services run on account noports, which is in group docker
    When "atsc services apply" runs
    Then the status names account noports, reports that it is in group docker, and whether "sudo -n true" succeeds for it

  Scenario: The status lists sshnpd's managers as access outside policy
    Given the base file's managers are @admin and @ops
    When "atsc services apply" runs
    Then the status lists @admin and @ops as managers, whose sessions the policy service does not decide
