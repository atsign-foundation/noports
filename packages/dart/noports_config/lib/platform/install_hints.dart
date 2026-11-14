import 'dart:io';

/// How NoPorts is meant to be installed on each platform, for the messages
/// shown when the daemon binary or service is missing. Linux installs go
/// through the distribution package manager, never loose binaries.
class InstallHints {
  InstallHints._();

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
    return 'Install NoPorts with your package manager: '
        '"sudo apt install noports" on Debian and Ubuntu or '
        '"sudo dnf install noports" on Fedora and RHEL. Repository setup is '
        'at https://apt.noports.com and https://rpm.noports.com.';
  }

  static String get installService {
    if (Platform.isWindows) {
      return 'Reinstall NoPorts from the MSI with the daemon service feature '
          'selected.';
    }
    if (Platform.isLinux) {
      return 'The noports package installs the sshnpd systemd unit. '
          '$installNoPorts';
    }
    return installNoPorts;
  }
}
