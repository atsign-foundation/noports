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

## Systemd unit files

`noports-policy.service`:

```ini
[Unit]
Description=NoPorts Policy Service
After=network-online.target

[Install]
WantedBy=multi-user.target

[Service]
Type=simple
Restart=always
RestartSec=3

# Configuration of NoPorts Policy service
# This unit script is a template for the sshnpd background service.
# You can configure the service by editing the variables below.

# MANDATORY: User to run the daemon as
User=noports

# MANDATORY: Policy manager address (atSign)
Environment=policy_atsign="@policy"

# Comment to disable verbose logging
Environment=v="-v"

# The line below runs the noports policy service, with the options set above.
# You can edit this line to further customize the service to your needs.
ExecStart=/home/noports/sshnp/npp_atserver -a "$policy_atsign" "$v"
```

`noports-policy-admin.service`:

```ini
[Unit]
Description=NoPorts Policy Admin Service
After=network-online.target

[Install]
WantedBy=multi-user.target

[Service]
Type=simple
Restart=always
RestartSec=3

# Configuration of NoPorts Policy Admin service
# This unit script is a template for the sshnpd background service.
# You can configure the service by editing the variables below.

# MANDATORY: User to run the daemon as
User=noports

# MANDATORY: Policy manager address (atSign)
Environment=policy_atsign="@policy"

# Comment to disable verbose logging
Environment=v="-v"

# The line below runs the noports policy service, with the options set above.
# You can edit this line to further customize the service to your needs.
ExecStart=/home/noports/sshnp/np_admin -a "$policy_atsign" -n sshnp "$v"
```
