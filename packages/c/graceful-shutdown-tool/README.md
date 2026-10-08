# graceful-shutdown-tool

When sshnpd is built with the `SSHNPD_ENABLE_TESTING_SHUTDOWN_NOTIFICATION`
compile definition, then it enables an extra notification handler for the key
`graceful_shutdown`. When sshnpd receives this key, it does a graceful shutdown,
exiting the main handler loop and proceeding with shutdown.

Normally this type of exit only occurs when sshnpd has some unrecoverable error.
Passing SIGINT to sshnpd does not gracefully exit, so in order for sshnpd to
exit in such a way that we can properly run memcheck, this special notification,
which is only available behind the compile definition is used to trigger an exit.

This graceful-shutdown-tool can be used to send this notification.

## Usage

`./graceful-shutdown-tool $FROM $TO`

> FROM is the -a flag in sshnpd
> TO is the -m flag in sshnpd
