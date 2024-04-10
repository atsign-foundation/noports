<#
.SYNOPSIS
   Installtion script for sshnpd on Windows
.DESCRIPTION
    Usage: install_sshnpd [options]

    Sshnp Version: 5.1.0
    Repository: https://github.com/atsign-foundation/sshnoports
    Script Version: 0.1.0

    General options:
      -u, --update                Update all services instead of installing
          --rename                Rename device for client/device pair with the new name
      -l, --local <path>          Install using local zip/tgz
      -r, --repo <path>           Install using local repo
      -h, --help                  Display this help message

    Installation options:
      -c, --client <address>      Client address (e.g. @alice_client)
      -d, --device <address>      Device address (e.g. @alice_device)
      -n, --name <device name>    Name of the device
      -v, --version <version>     Version to install (default: latest)
          --args <args>           Additional arguments to sshnpd ("-v" by default)
          Possible args:
            -s, --[no-]sshpublickey      Update authorized_keys to include public key from sshnp
            -u, --[no-]un-hide           When set, makes various information visible to the manager atSign - e.g. username, version, etc
            -v, --[no-]verbose           More logging

    Rename options:
      -c, --client <address>      Client address (e.g. @alice_client)
      -n, --name <device name>    New name of the device
.PARAMETER install_sshnpd OP
    The operation to perform. Default is "install".
    Rename options:
      -c, --client <address>      Client address (e.g. @alice_client)
      -n, --name <device name>    New name of the device
.EXAMPLE
    Usage: install_sshnpd [options]

    General options:
      -u, --update                Update all services instead of installing
          --rename                Rename device for client/device pair with the new name
      -l, --local <path>          Install using local zip/tgz
      -r, --repo <path>           Install using local repo
      -h, --help                  Display this help message

    Installation options:
      -c, --client <address>      Client address (e.g. @alice_client)
      -d, --device <address>      Device address (e.g. @alice_device)
      -n, --name <device name>    Name of the device
      -v, --version <version>     Version to install (default: latest)
          --args <args>           Additional arguments to sshnpd ("-v" by default)
          Possible args:
            -s, --[no-]sshpublickey      Update authorized_keys to include public key from sshnp
            -u, --[no-]un-hide           When set, makes various information visible to the manager atSign - e.g. username, version, etc
            -v, --[no-]verbose           More logging

    Rename options:
      -c, --client <address>      Client address (e.g. @alice_client)
      -n, --name <device name>    New name of the device
#>
#Prints the help message via get-help install_sshnpd-windows.ps1 
param(
    [string]$SSHNP_OP = "install",
    [switch]$SSHNP_CACHE_TEMP,
    [string]$SSHNP_LOCAL,
    [string]$SSHNP_DEV_MODE,
    [Parameter(Mandatory=$true, HelpMessage="Specify the manager atsign.")]
    [ValidateNotNullOrEmpty()]
    [string]$CLIENT_ATSIGN,
    [string]$DEVICE_MANAGER_ATSIGN,
    [Parameter(Mandatory=$true, HelpMessage="Specify the device atsign.")]
    [ValidateNotNullOrEmpty()]
    [string]$DEVICE_ATSIGN,
    [Parameter(Mandatory=$true, HelpMessage="Specify the device name.")]
    [ValidateNotNullOrEmpty()]
    [string]$DEVICE_NAME,
    [string]$HOST_ATSIGN,
    [string]$VERSION,
    [string]$SSHNPD_SERVICE_ARGS
)

### --- IMPORTANT ---
#Make sure to change the values in the help message.
#The help message must be at the top of the script, so no variables.

# SCRIPT METADATA
$script_version = "0.1.0"
$sshnp_version = "5.1.0"
$repo_url = "https://github.com/atsign-foundation/sshnoports"
# END METADATA


#can stay until sshnpd releases
$BINARY_NAME = "sshnp"

function Norm-Atsign {
    param([string]$input)
    $atsign = "@$($input -replace '"', '' -replace '^@', '')"
    return $atsign
}

function Norm-Version {
    param([string]$input)
    $version = "tags/v$($input -replace '"', '' -replace '^tags/', '' -replace '^v', '')"
    return $version
}

function Norm-InstallType {
    param([string]$input)
    $input = $input.ToLower()
    switch -regex ($input) {
        "d.*" { return "device" }
        "c.*" { return "client" }
        "b.*" { return "both" }
        default { return $null }
    }
}

function Check-BasicRequirements {
    $requiredCommands = @("attrib", "Expand-Archive", "Select-String", "Select-Object", "Get-WmiObject", "StartService","Test-Path", "New-Item", "Get-Command", "New-Object", "Invoke-WebRequest", "New-Service")
    
    foreach ($command in $requiredCommands) {
        if (-not (Get-Command -Name $command -ErrorAction SilentlyContinue)) {
            Write-Host "[X] Missing required dependency: $command"
        }
    }
}

function Make-Dirs {
    if (-not (Test-Path "$env:HOME\.atsign")) {
        New-Item -Path "$env:HOME\.atsign" -ItemType Directory -Force
    }
    if(Test-Path "$env:HOME\.atsign\temp\$VERSION") {
        Remove-Item -Path "$env:HOME\.atsign\temp\$VERSION" -Recurse -Force
    }

    if (-not (Test-Path "$env:HOME\.ssh")) {
        New-Item -Path "$env:HOME\.ssh" -ItemType Directory -Force
    }
    
    if (-not (Test-Path "$env:HOME\.$BINARY_NAME\logs")){
        New-Item -Path "$env:HOME\.$BINARY_NAME\logs" -ItemType Directory -Force
    }
    if(-not (Test-Path "$env:HOME\.atsign\keys")){
        New-Item -Path "$env:HOME\.atsign\keys" -ItemType Directory -Force
    }
    if(-not (Test-Path "$env:HOME\.atsign\temp")){
        New-Item -Path "$env:HOME\.atsign\temp" -ItemType Directory -Force
    }
    if(-not (Test-Path "$env:HOME\.local\bin")){
        New-Item -Path "$env:HOME\.local\bin" -ItemType Directory -Force
    }

    if (-not (Test-Path "$env:HOME\.ssh\authorized_keys" -PathType Leaf)) {
        New-Item -Path "$env:HOME\.ssh\authorized_keys" -ItemType File -Force
        attrib "$env:HOME\.ssh\authorized_keys" +h
    }
}

function Parse-Env {
    $global:HOME_PATH = if (-not [string]::IsNullOrEmpty($env:HOME)) { $env:HOME } else { $env:USERPROFILE }
    $global:VERSION = if ([string]::IsNullOrEmpty($VERSION)) { "latest" } else { Norm-Version $VERSION }
    $global:URL = "https://api.github.com/repos/atsign-foundation/noports/releases/$VERSION"
    #$global:INSTALL_TYPE = $null
    $CLIENT_ATSIGN = Norm-Atsign $CLIENT_ATSIGN
    $DEVICE_ATSIGN = Norm-Atsign $DEVICE_ATSIGN
    $DEVICE_MANAGER_ATSIGN = Norm-Atsign $DEVICE_MANAGER_ATSIGN
    $VERSION =  Norm-Version $VERSION
    
}

function Cleanup {
    if (Test-Path "$HOME_PATH/.atsign/temp/$VERSION") {
        Remove-Item -Path "$HOME_PATH/.atsign/temp/$VERSION" -Recurse -Force
    }
}

function Download-Archive {
    Write-Host "Downloading $BINARY_NAME from $global:URL"
    $DOWNLOAD_BODY = $(Invoke-WebRequest -Uri $global:URL).ToString() -split "," | Select-String "browser_download_url" | Select-String "sshnp-windows"
    $DOWNLOAD_URL = $DOWNLOAD_BODY.ToString() -split '"' | Select-Object -Index 3
    Write-Host $DOWNLOAD_URL
    New-Item -Path "$HOME_PATH/.atsign/temp/$VERSION" -ItemType Directory -Force
    Invoke-WebRequest -Uri $DOWNLOAD_URL -OutFile $global:ARCHIVE_PATH
    if (-not (Test-Path $global:ARCHIVE_PATH)) {
        Write-Host "Failed to download $BINARY_NAME"
        Cleanup
        Exit 1
    }
}

function Unpack-Archive {
    
    if (-not (Test-Path $global:ARCHIVE_PATH)) {
        Write-Host "Failed to download $BINARY_NAME"
        Exit 1
    }

    Expand-Archive -Path  -DestinationPath "$HOME_PATH/.atsign/temp/$VERSION/" -Force
    if (-not (Test-Path "$HOME_PATH/.atsign/temp/$VERSION/sshnp/sshnp.exe")) {
        Write-Host "Failed to unpack $BINARY_NAME"
        Cleanup
        Exit 1
    }
    $global:BIN_PATH = "$HOME_PATH/.atsign/temp/$VERSION/$BINARY_NAME"
}


function Get-UserInputs {
    if (-not $global:INSTALL_TYPE) {
        while (-not $global:INSTALL_TYPE) {
            $install_type_input = Read-Host "Install type (device, client, both):"
            $global:INSTALL_TYPE = Norm-InstallType $install_type_input
        }
    }
}

#Not Sure if this is needed, but I'll leave it here for now.
function Get-Atsigns {
    $directory = "$env:home\.atsign\keys"
    $prefixes = @()

    if (Test-Path $directory -PathType Container) {
        $files = Get-ChildItem -Path $directory -Filter "*.atKeys" -File

        foreach ($file in $files) {
            $prefix = $file.BaseName -replace '_key$'
            $prefixes += $prefix
        }
    }

    return $prefixes
}


function Write-Metadata {
    param(
        [string]$file,
        [string]$variable,
        [string]$value
    )

    $start_line = "# SCRIPT METADATA"
    $end_line = "# END METADATA"

    $content = Get-Content -Path $file
    $start_index = $content.IndexOf($start_line)
    $end_index = $content.IndexOf($end_line)

    if ([string]::IsNullOrEmpty($content)) {
        Write-Host "Error: $file is empty"
        return
    }

    if ($start_index -ne -1 -and $end_index -ne -1) {
        for ($i = $start_index; $i -le $end_index; $i++) {
            if ($content[$i] -match "$variable=`".*`"") {
                $content[$i] = $content[$i] -replace "$variable=`".*`"", "$variable=`"$value`""

            }
            Write-Host "he"
        }

        $content | Set-Content -Path $file
    } else {
        Write-Host "Error: Metadata block not found in $file"
    }
}


function Install-Client {
    if (-not $HOST_ATSIGN) {
        Write-Host "Pick your default region:"
        Write-Host "  am   : Americas"
        Write-Host "  ap   : Asia Pacific"
        Write-Host "  eu   : Europe"
        Write-Host "  @___ : Specify a custom region atSign"
        while (-not ($host_atsign -match "@.*")) {
            switch -Regex ($host_atsign.ToLower()) {
                "^(am).*" {
                    $host_atsign = "@rv_am"
                    break
                }
                "^(eu).*" {
                    $host_atsign = "@rv_eu"
                    break
                }
                "^(ap).*" {
                    $host_atsign = "@rv_ap"
                    break
                }
                "^@" {
                    # Do nothing for custom region
                    break
                }
                default {
                    Write-Host ("Invalid region: $host_atsign")
                    $host_atsign = Read-Host "Region"
                }
            }
        }
    }
    
    
}

# Main function
function Main {
    # Check-BasicRequirements
    # Parse-Env
    # #Windows Only Has Device For Now so no need to ask for install type
    # #Get-UserInputs
    # Make-Dirs
    # Download-Archive
    # Unpack-Archive
    #Install-Client
    Write-Metadata -file $env:HOMEPATH\testmeta\test -variable "womp" -value "reversed"
}

# Execute the main function
Main
