<a href="https://atsign.com#gh-light-mode-only"><img width=250px src="https://atsign.com/wp-content/uploads/2022/05/atsign-logo-horizontal-color2022.svg#gh-light-mode-only" alt="The Atsign Foundation"></a><a href="https://atsign.com#gh-dark-mode-only"><img width=250px src="https://atsign.com/wp-content/uploads/2023/08/atsign-logo-horizontal-reverse2022-Color.svg#gh-dark-mode-only" alt="The Atsign Foundation"></a>

# NoPorts Configuration

Desktop app for configuring the NoPorts daemon (`sshnpd`) on the machine it
runs on. It edits `sshnpd.yaml`, gets the device atsign's keys in place,
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
| Keys | Shows which `.atKeys` file the daemon will use and whether it exists. Enrolls the device through APKAM: the user pastes the OTP or PIN from the Authenticator tab of NoPorts Desktop on their client, the request is approved there, and the new keys land in the user's own `~/.atsign/keys` (where `at_activate` puts them); `sshnpd.yaml` gets the absolute path so the daemon's account (LocalSystem on Windows, the unit's `User=` on Linux, the user themselves on macOS) can read the file. Existing key files are never overwritten. Importing an existing `.atKeys` file is kept as a secondary option for fleets and recovery. |
| Diagnostics | In-app checks (config valid, keys present, access configured, binary present, atDirectory reachable, service state) and a button to run `sshnpd --doctor` for the full report. |

When `sshnpd.yaml` has no device atsign the app opens on a four step
wizard (Device, Keys, Access, Finish) that saves the config, starts the
service and runs the checks. The Keys step is the APKAM enrollment above,
mirroring `at_activate enroll -p noports -n "sshnp:rw,sshrvd:rw"` from the
install docs; the device atsign itself is activated beforehand in NoPorts
Desktop, never here.

## Platform notes

* **Privileges.** Installing NoPorts and this app needs root or
  administrator rights and is the package manager's or the MSI's job, not
  the app's. The app itself runs as the ordinary user. Only operations
  that need it go through `PrivilegedRunner`, which prompts each time;
  today that is Linux config writes and systemctl. Keys the app writes are
  always owned by the user.
* **The daemon's account on Linux.** sshnpd runs as its unit's `User=`,
  and that account is the one whose `~/.atsign/keys` it reads and whose
  `~/.ssh/authorized_keys` it adds session keys to, so it has to be the
  person who enrolled. The noports package ships
  `/etc/systemd/system/sshnpd.service.d/override.conf` with `User=1000`
  as a placeholder (the file `systemctl edit sshnpd` edits), and
  universal.sh replaces it with the user who ran the install. The app does
  the same for the user running it: when the unit's account differs, the
  save-and-restart call also rewrites that `User=` line (or adds one) and
  reloads systemd, and the result says so. `sudo systemctl edit sshnpd`
  changes it afterwards; the Diagnostics tab reports keys the daemon's
  account cannot read.
* **Windows.** The linker's `/MANIFESTUAC` requests administrator so a UAC
  prompt appears on launch (Windows has no per-operation prompt); the user
  account is still the same, so keys go to `%USERPROFILE%\.atsign\keys`.
  The release bundle needs the Visual C++ runtime; CI copies
  `msvcp140.dll`, `vcruntime140.dll` and `vcruntime140_1.dll` next to the
  exe with `tools/bundle_msvc_runtime.ps1` (app-local deployment, as the
  Flutter docs recommend for non-MSIX apps). The script picks the x64,
  arm64 or x86 redist to match the build output: the MSI ships for x64
  and, experimentally, native arm64.
  Run it yourself after a local `flutter build windows` if the target
  machine lacks the VC redist. Config lives at `%ProgramData%\NoPorts\sshnpd.yaml`,
  the service is `sshnpd` (controlled with `sc.exe`), logs come from the
  Application Event Log. The MSI installs the app under
  `Program Files\NoPorts\NoPortsConfig`, adds a Start Menu shortcut and
  offers to launch it from the installer's finish page.
* **macOS.** Everything is per user and nothing needs root. NoPorts itself
  comes from Homebrew (`brew tap atsign-foundation/homebrew-tap && brew
  install noports`, binaries in the brew prefix) or universal.sh (binaries
  in `~/.local/bin`); the app looks in both. Config is
  `~/Library/Application Support/NoPorts/sshnpd.yaml`, the daemon is the
  `com.atsign.sshnpd` LaunchAgent in `~/Library/LaunchAgents`, log in
  `~/.sshnpd/logs/sshnpd.log`. multibuild.yaml builds, signs and notarises
  the app as `noports-config-macos-universal.zip` on each release so it can
  be offered as a cask in the same tap. The app can install the LaunchAgent, or
  rewrite a legacy one that passes settings as command line flags (those
  override the YAML), so the daemon runs with `--config <yaml>`. An
  existing system-wide `/Library/Application Support/NoPorts/sshnpd.yaml`
  is used to seed the per-user file. Not sandboxed.
* **Linux.** Installed from the package manager, never as loose binaries:
  `sudo apt install noports-config` or `sudo dnf install noports-config`
  from apt.noports.com / rpm.noports.com. `nfpm.yaml` here builds the deb
  and rpm in multibuild.yaml next to the `noports` package, which it
  depends on; the Flutter bundle goes to `/usr/lib/noports-config` with a
  `noports-config` launcher on PATH, a desktop entry and an icon. Runtime
  dependencies (`libgtk-3-0`, `zenity` for the file picker, polkit for
  `pkexec`) are declared in the package. Config is `/etc/noports/sshnpd.yaml`,
  service control via `systemctl`, logs via `journalctl`. Flutter desktop
  builds for x64 and arm64 only, so there is no app for the daemon's armv7
  and riscv64 targets.

## Layout

```
lib/
  main.dart, app.dart             window setup, providers, theme, l10n
  styles/                         colours, spacing, theme (ported from npt_flutter)
  widgets/                        app bar with tabs, cards, pills, snack bars, log panel
  platform/
    daemon_paths.dart             where config / keys / binaries live per OS
    service_manager.dart          abstract service control + factory
    privileged_runner.dart        run one command as admin (osascript / pkexec / direct)
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
because of the `requireAdministrator` manifest. On macOS and Linux run it
as yourself; the password prompt appears when you save or touch the service
(on Linux, "Save and restart" asks once: the restart rides in the same
`pkexec` call as the write).

### End-to-end tests against an ephemeral environment

Two tagged suites exercise the real flows and are skipped unless they are
pointed at an atsign ephemeral environment (EE, the `atsigncompany/ephemeral`
image) with three atsigns onboarded by `at_activate onboard`: the device,
the manager and a relay.

```bash
# enroll with a bare atsign (OTP issued and approved with at_activate),
# save sshnpd.yaml, run the checks and the doctor, start sshnpd from that
# file and list the device from the manager atsign
EE_ROOT=vip.ve.atsign.zone:2500 EE_KEYS=/path/to/keys \
  flutter test --tags ee test/ee_enrollment_test.dart

# Linux only, as root, with the noports package installed: the real
# /etc/noports, the packaged systemd unit and journald, one-call save and
# restart, every in-app check and the doctor against the live unit
sudo -E env PATH=$PATH EE_ROOT=... EE_DEVICE_KEYS=/path/@device_key.atKeys \
  flutter test --tags linux-root test/linux_root_test.dart
```

`EE_BIN` points the first suite at the daemon binaries (`/usr/bin` for the
Linux package; `~/.local/bin` by default).

## CI and test builds

`.github/workflows/noports_config_tests.yaml` analyzes, tests and builds
five targets (Windows x64 / arm64, Linux x64 / arm64, macOS universal) on
pushes to trunk and on pull requests, keeping one archive per target as a
run artifact for 30 days. Every job installs the one Flutter release pinned
in the workflow and resolves with `--enforce-lockfile`.
Start it by hand from the Actions tab with **sign_artifacts** ticked and the
Windows and macOS archives are signed (Azure Trusted Signing; Developer ID
plus notarisation) and replace the unsigned artifacts on that run. Nothing
is ever released or tagged from this workflow: releases come only from
`v*` tags on trunk through multibuild.yaml, which the OpenSSF Scorecard
Signed-Releases check depends on.

## Release

Built by `.github/workflows/multibuild.yaml` on the Windows runner, signed
with the other executables, and picked up by `tools/windows-msi/noports.wxs`
from `tools/windows-msi/bin/noports_config/`.
