# NoPorts Admin API

## Status

The Admin API is currently in alpha, and we are working hard to make it
sufficiently robust for production usage

## Howto

0. Download a NoPorts release that contains the policy alpha binaries
(e.g. v5.7.0-alpha-6)

1. Run the policy service (using a different atSign to any daemons connecting
to the policy service): `npp_atserver -a @policy`

2. Start the policy admin API: `np_admin -a @policy -n sshnp`

3. Manage policy at: `http://localhost:3000`. In the UI, double-click on a
field to edit it. Changes save immediately they are done.

4. Connect one or more NoPorts daemons with `-p @policy`.
