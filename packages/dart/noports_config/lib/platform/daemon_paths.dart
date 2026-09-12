import 'dart:io';

import 'package:path/path.dart' as p;

/// Where the daemon, its config and its keys live on each platform.
///
/// These mirror the defaults compiled into sshnpd (see
/// `_defaultConfigFilePath` in noports_core's sshnpd_config.dart) and the
/// install layouts produced by the MSI, the macOS pkg and universal.sh.
/// If those move, update here.
class DaemonPaths {
  DaemonPaths._({
    required this.configDir,
    required this.binDir,
    required this.serviceHomeDir,
    required this.userHomeDir,
    this.configNeedsPrivileges = false,
    this.legacyConfigFiles = const [],
  });

  /// Whether writing [configDir] needs administrator rights (Linux:
  /// /etc/noports). Windows is already elevated; macOS uses a per-user
  /// LaunchAgent so everything is user owned.
  final bool configNeedsPrivileges;

  /// Older or system-wide locations to seed a new config from when the
  /// real one does not exist yet.
  final List<File> legacyConfigFiles;

  /// Home of the person using this app (not root, even under sudo). Keys
  /// the app enrolls or imports live in `~/.atsign/keys` here, owned by
  /// the user, exactly where at_activate and NoPorts Desktop keep them.
  /// sshnpd.yaml then points at that file by absolute path, which the
  /// service account (root / LocalSystem) can read.
  final Directory userHomeDir;

  /// Directory holding sshnpd.yaml.
  final Directory configDir;

  /// Directory the NoPorts CLI binaries were installed to.
  final Directory binDir;

  /// Home directory of the account the daemon runs as. On Windows the MSI
  /// registers the service as LocalSystem, whose profile is not the
  /// installing user's, so `~/.atsign/keys` is not a useful default there.
  final Directory? serviceHomeDir;

  File get configFile => File(p.join(configDir.path, 'sshnpd.yaml'));

  Directory get keysDir =>
      Directory(p.join(userHomeDir.path, '.atsign', 'keys'));

  String get sshnpdBinaryName => Platform.isWindows ? 'sshnpd.exe' : 'sshnpd';

  File get sshnpdBinary => File(p.join(binDir.path, sshnpdBinaryName));

  /// Path for a key file managed by this app for [atsign].
  File keysFileFor(String atsign) {
    final a = atsign.startsWith('@') ? atsign : '@$atsign';
    return File(p.join(keysDir.path, '${a}_key.atKeys'));
  }

  static DaemonPaths? _instance;

  static DaemonPaths get instance => _instance ??= _detect();

  /// Test hook.
  static set instance(DaemonPaths paths) => _instance = paths;

  static DaemonPaths forTest({
    required Directory configDir,
    required Directory binDir,
    Directory? serviceHomeDir,
    Directory? userHomeDir,
  }) => DaemonPaths._(
    configDir: configDir,
    binDir: binDir,
    serviceHomeDir: serviceHomeDir,
    userHomeDir: userHomeDir ?? Directory(p.join(configDir.parent.path, 'home')),
  );

  /// The real user's home, seeing through sudo.
  static Directory _userHome() {
    final env = Platform.environment;
    if (Platform.isWindows) {
      return Directory(env['USERPROFILE'] ?? r'C:\Users\Default');
    }
    final sudoUser = env['SUDO_USER'];
    if (sudoUser != null && sudoUser.isNotEmpty && sudoUser != 'root') {
      try {
        if (Platform.isMacOS) {
          final r = Process.runSync('dscl', ['.', '-read', '/Users/$sudoUser', 'NFSHomeDirectory']);
          final m = RegExp(r'NFSHomeDirectory:\s*(\S+)').firstMatch(r.stdout.toString());
          if (m != null) return Directory(m.group(1)!);
        } else {
          final r = Process.runSync('getent', ['passwd', sudoUser]);
          final parts = r.stdout.toString().trim().split(':');
          if (parts.length > 5 && parts[5].isNotEmpty) return Directory(parts[5]);
        }
      } catch (_) {}
      return Directory(Platform.isMacOS ? '/Users/$sudoUser' : '/home/$sudoUser');
    }
    return Directory(env['HOME'] ?? '/');
  }

  static DaemonPaths _detect() {
    if (Platform.isWindows) {
      final programData =
          Platform.environment['ProgramData'] ?? r'C:\ProgramData';
      final systemRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
      return DaemonPaths._(
        configDir: Directory(p.join(programData, 'NoPorts')),
        binDir: _windowsBinDir(),
        serviceHomeDir: Directory(
          p.join(systemRoot, 'System32', 'config', 'systemprofile'),
        ),
        userHomeDir: _userHome(),
      );
    }
    if (Platform.isMacOS) {
      // universal.sh installs sshnpd per user: binary in ~/.local/bin and a
      // LaunchAgent in ~/Library/LaunchAgents, running as the user. So the
      // config is per user too, and no root is involved anywhere.
      final home = _userHome();
      return DaemonPaths._(
        configDir: Directory(p.join(home.path, 'Library', 'Application Support', 'NoPorts')),
        binDir: _firstWithBinary([
          p.join(home.path, '.local', 'bin'),
          '/usr/local/bin',
          '/opt/homebrew/bin',
        ]),
        serviceHomeDir: home,
        userHomeDir: home,
        legacyConfigFiles: [File('/Library/Application Support/NoPorts/sshnpd.yaml')],
      );
    }
    return DaemonPaths._(
      configDir: Directory('/etc/noports'),
      binDir: _firstWithBinary(['/usr/local/bin', '/usr/bin']),
      serviceHomeDir: Directory('/root'),
      userHomeDir: _userHome(),
      configNeedsPrivileges: true,
    );
  }

  /// The MSI installs this app in a sub-folder of the NoPorts install
  /// directory, so the CLI binaries are one level up. Fall back to the
  /// default Program Files location and finally to PATH.
  static Directory _windowsBinDir() {
    final exeDir = File(Platform.resolvedExecutable).parent;
    final candidates = <String>[
      exeDir.parent.path,
      exeDir.path,
      p.join(
        Platform.environment['ProgramFiles'] ?? r'C:\Program Files',
        'NoPorts',
      ),
    ];
    for (final c in candidates) {
      if (File(p.join(c, 'sshnpd.exe')).existsSync()) return Directory(c);
    }
    return Directory(candidates.last);
  }

  static Directory _firstWithBinary(List<String> candidates) {
    for (final c in candidates) {
      if (File(p.join(c, 'sshnpd')).existsSync()) return Directory(c);
    }
    return Directory(candidates.first);
  }
}
