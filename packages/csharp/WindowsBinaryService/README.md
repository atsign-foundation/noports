# Build Commands

## Prerequisites

- .NET SDK && C++ Build Tools 2022 installed
- Visual Studio or Visual Studio Code (optional)

## Publish

Publish self-contained executable

```bash

#define constants is a feature flag, this is what decides what binary to build
dotnet publish --configuration Release -p:DefineConstants="SSHNPD"

```

The service runs `atsc.exe` from its own folder, with the subcommand that the
constant names (`sshnpd` or `srvd`) and then the service's own arguments.
When `atsc.exe` ends or cannot start, the service starts it again after a
wait: 1 s, doubled after each run shorter than a minute up to 60 s, and back
to 1 s after a run of a minute or more. Stopping the service ends the wait.

Can alternatively build with Visual Studio

- Open the solution in Visual Studio
- Right click on the project `WindowsBinaryService` and select `Publish`
- Choose `Folder` as the target
- Configure the Project Properties to have build parameters be the binary you want to build "SSHNPD", "NPP", etc.
- Click `Publish` to generate the binaries in the specified folder
The published binaries will be located in `bin\Release\net10.0\win-x64\native\` folder by default.
