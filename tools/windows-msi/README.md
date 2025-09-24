# SSH No Ports - Windows MSI Build using WiX v5

Usage of this tool is to create a Window MSI for sshnoports binaries.

Binaries are expected to be in windows-msi/bin

## Prerequisites
 - WiX Toolset V6
 - For CD pipeline:
   - needs setup-dotnet@v4 action
   - dotnet tool install --global wix
   
   Alternatively, you curl from the github repo and then build it from source.

## Usage
 - wix build path/to/tools/windows-msi/noports.wxs -o path/for/noports.msi