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
  });

  /// Directory holding sshnpd.yaml. Keys imported by this app go in a
  /// `keys` sub-directory so the service account can always read them.
  final Directory configDir;

  /// Directory the NoPorts CLI binaries were installed to.
  final Directory binDir;

  /// Home directory of the account the daemon runs as. On Windows the MSI
  /// registers the service as LocalSystem, whose profile is not the
  /// installing user's, so `~/.atsign/keys` is not a useful default there.
  final Directory? serviceHomeDir;

  File get configFile => File(p.join(configDir.path, 'sshnpd.yaml'));

  Directory get keysDir => Directory(p.join(configDir.path, 'keys'));

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
  }) => DaemonPaths._(
    configDir: configDir,
    binDir: binDir,
    serviceHomeDir: serviceHomeDir,
  );

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
      );
    }
    if (Platform.isMacOS) {
      return DaemonPaths._(
        configDir: Directory('/Library/Application Support/NoPorts'),
        binDir: _firstWithBinary(['/usr/local/bin', '/opt/homebrew/bin']),
        serviceHomeDir: Directory('/var/root'),
      );
    }
    return DaemonPaths._(
      configDir: Directory('/etc/noports'),
      binDir: _firstWithBinary(['/usr/local/bin', '/usr/bin']),
      serviceHomeDir: Directory('/root'),
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
