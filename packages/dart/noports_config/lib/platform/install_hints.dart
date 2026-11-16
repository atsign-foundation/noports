import 'dart:io';

/// How NoPorts is meant to be installed on each platform, for the messages
/// shown when the daemon binary or service is missing. Linux installs go
/// through the distribution package manager, never loose binaries.
class InstallHints {
  InstallHints._();

  /// The installation guide. apt.noports.com and rpm.noports.com are
  /// package repositories, not pages a person can open, so user-facing
  /// text points here instead.
  static const String docsUrl =
      'https://docs.noports.com/installation/advanced-installation-guides';

  static String get installNoPorts {
    if (Platform.isWindows) {
      return 'Reinstall NoPorts from the MSI with the command-line tools '
          'feature selected.';
    }
    if (Platform.isMacOS) {
      return 'Install NoPorts with Homebrew: '
          '"brew tap atsign-foundation/homebrew-tap && brew install noports". '
          'Installing with universal.sh (sshnpd in ~/.local/bin) also works.';
    }
    return 'Install the noports package with your package manager: '
        '"sudo apt install noports" on Debian and Ubuntu or '
        '"sudo dnf install noports" on Fedora and RHEL. The installation '
        'guide at $docsUrl shows how to add the NoPorts repository first.';
  }

  /// Why there is no service and what to do about it.
  static String get installService {
    if (Platform.isWindows) {
      return 'No sshnpd service is registered on this machine. Reinstall '
          'NoPorts from the MSI with the daemon service feature selected.';
    }
    if (Platform.isLinux) {
      return 'No sshnpd systemd unit is installed on this machine. The '
          'noports package provides it. $installNoPorts';
    }
    return 'No sshnpd service is registered. $installNoPorts';
  }
}
