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
.NOTES
    Author: [Xavier Lin]
    Date:   [April 3, 2024]
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
    [string]$SSHNPD_DEVICE_NAME,
    [string]$SSHNPD_VERSION,
    [string]$SSHNPD_SERVICE_ARGS
)

### --- IMPORTANT ---
#Make sure to change the values in the help message.
#The help message must be at the top of the script, so no variables.

# SCRIPT METADATA
# DO NOT MODIFY/DELETE THIS BLOCK
$script_version = "0.1.0"
$sshnp_version = "5.1.0"
$repo_url = "https://github.com/atsign-foundation/sshnoports"
# END METADATA



# Set variables
$BINARY_NAME = "sshnp"

# Define function to normalize atsign
function Norm-Atsign {
    param([string]$input)
    $atsign = "@$($input -replace '"', '' -replace '^@', '')"
    return $atsign
}

# Define function to normalize version
function Norm-Version {
    param([string]$input)
    $version = "tags/v$($input -replace '"', '' -replace '^tags/', '' -replace '^v', '')"
    return $version
}

# Define function to check basic requirements
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
    if(Test-Path "$env:HOME\.atsign\temp\$SSHNPD_VERSION") {
        Remove-Item -Path "$env:HOME\.atsign\temp\$SSHNPD_VERSION" -Recurse -Force
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
    $global:SSHNPD_VERSION = if ([string]::IsNullOrEmpty($SSHNPD_VERSION)) { "latest" } else { Norm-Version $SSHNPD_VERSION }
    $global:URL = "https://api.github.com/repos/atsign-foundation/noports/releases/$SSHNPD_VERSION"
    $CLIENT_ATSIGN = Norm-Atsign $CLIENT_ATSIGN
    $DEVICE_ATSIGN = Norm-Atsign $DEVICE_ATSIGN
    $DEVICE_MANAGER_ATSIGN = Norm-Atsign $DEVICE_MANAGER_ATSIGN
    $SSHNPD_VERSION =  Norm-Version $SSHNPD_VERSION
}

function Cleanup {
    if (Test-Path "$HOME_PATH/.atsign/temp/$SSHNPD_VERSION") {
        Remove-Item -Path "$HOME_PATH/.atsign/temp/$SSHNPD_VERSION" -Recurse -Force
    }
}

function Download-Archive {
    Write-Host "Downloading $BINARY_NAME from $global:URL"
    $DOWNLOAD_BODY = $(Invoke-WebRequest -Uri $global:URL).ToString() -split "," | Select-String "browser_download_url" | Select-String "sshnp-windows"
    $DOWNLOAD_URL = $DOWNLOAD_BODY.ToString() -split '"' | Select-Object -Index 3
    Write-Host $DOWNLOAD_URL
    New-Item -Path "$HOME_PATH/.atsign/temp/$SSHNPD_VERSION" -ItemType Directory -Force
    Invoke-WebRequest -Uri $DOWNLOAD_URL -OutFile "$HOME_PATH/.atsign/temp/$SSHNPD_VERSION/$BINARY_NAME.zip"
    if (-not (Test-Path "$HOME_PATH/.atsign/temp/$SSHNPD_VERSION/$BINARY_NAME.zip")) {
        Write-Host "Failed to download $BINARY_NAME"
        #Cleanup
        Exit 1
    }
}

function Unpack-Archive {
    if (-not (Test-Path "$HOME_PATH/.atsign/temp/$SSHNPD_VERSION/$BINARY_NAME.zip")) {
        Write-Host "Failed to download $BINARY_NAME"
        Exit 1
    }

    Expand-Archive -Path "$HOME_PATH/.atsign/temp/$SSHNPD_VERSION/$BINARY_NAME.zip" -DestinationPath "$HOME_PATH/.atsign/temp/$SSHNPD_VERSION/" -Force
    if (-not (Test-Path "$HOME_PATH/.atsign/temp/$SSHNPD_VERSION/sshnp/sshnp.exe")) {
        Write-Host "Failed to unpack $BINARY_NAME"
        Cleanup
        Exit 1
    }
    $global:BIN_PATH = "$HOME_PATH/.atsign/temp/$SSHNPD_VERSION/$BINARY_NAME"
    Remove-Item -Path "$HOME_PATH/.atsign/temp/$SSHNPD_VERSION/$BINARY_NAME.zip" -Force
}

# Main function
function Main {
    # Check basic requirements
    Check-BasicRequirements
    Parse-Env
    Make-Dirs
    Download-Archive
    Unpack-Archive
}

# Execute the main function
Main
