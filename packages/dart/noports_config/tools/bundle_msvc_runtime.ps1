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
  Folder containing noports_config.exe. Defaults to the x64 release output.

.PARAMETER Arch
  Which redist to bundle: x64, arm64 or x86. The DLLs are not
  interchangeable between CPU architectures. Defaults to the architecture
  segment of the Destination path (build\windows\<arch>\...), which is what
  `flutter build windows` produced. An x64 app running under emulation on a
  Windows ARM PC still needs the x64 DLLs.
#>
param(
  [string]$Destination = "build\windows\x64\runner\Release",
  [ValidateSet('x64', 'arm64', 'x86')]
  [string]$Arch
)

$ErrorActionPreference = 'Stop'
$dlls = @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')

if (-not $Arch) {
  if ($Destination -match '[\\/](x64|arm64|x86)[\\/]') { $Arch = $Matches[1] }
  else { Write-Error "Cannot tell the CPU architecture from '$Destination'; pass -Arch." }
}

function Find-RedistDir {
  $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
  if (Test-Path $vswhere) {
    $vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Redist.14.Latest -property installationPath
    if (-not $vs) { $vs = & $vswhere -latest -products * -property installationPath }
    if ($vs) {
      # Newest toolset first. VS 2022 and VS 2026 both ship the 14.4x toolset
      # as Microsoft.VC143.CRT; match any VC14x so a future rename does not
      # break the build (the three DLL names have been stable since VS 2015).
      $crt = Get-ChildItem -Path (Join-Path $vs 'VC\Redist\MSVC') -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending |
        ForEach-Object { Get-ChildItem -Path (Join-Path $_.FullName $Arch) -Directory -Filter 'Microsoft.VC14*.CRT' -ErrorAction SilentlyContinue } |
        Sort-Object Name -Descending |
        Select-Object -First 1 -ExpandProperty FullName
      if ($crt) { return $crt }
    }
  }
  if ($env:VCToolsRedistDir) {
    $crt = Get-ChildItem -Path (Join-Path $env:VCToolsRedistDir $Arch) -Directory -Filter 'Microsoft.VC14*.CRT' -ErrorAction SilentlyContinue |
      Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty FullName
    if ($crt) { return $crt }
  }
  return $null
}

$src = Find-RedistDir
if (-not $src) {
  Write-Error "Could not find the $Arch Visual C++ redist folder (Microsoft.VC14x.CRT). Is Visual Studio with the C++ workload installed?"
}
if (-not (Test-Path $Destination)) {
  Write-Error "Destination $Destination does not exist. Run 'flutter build windows --release' first."
}

foreach ($dll in $dlls) {
  $from = Join-Path $src $dll
  if (-not (Test-Path $from)) { Write-Error "Missing $from" }
  Copy-Item $from -Destination $Destination -Force
  Write-Host "Bundled $Arch $dll from $src"
}
