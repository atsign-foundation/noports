# SSH No Ports Windows

## Installation
You can open the NoPorts.msi installer in File Explorer,

or optionally run this command in powershell.

```powershell
msiexec /i ".\NoPorts.msi"
```

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