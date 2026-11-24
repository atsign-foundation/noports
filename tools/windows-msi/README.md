# SSH No Ports - Windows MSI Build using WiX v6

Usage of this tool is to create a Window MSI for sshnoports binaries.

Binaries are expected to be in windows-msi/bin

## Prerequisites

- WiX Toolset V6
- For CD pipeline:
  - needs setup-dotnet@v4 action
  - dotnet tool install --global wix

- Relies upon building and signing the binaries beforehand.
  - `atsc.exe` and `srv.exe`, compiled from the dart sources
  - the launcher (`packages\csharp\AtscLauncher`), copied under each program's
    name: `sshnpd.exe`, `sshnp.exe`, `npt.exe` and the others
  - built C# BinaryServices (sshnpdService.exe, nppService.exe, etc..)
    - see `packages\csharp\WindowsBinaryService\README.md` for more details.

## Usage

1. Windows MSI expects the windows binaries & services & example config file to be in the windows-msi\bin folder.
    - `atsc.exe`, `srv.exe`, and the launcher under each program's name
    - published C# BinaryServices (sshnpdService.exe, nppService.exe, etc..)
    - example config file (sshnpd.yaml)

2. Run the following command to build the MSI installer:
    - `wix build -ext WixToolset.Util.wixext -ext WixToolset.UI.wixext -d ProductVersion=5.15.2 -arch x64 -o build\NoPorts.msi noports.wxs`

    `-d ProductVersion=<x.y.z>` stamps the MSI's `ProductVersion`, which is what Windows
    shows as the version in Apps & Features and what drives major-upgrade detection. CI
    passes the version from `packages/dart/sshnoports/pubspec.yaml`. Omit the flag and the
    build falls back to `0.0.1`, which marks it unmistakably as a local build.
