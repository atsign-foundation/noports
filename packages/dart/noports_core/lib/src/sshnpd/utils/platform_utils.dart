import 'dart:io';
import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';


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
    
    try {
      final result = await Process.run('log', [
        'show', 
        '--predicate', 'process CONTAINS "sshnpd"', 
        '--last', '10m',
        '--style', 'syslog'
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
      final advapi32 = DynamicLibrary.open('advapi32.dll');

      // Lookup OpenEventLogW
      final openEventLog = advapi32.lookupFunction<
          IntPtr Function(Pointer<Utf16>, Pointer<Utf16>),
          int Function(Pointer<Utf16>, Pointer<Utf16>)>('OpenEventLogW');

      // Lookup ReadEventLogW
      final readEventLog = advapi32.lookupFunction<
          Int32 Function(IntPtr, Uint32, Uint32, Pointer<Uint8>, Uint32,
              Pointer<Uint32>, Pointer<Uint32>),
          int Function(int, int, int, Pointer<Uint8>, int, Pointer<Uint32>,
              Pointer<Uint32>)>('ReadEventLogW');

      // Lookup CloseEventLog
      final closeEventLog = advapi32.lookupFunction<
          Int32 Function(IntPtr),
          int Function(int)>('CloseEventLog');

      // Open the Application event log on local machine
      final logName = 'Application'.toNativeUtf16();
      final hEventLog = openEventLog(nullptr, logName);
      calloc.free(logName);

      if (hEventLog == 0) {
        return 'Error: Could not open Application event log';
      }

      // Read flags: backwards + sequential (newest first)
      const int EVENTLOG_BACKWARDS_READ = 0x0008;
      const int EVENTLOG_SEQUENTIAL_READ = 0x0001;
      final readFlags = EVENTLOG_BACKWARDS_READ | EVENTLOG_SEQUENTIAL_READ;

      final bufferSize = 64 * 1024; // 64KB buffer
      final buffer = calloc<Uint8>(bufferSize);
      final bytesRead = calloc<Uint32>();
      final minBytesNeeded = calloc<Uint32>();

      final logEntries = <String>[];
      var done = false;

      try {
        while (!done && logEntries.length < lines) {
          final success = readEventLog(
            hEventLog,
            readFlags,
            0, // dwRecordOffset (ignored for sequential)
            buffer,
            bufferSize,
            bytesRead,
            minBytesNeeded,
          );

          if (success == 0) {
            // No more records or error
            break;
          }

          // Parse EVENTLOGRECORD(s) from buffer
          var offset = 0;
          while (offset < bytesRead.value && logEntries.length < lines) {
            // Read record length (first 4 bytes)
            final recordLength = buffer.cast<Uint32>().elementAt(offset ~/ 4).value;
            if (recordLength == 0) break;

            // Parse fixed header fields
            final recordPtr = buffer.elementAt(offset);
            final timeGenerated = recordPtr.cast<Uint32>().elementAt(3).value; // offset 12
            final eventId = recordPtr.cast<Uint32>().elementAt(5).value & 0xFFFF; // offset 20, lower 16 bits
            final eventType = recordPtr.cast<Uint16>().elementAt(12).value; // offset 24
            final numStrings = recordPtr.cast<Uint16>().elementAt(13).value; // offset 26
            final stringOffset = recordPtr.cast<Uint32>().elementAt(9).value; // offset 36

            // Read source name at offset 56 (null-terminated UTF-16)
            final sourcePtr = recordPtr.elementAt(56).cast<Utf16>();
            final sourceName = sourcePtr.toDartString();

            if (sourceName.toLowerCase() == serviceName.toLowerCase()) {
              // Format timestamp
              final dateTime = DateTime.fromMillisecondsSinceEpoch(
                timeGenerated * 1000,
                isUtc: true,
              ).toLocal();

              // Read message strings
              var message = '';
              if (numStrings > 0 && stringOffset < recordLength) {
                var strPtr = recordPtr.elementAt(stringOffset).cast<Utf16>();
                final parts = <String>[];
                for (var i = 0; i < numStrings; i++) {
                  final str = strPtr.toDartString();
                  parts.add(str);
                  // Move past this string (length + null terminator, in UTF-16 code units)
                  // Advance past this string + null terminator (each UTF-16 code unit = 2 bytes)
                  strPtr = Pointer<Utf16>.fromAddress(
                    strPtr.address + (str.length + 1) * 2,
                  );
                }
                message = parts.join(' | ');
              }

              final typeStr = _eventTypeToString(eventType);
              logEntries.add(
                '[$dateTime] [$typeStr] EventID:$eventId - $message',
              );
            }

            offset += recordLength;
          }
        }
      } finally {
        calloc.free(buffer);
        calloc.free(bytesRead);
        calloc.free(minBytesNeeded);
        closeEventLog(hEventLog);
      }

      if (logEntries.isEmpty) {
        return 'No event log entries found for source "$serviceName"';
      }
      return logEntries.join('\n');
    } catch (e) {
      return 'Error reading Windows Event Log: $e';
    }
  }

  /// Converts a numeric Windows event type to a human-readable string.
  static String _eventTypeToString(int eventType) {
    switch (eventType) {
      case 0x0001:
        return 'ERROR';
      case 0x0002:
        return 'WARNING';
      case 0x0004:
        return 'INFO';
      case 0x0008:
        return 'AUDIT_SUCCESS';
      case 0x0010:
        return 'AUDIT_FAILURE';
      default:
        return 'UNKNOWN($eventType)';
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
