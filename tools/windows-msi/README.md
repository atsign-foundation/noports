# SSH No Ports - Windows MSI Build using WiX v5

Usage of this tool is to create a Window MSI for sshnoports binaries.

Binaries are expected to be in windows-msi/bin

## Prerequisites

- WiX Toolset V6
- For CD pipeline:
  - needs setup-dotnet@v4 action
  - dotnet tool install --global wix

- Relies upon building and signing the binaries beforehand.
  - all dart binaries
  - built C# BinaryServices (sshnpdService.exe, nppService.exe, etc..)
    - see `packages\csharp\WindowsBinaryService\README.md` for more details.

## Usage

1. Windows MSI expects the windows binaries & services & example config file to be in the windows-msi\bin folder.
    - all dart binaries
    - published C# BinaryServices (sshnpdService.exe, nppService.exe, etc..)
    - example config file (sshnpd.yaml)

2. Run the following command to build the MSI installer:
    - `wix build -ext WixToolset.Util.wixext -ext WixToolset.UI.wixext -arch x64 -o build\NoPorts.msi noports.wxs`
