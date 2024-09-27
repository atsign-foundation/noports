<#
.SYNOPSIS
   Installation script for sshnpd on Windows
.DESCRIPTION
    Usage: universal.ps1 

    Sshnp Version: 5.2.0
    Repository: https://github.com/atsign-foundation/sshnoports
    Script Version: 0.1.0
#>
#Prints the help message via get-help install_sshnpd-windows.ps1 
param(
    [string]$CLIENT_ATSIGN,
    [string]$DEVICE_MANAGER_ATSIGN,
    [string]$DEVICE_ATSIGN,
    [string]$DEVICE_NAME,
    [string]$INSTALL_TYPE,
    [string]$HOST_ATSIGN,
    [string]$VERSION,
    [switch]$dev = $false
)

### --- IMPORTANT ---
#Make sure to change the values in the help message.
#The help message must be at the top of the script, so no variables.

# SCRIPT METADATA
$script_version = "0.1.0"
$sshnp_version = "5.2.0"
$repo_url = "https://github.com/atsign-foundation/sshnoports"
# END METADATA

function Norm-Atsign {
    param([string]$str)
    $atsign = "@$($str -replace '"', '' -replace '^@', '')"
    if($atsign -eq "@"){
        return $null
    }
    return $atsign
}

function Norm-Version {
    param([string]$str)
    $version = "tags/v$($str -replace '"', '' -replace '^tags/', '' -replace '^v', '')"
    return $version
}

function Norm-InstallType {
    param([string]$str)
    $str = $str.ToLower()
    switch -regex ($str) {
        "^d.*" { return "device" }
        "^c.*" { return "client" }
        "^u.*" { return "uninstall"}
        default { return $null }
    }
}

function Check-BasicRequirements {
    $requiredCommands = @("attrib", "Expand-Archive", "Select-String", "Select-Object", "Start-Service","Test-Path", "New-Item", "Get-Command", "New-Object", "Invoke-WebRequest", "New-Service")
    
    foreach ($command in $requiredCommands) {
        if (-not (Get-Command -Name $command -ErrorAction SilentlyContinue)) {
            Write-Host "[X] Missing required dependency: $command"
        }
    }
}

function Make-Dirs {
    Write-Host $env:HOME
    if (-not (Test-Path "$env:HOME\.atsign")) {
        New-Item -Path "$env:HOME\.atsign" -ItemType Directory -Force
    }
    if(-not (Test-Path "$env:HOME\.atsign\keys")){
        New-Item -Path "$env:HOME\.atsign\keys" -ItemType Directory -Force
    }
    if (-not (Test-Path "$env:HOME\.ssh")) {
        New-Item -Path "$env:HOME\.ssh" -ItemType Directory -Force
    }

    if(-not (Test-Path $ARCHIVE_PATH)){
        New-Item -Path "$ARCHIVE_PATH" -ItemType Directory -Force
    }
    if(-not (Test-Path $INSTALL_PATH)){
        New-Item -Path "$INSTALL_PATH" -ItemType Directory -Force
    }

    if (-not (Test-Path "$env:HOME\.ssh\authorized_keys" -PathType Leaf)) {
        New-Item -Path "$env:HOME\.ssh\authorized_keys" -ItemType File -Force
        attrib "$env:HOME\.ssh\authorized_keys" +h
    }
}
function Parse-Env {
    $script:VERSION = if ([string]::IsNullOrEmpty($VERSION)) { "latest" } else { Norm-Version $VERSION }
    $script:SSHNP_URL = "https://api.github.com/repos/atsign-foundation/noports/releases/$VERSION"
    $script:WINSW_URL = "https://api.github.com/repos/winsw/winsw/releases/$VERSION"
    $script:ARCHIVE_PATH =  "$env:LOCALAPPDATA\atsign\$VERSION"
    $script:homepath = if (-not [string]::IsNullOrEmpty($env:HOME)) { $env:HOME } else { $env:USERPROFILE }
    $script:INSTALL_PATH =  "$homepath\.local\bin"
    $script:INSTALL_TYPE = Norm-InstallType "$script:INSTALL_TYPE"
    #Setting to silence download progress bars, see more 
    #https://learn.microsoft.com/en-ca/powershell/module/microsoft.powershell.core/about/about_preference_variables?view=powershell-7.4#progresspreference 
    $global:ProgressPreference = 'SilentlyContinue'
    if ($script:INSTALL_TYPE -eq "device") {
        if (Get-Service "sshnpd" -ErrorAction SilentlyContinue){
            Invoke-Expression "sshnpd_service stop" -ErrorAction SilentlyContinue | Out-Null
            Invoke-Expression "sshnpd_service uninstall" -ErrorAction SilentlyContinue | Out-Null
        }
        if (Test-Path "$script:INSTALL_PATH\sshnp\sshnpd.exe"){
            Remove-Item -Path "$script:INSTALL_PATH\sshnp\sshnpd.exe" -Force | Out-Null
        }
        if (Test-Path "$script:INSTALL_PATH\sshnp\sshnpd_service.xml"){
            Remove-Item -Path "$script:INSTALL_PATH\sshnp\sshnpd_service.xml" -Force | Out-Null
        }
        if (Test-Path "$script:INSTALL_PATH\sshnp\sshnpd_service.exe"){
            Remove-Item -Path "$script:INSTALL_PATH\sshnp\sshnpd_service.exe" -Force | Out-Null
        }        
    }
    if ($script:INSTALL_TYPE -eq "client") {
        if (Test-Path "$script:INSTALL_PATH\sshnp\sshnp.exe"){
            Remove-Item -Path "$script:INSTALL_PATH\sshnp\sshnp.exe" -Force | Out-Null
        }
    }
}
function Cleanup {
    if (Test-Path "$ARCHIVE_PATH") {
        Remove-Item -Path "$ARCHIVE_PATH" -Recurse -Force
    }
    #Default value for this preference.
    $global:ProgressPreference = "Continue"
}
function Unpack-Archive {
    if (-not (Test-Path "$ARCHIVE_PATH\sshnp.zip")) {
        Write-Host "Failed to download sshnp"
        Exit 1
    }
    if (Test-Path "$script:INSTALL_PATH\sshnp"){
        Remove-Item -Path "$script:INSTALL_PATH\sshnp" -Recurse -Force
    }
    Expand-Archive -Path "$ARCHIVE_PATH\sshnp.zip" -DestinationPath $INSTALL_PATH -Force | Out-Null
    if (-not (Test-Path "$INSTALL_PATH/sshnp/sshnp.exe")) {
        Write-Host "Failed to unpack sshnp"
        Cleanup
        Exit 1
    }
}

function Download-Sshnp {
    Write-Host "Downloading sshnp from $SSHNP_URL..."
    $DOWNLOAD_BODY = $(Invoke-WebRequest -Uri $SSHNP_URL).ToString() -split "," | Select-String "browser_download_url" | Select-String "sshnp-windows" | Select-Object -Index 0
    $DOWNLOAD_URL = $DOWNLOAD_BODY.ToString() -split '"' | Select-Object -Index 3
    Invoke-WebRequest -Uri $DOWNLOAD_URL -OutFile "$ARCHIVE_PATH\sshnp.zip" | Out-Null
    if (-not (Test-Path "$ARCHIVE_PATH\sshnp.zip")) {
        Write-Host "Failed to download sshnp"
        Cleanup
        Exit 1
    }
    Unpack-Archive
}

function Download-Winsw {
    $DOWNLOAD_BODY = $(Invoke-WebRequest -Uri $script:WINSW_URL).ToString() -split "," | Select-String "browser_download_url" | Select-String "WinSW-x64" 
    $DOWNLOAD_URL = $DOWNLOAD_BODY.ToString() -split '"' | Select-Object -Index 3
    Write-Host "Installing sshnpd Windows Service..."
    Invoke-WebRequest -Uri $DOWNLOAD_URL -OutFile "$script:INSTALL_PATH\sshnp\sshnpd_service.exe" | Out-Null
    if (-not (Test-Path "$script:INSTALL_PATH\sshnp\sshnpd_service.exe")) {
        Write-Host "Failed to download winsw"
        Cleanup
        Exit 1
    }
}

function Add-ToPath {
    $pathToAdd = "$script:INSTALL_PATH\sshnp"
    if (Test-Path $script:INSTALL_PATH){
        if ($env:Path -notlike "*$pathToAdd*") {
            $newPath = ($env:Path + ";" + $pathToAdd)
            [Environment]::SetEnvironmentVariable("PATH", $newPath, [EnvironmentVariableTarget]::User)
        } else {
            Write-Host "Path already exists in the environment variable PATH."
        }
    } else {
        Throw "'$pathToAdd' is not a valid path."
    }
}
function Get-InstallType { 
    if ([string]::IsNullOrEmpty($script:INSTALL_TYPE)) {
        while ([string]::IsNullOrEmpty($script:INSTALL_TYPE)) {
            $install_type_input = Read-Host "Install type (device, client, uninstall)"
            $script:INSTALL_TYPE = Norm-InstallType $install_type_input
        }
    }
}
function Get-Atsigns {
    $directory = "$homepath\.atsign\keys"
    $prefixes = @()
    if (Test-Path $directory -PathType Container) {
        $files = Get-ChildItem -Path $directory -Filter "*.atKeys" -File
        foreach ($file in $files) {
            $prefix = $file.BaseName -replace '_key$'
            $prefixes += $prefix
        }
    }
    if (-not ([string]::IsNullOrEmpty($prefixes))) {
        $i = 1
        Write-Host "0) Manually Enter:"
        foreach($prefix in $prefixes){
            Write-Host "$i) $prefix"
            $i = $i + 1
        }
        $i = Read-Host "Choose an atsign (input number)"
        while(-not ($i -match "^\d+$")){
            $i = Read-Host "Choose an atsign (input number)"
        }
        if($i -eq 0){
            $at = Read-Host "Enter your atsign"
            return Norm-Atsign $at
        }
        return $prefixes[$i-1]
    } else {
        Write-Host "No atsigns found, please get one at  https://www.my.atsign.com/go"
        Write-Host "Exiting.."
        Cleanup
        Start-Sleep -Seconds 3  
        Exit 1
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
            switch -regex ($host_atsign.ToLower()) {
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
                    $host_atsign = Read-Host "Region"
                }
            }
        }
        $script:HOST_ATSIGN = $host_atsign
    }
    $clientPath = "$script:INSTALL_PATH\sshnp\$script:DEVICE_NAME$script:DEVICE_ATSIGN.ps1"
    "sshnp.exe -f '$script:CLIENT_ATSIGN' -t '$script:DEVICE_ATSIGN' -d '$script:DEVICE_NAME' -r '$script:HOST_ATSIGN' -s -u '$Env:UserName'"  | Out-File -FilePath  $clientPath
    if (-not (Test-Path $clientPath -PathType Leaf)) {
        Write-Host "Failed to create client script'. Please check your permissions and try again."
        Cleanup
        Exit 1
    } 
    Write-Host "Created client script for $script:DEVICE_NAME$script:DEVICE_ATSIGN"
}

function Install-Device {
    Write-Host "Installed at_activate and sshnpd binaries to $script:INSTALL_PATH" 
    Download-Winsw
    New-Item -Path "$script:INSTALL_PATH\sshnp\" -Name "logs" -ItemType "directory" 
    $servicePath = "$script:INSTALL_PATH\sshnp\sshnpd.exe"
    $xmlPath = "$script:INSTALL_PATH\sshnp\sshnpd_service.xml"
    [xml]$xmlContent = Get-Content $xmlPath
    $xmlContent.service.arguments = "-a $script:DEVICE_ATSIGN -m $script:CLIENT_ATSIGN -d $script:DEVICE_NAME -k $script:homepath/.atsign/keys/$script:DEVICE_ATSIGN"+ "_key.atKeys -s"
    $xmlEnv = $xmlContent.service.env | Where-Object {$_.Name -eq "USERPROFILE"}
    $xmlEnv.Value = $script:homepath 
    $xmlContent.Save($xmlPath)
    if (-not (Test-Path $servicePath -PathType Leaf)) {
        Write-Host "Failed to create service script'. Please check your permissions and try again."
        Cleanup
        Exit 1
    } 
    try {
        Invoke-Expression "$script:service_path install" | Out-Null
        Invoke-Expression "$script:service_path start" | Out-Null
    }
    catch {
        Invoke-Expression "$script:service_path stop" -ErrorAction SilentlyContinue
        Invoke-Expression "$script:service_path uninstall" -ErrorAction SilentlyContinue
    }
}

function Uninstall-Both{
    if (Get-Service "sshnpd" -ErrorAction SilentlyContinue){
        Invoke-Expression "$script:service_path stop" -ErrorAction SilentlyContinue 
        Invoke-Expression "$script:service_path uninstall" -ErrorAction SilentlyContinue
    }
    if (Test-Path "$script:INSTALL_PATH\sshnp"){
        Remove-Item -Path "$script:INSTALL_PATH\sshnp" -Recurse -Force
    }
    Cleanup
    Write-Host "Uninstall complete, exiting.."
    Start-Sleep -Seconds 3
    exit 1
}

# Main function
function Main {
    if ([string]::IsNullOrEmpty($script:INSTALL_TYPE)){ 
        Get-InstallType
    }
    Parse-Env
    $script:service_path = "$script:INSTALL_PATH\sshnp\sshnpd_service.exe"
    if ($script:INSTALL_TYPE -eq "uninstall"){
        Uninstall-Both
    }
    Check-BasicRequirements
    if ($dev) {
        Write-Host "---- Dev Mode -----"
        if(-not (Test-Path .\packages\dart\sshnoports\bundles\windows\sshnpd_service.xml)){
            Write-Host "Please use dev mode inside the repo at the root directory of noports"
            Cleanup 
            Exit 1
        }
    }
    Make-Dirs
    Download-Sshnp
    Add-ToPath
    if($dev) {
        Copy-Item .\packages\dart\sshnoports\bundles\windows\sshnpd_service.xml "$script:INSTALL_PATH/sshnp"
    }
    while ([string]::IsNullOrEmpty($script:DEVICE_ATSIGN)){
        Write-Host "Selecting a Device atsign.."
        $atsign = Get-Atsigns
        $script:DEVICE_ATSIGN =  Norm-Atsign $atsign
    }
    while([string]::IsNullOrEmpty($script:CLIENT_ATSIGN)){
        Write-Host "Selecting a Client atsign.."
        $atsign = Get-Atsigns
        $script:CLIENT_ATSIGN =  Norm-Atsign $atsign
    }
    $script:DEVICE_NAME = Read-Host "Device Name "
    switch -regex ($INSTALL_TYPE){
        "client" {
            Install-Client
        }
        "device" {
            Install-Device
        }
    }
    Cleanup
    Write-Host "Successfully installed $script:INSTALL_TYPE at $script:INSTALL_PATH, script ending..."
    Start-Sleep -Seconds 10
}
# Execute the main function
Main