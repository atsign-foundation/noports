Feature: A tunnel can be limited to weekly and one-off windows

  Built after the first slice of services documents. A tunnel switched on
  may also carry weekly windows (days of the week, a start and an end) and
  one-off windows (a start and an end instant). Every time is stored and read
  as UTC, and a window runs from its start up to, not including, its end. A
  tunnel with windows runs only inside one of them; a tunnel switched off
  stays off whatever its windows say. The reconciler works out which windows
  are open on every run, and after each run arms a one-off systemd timer for
  the next window boundary, with one-second accuracy and no random delay, so
  a window opens and closes on time without waiting for the 5-minute timer.
  A tunnel outside its windows is reported as off by schedule, which Control
  Center shows as Off by schedule.

  Races: each run takes one reading of the clock, works out both the state
  and the next boundary from it, and arms the timer before it applies the
  state, so a boundary that falls during a run is handled by that run or by
  the timer armed for it, never by neither.
  Replay: a window is part of the signed document, so the document's
  revision floor covers it; a clock that steps back inside a window opens
  nothing the windows did not already allow.
  DoS: a tunnel has at most 32 windows; a window shorter than 1 minute, one
  that ends before it starts, and two that overlap are refused, with the
  whole document.
  Forgery: as for any document.
  Impersonation: no new identity is involved. The clock is trusted: a window
  is only as good as the endpoint's time source, and nothing authenticates
  time, so a tunnel with windows stays stopped while the clock is not
  synchronised.

  Background:
    Given an endpoint @site1 device pump with tunnel a switched on
    And the endpoint's clock is synchronised, unless the scenario says otherwise

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

  Scenario Outline: A window crossing midnight is one window, from its start up to its end
    Given tunnel a has the weekly window Friday 22:00 to Saturday 02:00 UTC
    When the clock reads <time>
    Then npt@a is <state>

    Examples:
      | time               | state   |
      | Friday 21:59 UTC   | stopped |
      | Friday 22:00 UTC   | running |
      | Saturday 01:59 UTC | running |
      | Saturday 02:00 UTC | stopped |
      | Saturday 22:00 UTC | stopped |

  Scenario Outline: A window that is not valid is refused with the whole document
    When a document gives tunnel a <windows>
    Then the document is refused, and the status names tunnel a's windows

    Examples:
      | windows                                                         |
      | a window from 06:00 to 06:00:30 UTC                             |
      | the one-off window 2026-12-04T02:00Z to 2026-12-03T22:00Z       |
      | the weekly windows Monday 06:00 to 12:00 and 11:00 to 18:00 UTC |
      | 33 windows                                                      |

  Scenario: A tunnel switched off stays off inside its window
    Given tunnel a is switched off and has the weekly window Monday to Friday, 06:00 to 18:00 UTC
    When the clock reads Tuesday 10:00 UTC
    Then npt@a is not running

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

  Scenario: A tunnel waiting for the clock starts soon after the clock is synchronised
    Given the endpoint has booted inside tunnel a's window, and its clock is not yet synchronised
    When the clock becomes synchronised
    Then npt@a is started within 60 seconds

  Scenario: A tunnel outside its window says when it next opens
    Given tunnel a's window is closed until Monday 06:00 UTC
    When "atsc services status" runs
    Then tunnel a shows Off by schedule, opening Monday 06:00 UTC
    And the status record reports tunnel a off by schedule

  Scenario: With an unsynchronised clock, a tunnel with windows stays stopped
    Given the endpoint's clock is not synchronised
    When "atsc services apply" runs
    Then tunnel a is stopped, and the status reports it off by schedule, waiting for a synchronised clock
    And tunnels with no windows keep running

  Scenario: A running tunnel with windows stops when the clock stops being synchronised
    Given tunnel a is running inside its window
    When the clock stops being synchronised and "atsc services apply" runs
    Then npt@a is stopped, and the status reports it off by schedule, waiting for a synchronised clock
