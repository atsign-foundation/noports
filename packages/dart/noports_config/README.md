<a href="https://atsign.com#gh-light-mode-only"><img width=250px src="https://atsign.com/wp-content/uploads/2022/05/atsign-logo-horizontal-color2022.svg#gh-light-mode-only" alt="The Atsign Foundation"></a><a href="https://atsign.com#gh-dark-mode-only"><img width=250px src="https://atsign.com/wp-content/uploads/2023/08/atsign-logo-horizontal-reverse2022-Color.svg#gh-dark-mode-only" alt="The Atsign Foundation"></a>

# NoPorts Configuration

Desktop app for configuring the NoPorts daemon (`sshnpd`) on the machine it
runs on. It edits `sshnpd.yaml`, gets the device atSign's keys in place,
starts, stops and restarts the system service, shows its log, and runs
diagnostics. On a fresh install it walks the user through setup.

It is a Flutter desktop app, built for Windows (shipped inside the NoPorts
MSI), and buildable for macOS and Linux. It is not the NoPorts Desktop
client (`npt_flutter`); that app runs on the machine you connect *from*,
this one on the machine you connect *to*.

## What it does

| Tab | Purpose |
| --- | --- |
| Status | Live service state, Start / Stop / Restart, start mode, PID, last exit code, recent log lines from the platform log (Event Log, launchd, journald). |
| Configuration | A form generated from the daemon's own option definitions, plus a raw YAML editor over the same document. Save, Revert, Save and restart. Comments in the file are preserved. |
| Keys | Shows which `.atKeys` file the daemon will use and whether it exists. Enrolls the device through APKAM: the user pastes the OTP or PIN from the Authenticator tab of NoPorts Desktop on their client, the request is approved there, and the new keys land in `<config dir>/keys` where the service account can read them. Importing an existing `.atKeys` file is kept as a secondary option for fleets and recovery. |
| Diagnostics | In-app checks (config valid, keys present, access configured, binary present, atDirectory reachable, service state) and a button to run `sshnpd --doctor` for the full report. |

When `sshnpd.yaml` has no device atSign the app opens on a four step
wizard (Device, Keys, Access, Finish) that saves the config, starts the
service and runs the checks. The Keys step is the APKAM enrollment above,
mirroring `at_activate enroll -p noports -n "sshnp:rw,sshrvd:rw"` from the
install docs; the device atSign itself is activated beforehand in NoPorts
Desktop, never here.

## Platform notes

* **Windows.** Requires administrator; the manifest requests it so a UAC
  prompt appears on launch. Config lives at `%ProgramData%\NoPorts\sshnpd.yaml`,
  the service is `sshnpd` (controlled with `sc.exe`), logs come from the
  Application Event Log. The MSI installs the app under
  `Program Files\NoPorts\NoPortsConfig`, adds a Start Menu shortcut and
  offers to launch it from the installer's finish page.
* **macOS.** Needs root to write `/Library/Application Support/NoPorts`
  and drive `launchctl` (label `com.atsign.sshnpd`). When launched as a
  normal user the app relaunches itself through the system password prompt
  (`osascript ... with administrator privileges`) and exits. Not sandboxed.
* **Linux.** `/etc/noports/sshnpd.yaml`, `systemctl`, `journalctl`. Relaunches
  through `pkexec` when not root.
* Set `NOPORTS_CONFIG_NO_ELEVATE=1` to skip the relaunch, e.g. under
  `flutter run`; the UI then shows what it cannot do.

## Layout

```
lib/
  main.dart, app.dart             window setup, providers, theme, l10n
  styles/                         colours, spacing, theme (ported from npt_flutter)
  widgets/                        app bar with tabs, cards, pills, snack bars, log panel
  platform/
    daemon_paths.dart             where config / keys / binaries live per OS
    service_manager.dart          abstract service control + factory
    elevation.dart                relaunch as root on macOS / Linux
    windows_/macos_/linux_service_manager.dart
  features/
    config/
      model/config_schema.dart    THE list of editable fields (see below)
      model/sshnpd_config_document.dart  yaml_edit wrapper, typed accessors, validation
      config_repository.dart      load / save with backup
      cubit/, view/, widgets/
    service/                      ServiceCubit (polls status), Status tab
    keys/                         APKAM enrollment (EnrollmentCubit), import, Keys tab
    health/                       HealthCheck classes, Diagnostics tab
    wizard/                       first-run flow
  pages/                          HomePage, NavCubit
  l10n/app_en.arb                 UI strings (generate with `flutter gen-l10n`)
assets/sshnpd.template.yaml       copy of bundles/core/config/sshnpd.yaml (a test enforces this)
```

## Extending

* **Expose another daemon option**: add a `ConfigField` to
  `ConfigSchema.fields` pointing at the matching `SshnpdOption`. The YAML
  path, help text and default come from noports_core, so only label, kind
  and section are needed. The form, validation hooks and wizard pick it up.
* **Add a diagnostic**: subclass `HealthCheck` in `health_checks.dart` and
  add it to `HealthChecks.all()`.
* **Support another service manager**: implement `ServiceManager` and
  return it from `ServiceManager.forPlatform()`.
* **Strings**: UI chrome is in `lib/l10n/app_en.arb`; field labels and
  help live in the schema next to the field they describe.

## Developing

```bash
flutter pub get
flutter gen-l10n           # after editing app_en.arb
flutter analyze
flutter test
flutter run -d macos       # or windows / linux
flutter build windows --release
```

On Windows, `flutter run` must itself be started from an elevated shell
because of the `requireAdministrator` manifest.

## Release

Built by `.github/workflows/multibuild.yaml` on the Windows runner, signed
with the other executables, and picked up by `tools/windows-msi/noports.wxs`
from `tools/windows-msi/bin/noports_config/`.
