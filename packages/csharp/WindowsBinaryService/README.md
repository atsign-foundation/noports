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

Can alternatively build with Visual Studio

- Open the solution in Visual Studio
- Right click on the project `WindowsBinaryService` and select `Publish`
- Choose `Folder` as the target
- Configure the Project Properties to have build parameters be the binary you want to build "SSHNPD", "NPP", etc.
- Click `Publish` to generate the binaries in the specified folder
The published binaries will be located in `bin\Release\net8.0\win-x64\native\` folder by default.
