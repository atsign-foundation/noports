Feature: A tunnel can be limited to weekly and one-off windows

  Built after the first slice of services documents. A tunnel switched on
  may also carry weekly windows (days of the week, a start and an end) and
  one-off windows (a start and an end instant). Every time is stored and read
  as UTC. A tunnel with windows runs only inside one of them. The
  reconciler works out which windows are open on every run, and after each
  run arms a one-off systemd timer for the next window boundary, so a window
  opens and closes on time without waiting for the 5-minute timer.

  Races: a boundary that falls during a run is handled by that run or by the
  timer armed for it, never by neither, since every run recomputes the state
  from the clock.
  Replay: a window is part of the signed document, so the document's
  revision floor covers it.
  DoS: a tunnel has at most 32 windows, and a window shorter than 1 minute
  is refused.
  Forgery: as for any document.
  Impersonation: nothing new crosses the network.

  Background:
    Given an endpoint @site1 device pump with tunnel a switched on

  Scenario: A tunnel with a weekly window runs only inside it
    Given tunnel a has the weekly window Monday to Friday, 06:00 to 18:00 UTC
    When the clock reads Tuesday 10:00 UTC
    Then npt@a is running
    And when the clock reads Tuesday 19:00 UTC, npt@a is stopped

  Scenario: A one-off window opens and closes once
    Given tunnel a has only the one-off window 2026-12-03T22:00Z to 2026-12-04T02:00Z
    When the clock reads 2026-12-03T23:00Z
    Then npt@a is running
    And when the clock reads 2026-12-04T03:00Z, npt@a is stopped and stays stopped

  Scenario: A window crossing midnight is one window
    Given tunnel a has the weekly window Friday 22:00 to Saturday 02:00 UTC
    When the clock reads Saturday 01:00 UTC
    Then npt@a is running

  Scenario: A window closing drops connections at once
    Given tunnel a is running inside its window and carrying a connection
    When the window closes
    Then npt@a is stopped, and its connection is closed

  Scenario: A window opens on time
    Given tunnel a's next window opens at 06:00 UTC
    When the clock reaches 06:00 UTC
    Then npt@a is started within 5 seconds, without waiting for the 5-minute timer

  Scenario: Booting inside a window starts the tunnel
    Given tunnel a's window is open
    When the endpoint boots and "atsc services apply" runs
    Then npt@a is running

  Scenario: A tunnel outside its window says when it next opens
    Given tunnel a's window is closed until Monday 06:00 UTC
    When "atsc services status" runs
    Then tunnel a shows Stopped by schedule, opening Monday 06:00 UTC

  Scenario: With an unsynced clock, a tunnel with windows stays stopped
    Given the system clock is not synchronised
    When "atsc services apply" runs
    Then tunnel a is stopped, and the status reports that windows wait for a synchronised clock
    And tunnels with no windows keep running
