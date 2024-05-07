# SSH No Ports Windows

## Installation

Install the sshnp-windows-x64 bundle on your Windows machine.

[Latest Relaase](https://github.com/atsign-foundation/noports/releases/latest)

Open a powershell terminal and run the following command:

```powershell
./universal.ps1
```

Follow the instructions and you will have the sshnp binaries installed on your Windows machine.

## Usage


### Device Side
After finishing the device install, you will have a windows service installed called `sshnpd`. This service will be started automatically and will be running in the background.


### Client Side
After finishing the client install, you will have a binary called `{device_name@device_atsign}` installed on your machine. You can use this binary to connect to the device.

Example:
```powershell
esp_32@wanderinggazebo 
```