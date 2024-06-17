# SSH No Ports Windows

## Installation
First, open a powershell terminal.

Then run the following command:

```powershell
Invoke-WebRequest -Uri "https://github.com/atsign-foundation/noports/releases/latest/download/universal.ps1" -OutFile "universal.ps1"
```

### Running the installer
After downloading the installer, you can run the installer by running the following command:

```powershell
.\universal.ps1
```

### Device Side
After finishing the device install, you will have a windows service installed called `sshnpd`. This service will be started automatically and will be running in the background.

### Client Side
After finishing the client install, you will have a binary called `{device_name@device_atsign}` installed on your machine. You can use this binary to connect to the device.

Example:
```powershell
esp_32@wanderinggazebo 
```

## SSH Key Generation
To generate an SSH key, you can run the following command:

For RSA:
```powershell
ssh-keygen
```

For Ed25519:
```powershell
ssh-keygen -t ed25519
```

## Activate the device atSign
First time activating this atSign
```powershell
~/.local/bin/at_activate -a @<REPLACE>_device
```
Activated this atSign before ?
 As before if this atSign is already activated elsewhere then you need to copy the .atKeys file for this atSign into the ~/.atsign/keys/ directory.