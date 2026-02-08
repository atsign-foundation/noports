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

  Future<String> getCurrentVersion();
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
    // pgrep -x matches the exact name
    final result = await Process.run('pgrep', ['-x', processName]);
    return result.exitCode == 0;
  }

  @override
  List<String> getPotentialConfigPaths() {
    return [
      '$homeDirectory/.atsign/sshnpd.yaml',
      '$homeDirectory/.sshnpd/sshnpd.yaml',
      '/usr/local/etc/sshnpd.yaml'
    ];
  }

  @override
  Future<String> getCurrentVersion() async{
    final result = await Process.run('sshnpd', ['--version']);
    // Process might crash and output to stderr, so check both or prioritize stderr where we saw it
    var output = result.stdout.toString();
    if (output.isEmpty || !output.contains('Version')) {
      output = result.stderr.toString();
    }
    final match = RegExp(r'Version\s*:\s*(\S+)', caseSensitive: false).firstMatch(output);
    return match?.group(1) ?? 'unknown';
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
    final result = await Process.run('pgrep', ['-x', processName]);
    return result.exitCode == 0;
  }

  @override
  List<String> getPotentialConfigPaths() {
    return [
      '$homeDirectory/.atsign/sshnpd.yaml',
      '$homeDirectory/.sshnpd/sshnpd.yaml',
      '/etc/sshnpd.yaml'
    ];
  }

  @override
  Future<String> getCurrentVersion() async {
    final result = await Process.run('sshnpd', ['--version']);
    var output = result.stdout.toString();
    if (output.isEmpty || !output.contains('Version')) {
      output = result.stderr.toString();
    }
    final match = RegExp(r'Version\s*:\s*(\S+)', caseSensitive: false).firstMatch(output);
    return match?.group(1) ?? 'unknown';
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
      '$homeDirectory\\.atsign\\sshnpd.yaml',
      '$homeDirectory\\.sshnpd\\sshnpd.yaml',
    ];
  }

  @override
  Future<String> getCurrentVersion() async {
    final result = await Process.run('sshnpd', ['--version']);
    var output = result.stdout.toString();
    if (output.isEmpty || !output.contains('Version')) {
      output = result.stderr.toString();
    }
    final match = RegExp(r'Version\s*:\s*(\S+)', caseSensitive: false).firstMatch(output);
    return match?.group(1) ?? 'unknown';
  }
}
