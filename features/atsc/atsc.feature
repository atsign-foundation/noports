Feature: atsc runs every NoPorts command-line program

  atsc is one binary holding each NoPorts command-line program as a
  subcommand: at_activate, noports, np_admin, npevents, npp, npp_atserver,
  npp_file, npt, srvd, sshnp and sshnpd. Each of those names is still
  installed, and runs atsc with the name as its first argument, so
  `npt <args>` and `atsc npt <args>` do the same thing. On Linux and macOS
  each name is a small script; on Windows each is an .exe at the path it has
  today, except srvd, which Windows releases do not include: there
  `atsc.exe srvd` runs the relay. A script rather than a link to atsc lets
  atsc take the program from its first argument, never from the name it was
  started under; the cost is that the program runs as a process named atsc,
  with a command line such as `atsc sshnpd <arguments>`, which a search by
  the process name sshnpd does not find. srv, which the daemon and clients
  start once per session, stays a separate binary installed beside atsc.

  Races: when an upgrade replaces atsc and srv while sshnpd runs, sshnpd
  starts each new session's srv from the new srv beside it, as today, and
  sessions already running keep the srv they started with.
  Replay: no message, key or format that crosses the network changes.
  DoS: each session's srv still runs in a process of its own, and nothing
  else changes what a peer can make a daemon or relay do.
  Forgery: the subcommand comes from the local command line, whose user can
  already run any of the programs; the relay secrets still reach srv in its
  environment, never in its arguments.
  Impersonation: sshnpd and the clients start srv from their own
  installation, never by a PATH lookup or from the current directory, and
  each old name runs the atsc in its own installation.

  Scenario Outline: atsc <program> is the same program as <program>
    When "atsc <program> --help" runs
    And "<program> --help" runs
    Then both print the same text and exit 0

    Examples:
      | program      |
      | at_activate  |
      | noports      |
      | np_admin     |
      | npevents     |
      | npp          |
      | npp_atserver |
      | npp_file     |
      | npt          |
      | srvd         |
      | sshnp        |
      | sshnpd       |

  Scenario: a program names itself by its old name
    When "atsc npt --version" runs
    Then it prints "npt <version> (core <core version>)"
    And "atsc npt --help" prints a usage line starting "Usage: npt "

  Scenario: an old name passes every argument through unchanged
    When "npt" runs with the arguments "-d", "my device", "", "--key=a b" and "-"
    Then atsc npt receives exactly those five arguments, in that order

  Scenario: an old name exits with the program's exit code
    When "npt --no-such-option" runs
    Then it exits with the same code as "atsc npt --no-such-option"

  Scenario: a signal sent to an old name reaches the program
    Given "sshnpd" is running in the foreground
    When its process is sent SIGTERM
    Then sshnpd stops as it does today when sent SIGTERM

  Scenario: atsc with no subcommand prints its usage
    When "atsc" runs with no arguments
    Then it prints a usage that lists every subcommand
    And it exits non-zero

  Scenario: atsc with an unknown subcommand refuses it
    When "atsc no-such-program" runs
    Then it prints "Invalid command: no-such-program" and its usage
    And it exits non-zero

  Scenario: atsc prints its own version and help
    When "atsc --version" runs
    Then it prints "atsc <version> (core <core version>)" and exits 0
    And "atsc --help" prints its usage and exits 0

  Scenario: a subcommand's own --version is not taken by atsc
    When "atsc noports activate --version" runs
    Then it prints "noports <version> (core <core version>)"

  @impersonation
  Scenario: sshnpd starts each session's srv from its own installation
    Given sshnpd was started from the installation in "/opt/a"
    And a different "atsc" and a different "srv" are first on the PATH
    When a client requests a session
    Then the session's srv runs from the installation in "/opt/a"

  @impersonation
  Scenario: a client starts its srv from its own installation
    Given npt was started from the installation in "/opt/a"
    And a different "atsc" and a different "srv" are first on the PATH
    When "npt --exit-when-connected" opens a tunnel, which runs srv in a separate process
    Then that srv runs from the installation in "/opt/a"

  Scenario: srvd reports its own name and version to relay telemetry
    Given srvd runs with telemetry enabled
    When it exports its service attributes
    Then the service version is "srvd <version> (core <core version>)"

  Scenario: an old Windows name is still an .exe at its installed path
    Given NoPorts is installed on Windows from the MSI
    When "C:\Program Files\NoPorts\sshnp.exe <args>" runs
    Then it does what "atsc.exe sshnp <args>" does

  Scenario: srv is its own binary beside atsc
    When "atsc srv" runs
    Then it prints "Invalid command: srv" and its usage
    And "srv --version" prints "srv <version> (core <core version>)"

  Scenario: np_admin serves its web app from beside atsc
    Given atsc is installed in "/opt/a" with the web app in "/opt/a/web/admin"
    When "np_admin" runs from another directory
    Then it serves the web app from "/opt/a/web/admin"

  Scenario: the debug srvd runs the debug build of atsc
    The debug relay is a debug build of all of atsc, not of srvd alone, so
    that relay telemetry names it srvd: atsc names the program srvd, where a
    binary of its own takes its name from its file, such as debug_srvd.

    Given the debug relay is installed beside the production atsc
    When the debug srvd runs
    Then it runs srvd from the debug build of atsc, never the production one
