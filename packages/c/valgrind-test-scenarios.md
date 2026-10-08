# Valgrind Test Scenarios

A list of test scenarios to run sshnpd under valgrind with.
All of these test scenarios assume the program is shutdown with the
graceful-shutdown-tool unless dictated otherwise.

## Test Scenarios

### idle

Don't create any sessions. Start the program, wait for a few stats notifications
then shutdown.

### idle reconnect

Same thing, don't create any sessions. Start the program, but this time, once
monitor is started, disconnect the network, and wait for it to reconnect. The
best way to do this is force a swap from Ethernet to WiFi or vice-versa. Then,
after the reconnect wait for another stats notification and shutdown.

### idle background thread

Again, don't create any sessions. This time we want to test that the hourly
background job doesn't have any leaks. The easiest way to do this is to
temporarily reduce the timer from 60 minutes to 1 minute
(global search for `60 * 60` to find this). Then do the same thing as the idle,
but wait until you see the background job run again. Then shutdown.

(no longer needs to be tested, as the second thread has been removed)

### sshnp session

Start an sshnp session with the minimum required arguments: -f, -t, & -d.
Using the valgrind container with `--network=host` is a fine option, if you have
password authentication turned on, it's fine to not sign in to the ssh session.
Close the sshnp session, then shutdown.

### npt session

Start an npt session with the minimum required arguments: -f, -t, -d, -l, & -p.
Using the valgrind container with `--network=host` is a fine option.
Close the npt session, then shutdown.

### ping handler

Should be tested by newer versions of sshnp and npt already. No need to test
separately, but calling it out since it is its own notification type.

### send ssh public key

Same as sshnp session, but include the `-s` and `-i` flag in the sshnp command.
It's best to address any issues with `sshnp session` before moving on to this
test.

### live sshnp session

Same thing as `sshnp session` but don't close the sshnp session before shutting
down.

### live npt session

Same thing as `npt session` but don't close the npt session before shutting
down.
