# SSH No Ports Windows

## Installation
You can open the NoPorts.msi installer in File Explorer,

or optionally run this command in powershell.

```powershell
msiexec /i ".\NoPorts.msi"
```

## Upgrading

Installing a newer MSI over an existing install performs a major upgrade: the old version is
uninstalled and the new one installed in its place. Two things to know:

- **The `sshnpd` service is restarted for you.** The upgrade stops and removes the old service and
  starts the new one. If it does not come back up, check the Event Viewer under `Application` and
  start it manually with `Start-Service sshnpd`. (On a *fresh* install the service is installed but
  left stopped, because it has no config yet — see Post-Installation below.)
- **`PATH` is rewritten**, so already-open terminals need restarting before they see the new
  binaries.

Your config at `%PROGRAMDATA%\NoPorts\sshnpd.yaml` and your keys in
`C:\Users\<USER>\.atsign\keys\` are left untouched by the upgrade.

## Troubleshooting

### The installer takes a long time before prompting for admin rights

Windows validates the installer's code signature before showing the UAC prompt. If the machine's
trusted root certificates are stale, or it cannot reach the certificate revocation servers, that
check can block for tens of seconds. `certupdater.ps1` is installed alongside the binaries in
`C:\Program Files\NoPorts\` and refreshes the trusted root store from Windows Update:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Program Files\NoPorts\certupdater.ps1"
```

It self-elevates, so run it from any shell. This is also worth trying if the NoPorts binaries
themselves fail to establish TLS connections.

## Post-Installation

### Device Side
When installing a device, ensure you are installing the NoPorts daemon service feature within the installer. 


1. Activate / Enroll your atSign keys

    First time activation
    ```
    at_activate.exe -a "@<REPLACE>_np"
    ```

    Enrolling existing keys onto another device
    ```
    at_activate.exe enroll -a "@<REPLACE>_np" `
    -s <PASSCODE> `
    -p noports `
    -k C:\Users\<USER>\.atsign\keys\@<REPLACE>_np_key.atKeys `
    -d <DEVICE_NAME> `
    -n "sshnp:rw,sshrvd:rw"
    ```
2. Edit the service config
    
    The service config is located at `%PROGRAMDATA%\NoPorts\sshnpd.yaml`
    
    Make sure to open this as administrator or else you won't be able to save the file.

    Ensure you provide the following fields to your service config:

    - atsign

        - atsign: example02_np

        - atsign: '@example02_np'

    - keys (windows path)

        - keys: C:\Users\alice\.atsign\keys\@example02_np_key.atKeys

    - manager 

        - manager: example01_np

        - manager: '@example01_np'

3. Finally, start your service!

    Open `services.msc / task manager` and start your sshnpd service!

    All the logs are located in the EventViewer >> `Application`


### Client Side
After finishing the install you'll have to make sure to activate and approve your enrollment onto your device.

Activate
```
at_activate.exe -a "@<REPLACE>_np"
```

Approve Enrollment
```
at_activate.exe approve -a "@<REPLACE>_np" --arx NoPorts --drx <REPLACE_NAME>
```