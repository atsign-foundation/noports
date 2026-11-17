## 1.0.0+1

- FEAT: NoPorts Configuration, a desktop app for the device side of NoPorts:
  edit `sshnpd.yaml` with the same options and checks as the daemon, start,
  stop and watch the sshnpd service, enroll the device's keys through APKAM
  (approved from NoPorts Desktop's Authenticator tab) or import a key file,
  and run diagnostics that mirror `sshnpd --doctor`.
- FEAT: A first-run wizard that fills in the device name from the hostname,
  enrolls the keys, sets who may connect, then saves and starts the daemon
  with a single administrator prompt.
- FEAT: Windows (x64 and arm64, inside the NoPorts MSI), Linux (x64 and
  arm64, `noports-config` deb and rpm) and macOS (universal, Homebrew cask).
- FEAT: On Linux the daemon is made to run as the user who enrolled, the way
  universal.sh arranges it, so it can read the keys in that account's home;
  the saved config is root-owned and readable through that user's group only.
