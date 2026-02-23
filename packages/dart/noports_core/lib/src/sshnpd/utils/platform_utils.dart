import 'dart:io';


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
    // pgrep -f matches against the full command line (useful for 'dart run sshnpd')
    final result = await Process.run('pgrep', ['-f', processName]);
    return result.exitCode == 0;
  }

  @override
  List<String> getPotentialConfigPaths() {
    return [
        '$homeDirectory/Library/LaunchAgents/com.atsign.sshnpd.plist'
    ];
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
    // log show --predicate 'process == "sshnpd"' --info --last 50
    // Note: 'log' command might require permissions or might be noisy.
    // Alternative: check standard log files if we knew where they were.
    // Let's try 'log show' which is standard on modern macOS.
    try {
      final result = await Process.run('log', [
        'show',
        '--predicate',
        'process == "$serviceName"',
        '--info',
        '--last',
        '$lines',
        '--style',
        'compact'
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
    return [
      '/etc/systemd/system/sshnpd.service.d/override.conf'
    ];
  }

  @override
  Future<bool> isServiceInstalled(String serviceName) async {
    // systemctl list-unit-files | grep serviceName
    final result = await Process.run('systemctl', ['list-unit-files', '$serviceName.service']);
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
        '--no-pager'
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
    String actualName = processName.endsWith('.exe') ? processName : '$processName.exe';
    
    final result = await Process.run('tasklist', ['/FI', 'IMAGENAME eq $actualName']);
    // tasklist always returns 0 even if not found, so we check stdout
    return result.stdout.toString().contains(actualName);
  }

  @override
  List<String> getPotentialConfigPaths() {
    return [
      'C:\ProgramData\NoPorts\sshnpd.yaml',
    ];
  }

  @override
  Future<bool> isServiceInstalled(String serviceName) async {
    // PowerShell Get-Service -Name serviceName
    final result = await Process.run('powershell', ['-Command', 'Get-Service -Name $serviceName']);
    return result.exitCode == 0; // successfully found
  }

  @override
  Future<bool> isServiceRunning(String serviceName) async {
    final result = await Process.run('powershell', [
      '-Command', 'sc query "sshnpd"']);
    // If output is not empty, it's running
    return result.stdout.toString().trim().isNotEmpty;
  }

  @override
  Future<String> getServiceLogs(String serviceName, {int lines = 50}) async {
    // Get-EventLog -LogName Application -Source serviceName -Newest lines
    try {
      final result = await Process.run('powershell', [
        '-Command',
        'Get-EventLog -LogName Application -Source $serviceName -Newest $lines | Format-Table -AutoSize'
      ]);
      if (result.exitCode != 0) {
        return 'Error fetching logs (EventLog): ${result.stderr}';
      }
      return result.stdout.toString();
    } catch (e) {
      return 'Error running PowerShell: $e';
    }
  }

  @override
  Future<String> getArchitecture() async {
    String arch = Platform.environment['PROCESSOR_ARCHITECTURE'] ?? 'unknown';
    if (arch == 'AMD64') return 'x64';
    if (arch == 'ARM64') return 'arm64';
    return arch;
  }
}
