import 'dart:io';

class ServiceExitInfo {
  final int exitCode;
  final String result;
  final String activeState;
  final String subState;

  ServiceExitInfo({
    this.exitCode = -1,
    this.result = 'unknown',
    this.activeState = 'unknown',
    this.subState = 'unknown',
  });

  bool get hasFailed => exitCode > 0 || activeState == 'failed';
}

/// Abstract class defining platform-specific operations
abstract class PlatformUtils {
  /// current instance
  static PlatformUtils? _instance;

  /// Factory to get the correct instance based on the current OS
  static PlatformUtils get instance {
    if (_instance == null) {
      if (Platform.isWindows) {
        _instance = WindowsUtils();
      } else if (Platform.isLinux) {
        _instance = LinuxUtils();
      } else if (Platform.isMacOS) {
        _instance = MacOSUtils();
      } else {
        // Default fallback (Unix-like)
        _instance = LinuxUtils();
      }
    }
    return _instance!;
  }

  /// Platform name for display
  String get name;

  /// User Home Directory
  String get homeDirectory;

  /// Check if a command is available (e.g. 'curl', 'ssh')
  Future<bool> isCommandAvailable(String command);

  /// Check if a process is currently running
  Future<bool> isProcessRunning(String processName);

  /// Get list of potential config file paths
  List<String> getPotentialConfigPaths();

  /// Check if the service is installed/registered
  Future<bool> isServiceInstalled(String serviceName);

  /// Check if the service is active/running (different from process check)
  Future<bool> isServiceRunning(String serviceName);

  /// Get recent logs for the service
  Future<String> getServiceLogs(String serviceName, {int lines = 50});

  /// Get the system architecture (e.g. x64, arm64)
  Future<String> getArchitecture();

  Future<String> getAtKeys(String content);

  /// Get structured exit info for the service (exit code, result, states).
  /// Returns defaults if not applicable on this platform.
  Future<ServiceExitInfo> getServiceExitInfo(String serviceName);

  /// Detects if a package was installed via a system package manager.
  /// Returns the recommended update command, or null if not package-managed.
  Future<String?> detectPackageManagerInstall(String packageName);

  /// Returns platform-specific advice for installing/updating the package
  /// when it was NOT installed via a detected package manager.
  Future<String> getRecommendedInstallAdvice(String packageName);
}

/// MacOS Implementation
class MacOSUtils implements PlatformUtils {
  @override
  String get name => 'MacOS';

  @override
  String get homeDirectory => Platform.environment['HOME'] ?? '/';

  @override
  Future<bool> isCommandAvailable(String command) async {
    final result = await Process.run('which', [command]);
    return result.exitCode == 0;
  }

  @override
  Future<bool> isProcessRunning(String processName) async {
    final result = await Process.run('pgrep', ['-f', processName]);
    return result.exitCode == 0;
  }

  @override
  List<String> getPotentialConfigPaths() {
    return ['$homeDirectory/Library/LaunchAgents/com.atsign.sshnpd.plist'];
  }

  @override
  Future<bool> isServiceInstalled(String serviceName) async {
    // launchctl list | grep serviceName
    final result = await Process.run('launchctl', ['list']);
    return result.stdout.toString().contains(serviceName);
  }

  @override
  Future<bool> isServiceRunning(String serviceName) async {
    // On macOS, launchctl list shows status. If it appears in list, it is loaded.
    // We can check if it has a PID.
    final result = await Process.run('launchctl', ['list']);
    final lines = result.stdout.toString().split('\n');
    for (var line in lines) {
      if (line.contains(serviceName)) {
        // Format: PID Status Label
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.isNotEmpty && parts[0] != '-') {
          // PID is present
          return true;
        }
      }
    }
    return false;
  }

  @override
  Future<String> getServiceLogs(String serviceName, {int lines = 50}) async {
    try {
      final result = await Process.run('log', [
        'show',
        '--predicate',
        'process CONTAINS "$serviceName"',
        '--last',
        '10m',
        '--style',
        'syslog',
      ]);
      if (result.exitCode != 0) {
        return 'Error fetching logs: ${result.stderr}';
      }
      return result.stdout.toString();
    } catch (e) {
      return 'Error running log command: $e';
    }
  }

  @override
  Future<String> getArchitecture() async {
    final result = await Process.run('uname', ['-m']);
    String arch = result.stdout.toString().trim();
    if (arch == 'x86_64') return 'x64';
    if (arch == 'arm64') return 'arm64';
    return arch;
  }

  @override
  Future<String> getAtKeys(String content) async {
    var atkeys = content
        .split('\n')
        .where((line) => line.contains('@'))
        .map((l) => l.trim())
        .join(', ');
    atkeys = atkeys.replaceAll('<string>', '').replaceAll('</string>', '');
    return atkeys;
  }

  @override
  Future<ServiceExitInfo> getServiceExitInfo(String serviceName) async {
    try {
      final listResult = await Process.run('launchctl', ['list']);
      final lines = listResult.stdout.toString().split('\n');
      String? actualLabel;

      for (var line in lines) {
        if (line.contains(serviceName)) {
          final parts = line.trim().split(RegExp(r'\s+'));
          if (parts.length >= 3) {
            actualLabel = parts[2];
            break;
          }
        }
      }

      if (actualLabel == null) return ServiceExitInfo();

      final result = await Process.run('launchctl', ['list', actualLabel]);
      final output = result.stdout.toString();

      final exitMatch = RegExp(
        r'"LastExitStatus"\s*=\s*(\d+);',
      ).firstMatch(output);
      int exitCode = -1;
      if (exitMatch != null) {
        exitCode = int.tryParse(exitMatch.group(1)!) ?? -1;
        if (exitCode > 255) {
          exitCode = exitCode >> 8;
        }
      }

      final pidMatch = RegExp(r'"PID"\s*=\s*(\d+);').firstMatch(output);
      String activeState = 'unknown';
      if (pidMatch != null) {
        activeState = 'active';
      } else if (exitCode > 0) {
        activeState = 'failed';
      } else {
        activeState = 'inactive';
      }

      return ServiceExitInfo(
        exitCode: exitCode,
        result: exitCode == 0 ? 'success' : 'failed',
        activeState: activeState,
        subState: 'unknown',
      );
    } catch (_) {
      return ServiceExitInfo();
    }
  }

  @override
  Future<String?> detectPackageManagerInstall(String packageName) async {
    // Check Homebrew
    try {
      final brew = await Process.run('brew', ['list', packageName]);
      if (brew.exitCode == 0) {
        return 'brew upgrade $packageName';
      }
    } catch (_) {
      // brew not available
    }

    return null;
  }

  @override
  Future<String> getRecommendedInstallAdvice(String packageName) async {
    return 'Install or update via Homebrew:\n'
        'brew tap atsign-foundation/homebrew-tap\n'
        'brew install $packageName\n'
        '\n'
        ' If already tapped: brew upgrade $packageName';
  }
}

/// Linux Implementation (Very similar to MacOS)
class LinuxUtils implements PlatformUtils {
  @override
  String get name => 'Linux';

  @override
  String get homeDirectory => Platform.environment['HOME'] ?? '/';

  @override
  Future<bool> isCommandAvailable(String command) async {
    final result = await Process.run('which', [command]);
    return result.exitCode == 0;
  }

  @override
  Future<bool> isProcessRunning(String processName) async {
    // pgrep -f matches full command line
    final result = await Process.run('pgrep', ['-f', processName]);
    return result.exitCode == 0;
  }

  @override
  List<String> getPotentialConfigPaths() {
    return ['/etc/systemd/system/sshnpd.service.d/override.conf'];
  }

  @override
  Future<bool> isServiceInstalled(String serviceName) async {
    // systemctl list-unit-files | grep serviceName
    final result = await Process.run('systemctl', [
      'list-unit-files',
      '$serviceName.service',
    ]);
    return result.stdout.toString().contains('$serviceName.service');
  }

  @override
  Future<bool> isServiceRunning(String serviceName) async {
    // systemctl is-active serviceName
    final result = await Process.run('systemctl', ['is-active', serviceName]);
    return result.stdout.toString().trim() == 'active';
  }

  @override
  Future<String> getServiceLogs(String serviceName, {int lines = 50}) async {
    // journalctl -u serviceName -n lines --no-pager
    try {
      final result = await Process.run('journalctl', [
        '-u',
        '$serviceName.service',
        '-n',
        '$lines',
        '--no-pager',
      ]);
      if (result.exitCode != 0) {
        return 'Error fetching logs: ${result.stderr}';
      }
      return result.stdout.toString();
    } catch (e) {
      return 'Error running journalctl: $e';
    }
  }

  @override
  Future<String> getArchitecture() async {
    final result = await Process.run('uname', ['-m']);
    String arch = result.stdout.toString().trim();
    if (arch == 'x86_64') return 'x64';
    if (arch == 'aarch64' || arch == 'arm64') return 'arm64';
    if (arch.startsWith('arm')) return 'arm';
    return arch;
  }

  @override
  Future<String> getAtKeys(String content) async {
    final quoteRegex = RegExp(r'"([^"]*)"');
    var atkeys = content
        .split('\n')
        .where((line) => line.contains('@'))
        .map((line) {
          final match = quoteRegex.firstMatch(line);
          return match != null ? match.group(1)!.trim() : line.trim();
        })
        .join(', ');
    return atkeys;
  }

  @override
  Future<ServiceExitInfo> getServiceExitInfo(String serviceName) async {
    try {
      final result = await Process.run('systemctl', [
        'show',
        '$serviceName.service',
        '--property=ExecMainStatus,Result,ActiveState,SubState',
      ]);
      final props = <String, String>{};
      for (final line in result.stdout.toString().trim().split('\n')) {
        final idx = line.indexOf('=');
        if (idx > 0) {
          props[line.substring(0, idx)] = line.substring(idx + 1);
        }
      }
      return ServiceExitInfo(
        exitCode: int.tryParse(props['ExecMainStatus'] ?? '') ?? -1,
        result: props['Result'] ?? 'unknown',
        activeState: props['ActiveState'] ?? 'unknown',
        subState: props['SubState'] ?? 'unknown',
      );
    } catch (_) {
      return ServiceExitInfo();
    }
  }

  @override
  Future<String?> detectPackageManagerInstall(String packageName) async {
    // Check dpkg (Debian/Ubuntu)
    try {
      final dpkg = await Process.run('dpkg', ['-s', packageName]);
      if (dpkg.exitCode == 0 &&
          dpkg.stdout.toString().contains('Status: install ok installed')) {
        return 'sudo apt update && sudo apt upgrade $packageName';
      }
    } catch (_) {
      // dpkg not available — not a Debian-based system
    }

    // Check rpm (RHEL/Fedora/SUSE)
    try {
      final rpm = await Process.run('rpm', ['-q', packageName]);
      if (rpm.exitCode == 0) {
        // Determine whether to use dnf or yum
        final dnfCheck = await Process.run('which', ['dnf']);
        if (dnfCheck.exitCode == 0) {
          return 'sudo dnf upgrade $packageName';
        }
        return 'sudo yum update $packageName';
      }
    } catch (_) {
      // rpm not available — not an RPM-based system
    }

    // Check apk (OpenWrt 25.12+ / Alpine)
    // On OpenWrt the C implementation is packaged as 'csshnpd'
    final apkNames = [packageName, 'csshnpd'];
    try {
      for (final name in apkNames) {
        final apk = await Process.run('apk', ['info', '-e', name]);
        if (apk.exitCode == 0 && apk.stdout.toString().trim().isNotEmpty) {
          return 'apk update && apk upgrade $name';
        }
      }
    } catch (_) {
      // apk not available
    }

    // Check opkg (OpenWrt 24.10 and older) — same candidate names as apk
    try {
      for (final name in apkNames) {
        final opkg = await Process.run('opkg', ['status', name]);
        if (opkg.exitCode == 0 &&
            opkg.stdout.toString().contains('Status: install')) {
          return 'opkg update && opkg upgrade $name';
        }
      }
    } catch (_) {
      // opkg not available
    }

    return null;
  }

  @override
  Future<String> getRecommendedInstallAdvice(String packageName) async {
    // Detect which package manager is available on the system
    try {
      final aptCheck = await Process.run('which', ['apt']);
      if (aptCheck.exitCode == 0) {
        return 'Install via apt (requires repo setup):\n'
            'sudo apt update && sudo apt install -y $packageName\n'
            '\n'
            ' If the noports repo is not yet configured, see:\n'
            ' https://docs.noports.com/installation/advanced-installation-guides#apt-package';
      }
    } catch (_) {}

    try {
      final dnfCheck = await Process.run('which', ['dnf']);
      if (dnfCheck.exitCode == 0) {
        return 'Install via dnf (requires repo setup):\n'
            'sudo dnf install $packageName\n'
            '\n'
            ' If the noports repo is not yet configured, see:\n'
            ' https://docs.noports.com/installation/advanced-installation-guides#rpm-package';
      }
    } catch (_) {}

    try {
      final yumCheck = await Process.run('which', ['yum']);
      if (yumCheck.exitCode == 0) {
        return 'Install via yum (requires repo setup):\n'
            'sudo yum install $packageName\n'
            '\n'
            ' If the noports repo is not yet configured, see:\n'
            ' https://docs.noports.com/installation/advanced-installation-guides#rpm-package';
      }
    } catch (_) {}

    return 'Please visit https://docs.noports.com/installation/advanced-installation-guides for installation instructions.';
  }
}

/// Windows Implementation
class WindowsUtils implements PlatformUtils {
  @override
  String get name => 'Windows';

  @override
  String get homeDirectory => Platform.environment['USERPROFILE'] ?? 'C:\\';

  @override
  Future<bool> isCommandAvailable(String command) async {
    // 'where' is the windows equivalent of 'which'
    final result = await Process.run('where', [command]);
    return result.exitCode == 0;
  }

  @override
  Future<bool> isProcessRunning(String processName) async {
    // tasklist /FI "IMAGENAME eq sshnpd.exe"
    // Note: Windows processes usually have .exe extension
    String actualName = processName.endsWith('.exe')
        ? processName
        : '$processName.exe';

    final result = await Process.run('tasklist', [
      '/FI',
      'IMAGENAME eq $actualName',
    ]);
    // tasklist always returns 0 even if not found, so we check stdout
    return result.stdout.toString().contains(actualName);
  }

  @override
  List<String> getPotentialConfigPaths() {
    return [r'C:\ProgramData\NoPorts\sshnpd.yaml'];
  }

  @override
  Future<bool> isServiceInstalled(String serviceName) async {
    final result = await Process.run('sc', ['query', serviceName]);
    return result.exitCode == 0;
  }

  @override
  Future<bool> isServiceRunning(String serviceName) async {
    final result = await Process.run('sc', ['query', serviceName]);
    return result.stdout.toString().contains('RUNNING');
  }

  @override
  Future<String> getServiceLogs(String serviceName, {int lines = 50}) async {
    try {
      // Use PowerShell Get-WinEvent to query the Application event log
      // filtered by ProviderName (source) matching sshnpd
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        'Get-WinEvent -FilterHashtable @{LogName=\'Application\'; ProviderName=\'$serviceName\'} -MaxEvents $lines | Format-List TimeCreated, Id, LevelDisplayName, Message',
      ]);

      if (result.exitCode != 0) {
        final stderr = result.stderr.toString();
        if (stderr.contains('No events were found')) {
          return 'No event log entries found for source "$serviceName"';
        }
        return 'Error fetching logs: $stderr';
      }

      final output = result.stdout.toString().trim();
      if (output.isEmpty) {
        return 'No event log entries found for source "$serviceName"';
      }
      return output;
    } catch (e) {
      return 'Error reading Windows Event Log: $e';
    }
  }

  @override
  Future<String> getArchitecture() async {
    String arch = Platform.environment['PROCESSOR_ARCHITECTURE'] ?? 'unknown';
    if (arch == 'AMD64') return 'x64';
    if (arch == 'ARM64') return 'arm64';
    return arch;
  }

  @override
  Future<String> getAtKeys(String content) async {
    final quoteRegex = RegExp(r"'([^']*)'");
    var atkeys = content
        .split('\n')
        .where((line) => line.contains('@'))
        .map((line) {
          final match = quoteRegex.firstMatch(line);
          return match != null ? match.group(1)!.trim() : line.trim();
        })
        .join(', ');
    return atkeys;
  }

  @override
  Future<ServiceExitInfo> getServiceExitInfo(String serviceName) async {
    try {
      final result = await Process.run('sc', ['query', serviceName]);
      final output = result.stdout.toString();

      int exitCode = -1;

      final win32Match = RegExp(
        r'WIN32_EXIT_CODE\s*:\s*(\d+)',
      ).firstMatch(output);
      final serviceMatch = RegExp(
        r'SERVICE_EXIT_CODE\s*:\s*(\d+)',
      ).firstMatch(output);

      if (win32Match != null) {
        exitCode = int.tryParse(win32Match.group(1)!) ?? -1;
      }
      if (exitCode == 1066 && serviceMatch != null) {
        exitCode = int.tryParse(serviceMatch.group(1)!) ?? exitCode;
      }

      final stateMatch = RegExp(r'STATE\s*:\s*\d+\s+(\w+)').firstMatch(output);
      String activeState = 'unknown';
      if (stateMatch != null) {
        activeState = stateMatch.group(1)!.toLowerCase();
      }

      bool hasFailed = exitCode > 0;
      return ServiceExitInfo(
        exitCode: exitCode,
        result: hasFailed ? 'failed' : 'success',
        activeState: activeState,
        subState: 'unknown',
      );
    } catch (_) {
      return ServiceExitInfo();
    }
  }

  @override
  Future<String?> detectPackageManagerInstall(String packageName) async {
    return null;
  }

  @override
  Future<String> getRecommendedInstallAdvice(String packageName) async {
    return 'Please download and run the MSI installer from:\n'
        '   https://github.com/atsign-foundation/noports/releases/latest\n';
  }
}
