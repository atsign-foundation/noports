<#
.SYNOPSIS
  Copies the Visual C++ runtime DLLs a Flutter Windows release needs into
  the build output, so the app runs on machines without the VC redist.

.DESCRIPTION
  flutter_windows.dll and the runner link the MSVC runtime dynamically.
  Microsoft allows app-local deployment of these three DLLs; the Flutter
  docs recommend exactly this for apps not shipped as MSIX (an MSIX would
  declare the VCLibs framework dependency instead).

  Looks in the Visual Studio redist folder (via vswhere, then
  VCToolsRedistDir). Fails loudly if they cannot be found so CI does not
  ship a bundle that only works on developer machines.

.PARAMETER Destination
  Folder containing noports_config.exe. Defaults to the release output.
#>
param(
  [string]$Destination = "build\windows\x64\runner\Release"
)

$ErrorActionPreference = 'Stop'
$dlls = @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')

function Find-RedistDir {
  $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
  if (Test-Path $vswhere) {
    $vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Redist.14.Latest -property installationPath
    if (-not $vs) { $vs = & $vswhere -latest -products * -property installationPath }
    if ($vs) {
      $crt = Get-ChildItem -Path (Join-Path $vs 'VC\Redist\MSVC') -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending |
        ForEach-Object { Join-Path $_.FullName 'x64\Microsoft.VC143.CRT' } |
        Where-Object { Test-Path $_ } |
        Select-Object -First 1
      if ($crt) { return $crt }
    }
  }
  if ($env:VCToolsRedistDir) {
    $crt = Join-Path $env:VCToolsRedistDir 'x64\Microsoft.VC143.CRT'
    if (Test-Path $crt) { return $crt }
  }
  return $null
}

$src = Find-RedistDir
if (-not $src) {
  Write-Error "Could not find the Visual C++ redist folder (Microsoft.VC143.CRT). Is Visual Studio with the C++ workload installed?"
}
if (-not (Test-Path $Destination)) {
  Write-Error "Destination $Destination does not exist. Run 'flutter build windows --release' first."
}

foreach ($dll in $dlls) {
  $from = Join-Path $src $dll
  if (-not (Test-Path $from)) { Write-Error "Missing $from" }
  Copy-Item $from -Destination $Destination -Force
  Write-Host "Bundled $dll from $src"
}
