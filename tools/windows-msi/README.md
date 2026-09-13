# SSH No Ports - Windows MSI Build using WiX v6

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

## What the installer shows

WixUI_FeatureTree: Welcome, License, Custom Setup, Ready, Progress, Finish.

- `noports.wxs` holds the features (Command-line tools, Device daemon service,
  NoPorts Configuration app) with the descriptions shown on Custom Setup, the
  Apps & Features icon, and the Finish page checkbox that launches NoPorts
  Configuration on a fresh install.
- `noports.en-us.wxl` overrides the stock WixUI wording (welcome text, page
  titles). Add a string with the same Id as the WixUI one to change more.
- `banner.bmp` (493x58) and `dialog.bmp` (493x312) are the branding images,
  generated with ImageMagick from `packages/dart/npt_flutter/assets/noports_logo.svg`
  (wordmark) and `packages/dart/npt_flutter/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png`
  (mark); `noports.ico` is a multi-size icon from the same 1024px mark, used
  for Apps & Features, the Start Menu shortcut and the app's own window icon.
  Regenerate:

  ```bash
  MARK=../../packages/dart/npt_flutter/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png
  WM=../../packages/dart/npt_flutter/assets/noports_logo.svg
  magick "$MARK" -define icon:auto-resize=256,128,64,48,32,16 noports.ico
  magick -background none -density 300 "$WM" -resize 136x /tmp/wm136.png
  magick -background none -density 300 "$WM" -resize 120x /tmp/wm120.png
  magick -size 493x312 xc:white \( -size 164x312 xc:"#FFEDE9" \) -gravity NorthWest -composite \
    \( "$MARK" -resize 88x88 \) -gravity NorthWest -geometry +38+36 -composite \
    /tmp/wm136.png -gravity NorthWest -geometry +14+140 -composite \
    -fill "#F05E3E" -draw "rectangle 164,0 166,312" -type TrueColor BMP3:dialog.bmp
  magick -size 493x58 xc:white /tmp/wm120.png -gravity East -geometry +10+0 -composite \
    -fill "#F05E3E" -draw "rectangle 0,55 493,58" -type TrueColor BMP3:banner.bmp
  ```

## Usage

1. Windows MSI expects the windows binaries & services & example config file to be in the windows-msi\bin folder.
    - all dart binaries
    - published C# BinaryServices (sshnpdService.exe, nppService.exe, etc..)
    - example config file (sshnpd.yaml)

    - the NoPorts Configuration app: the contents of `flutter build windows --release`
      (plus the MSVC runtime dlls, see `packages/dart/noports_config/tools/bundle_msvc_runtime.ps1`)
      in `windows-msi\bin\noports_config\`

2. Run the following command to build the MSI installer:
    - `wix build -ext WixToolset.Util.wixext -ext WixToolset.UI.wixext -d ProductVersion=5.15.2 -culture en-US -loc noports.en-us.wxl -arch x64 -o build\NoPorts.msi noports.wxs`

    `-d ProductVersion=<x.y.z>` stamps the MSI's `ProductVersion`, which is what Windows
    shows as the version in Apps & Features and what drives major-upgrade detection. CI
    passes the version from `packages/dart/sshnoports/pubspec.yaml`. Omit the flag and the
    build falls back to `0.0.1`, which marks it unmistakably as a local build.
