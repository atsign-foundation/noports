## 1.0.8

- fix: version number in version.h

## 1.0.7

- fix: switch statement fallthrough warning

## 1.0.6

- fix: more build warnings for openwrt upstream

## 1.0.5

- chore: stricter compile options to match openwrt upstream
- fix: build warnings for openwrt upstream

## 1.0.4

- chore: change source packaging format
  - If you are using 1.0.3 from GitHub releases (non-source code),
    then there is no need to upgrade

## 1.0.3

- fix: uptake segfault bug fix in atsdk

## 1.0.2

- chore: uptake atsdk changes

## 1.0.1

- fix: remove the background thread used to update device_info (now synchronous)

## 1.0.0

- fix: memory leaks on the main daemon process

## 0.4.1

- feat: add Dart compliant at_activate binary in place of existing ones

## 0.4.0

- breaking: reimplement at_activate to conform to dart interface
  - only onboard supported with this new interface

## 0.3.4

- ci: Use TARGETARCH so armv7 builds on arm64 runner

## 0.3.3

- ci: Move armv7 build back to amd64 runner

## 0.3.2

- chore: Fix version numbers

## 0.3.1

- chore: explicitly link cjson
- ci: Use arm64 runners for arm builds

## 0.3.0

- feat: Add at_activate

## 0.2.6

- fix: stabilize monitor connection
  - automatic failover / reconnect after ~40 seconds of down time

## 0.2.5

- fix: uptake some fixes in monitor

## 0.2.4

- fix: Disabled clang-tidy missing-includes, as it malformed header includes
- fix: Restore the malformed headers

## 0.2.3

- Update to atSDK v0.3.1 with type fixes

## 0.2.2

- Fix 32bit support for device_info

## 0.2.1

- Bump at_c to v0.3.0 to have more explicit int types

## 0.2.0

- Beta release of C sshnpd

## 0.1.0

- Initial alpha version of C sshnpd

