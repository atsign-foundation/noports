import 'dart:io';

import 'package:noports_config/platform/service_manager.dart';

/// Runs individual commands with administrator rights while the app itself
/// stays a normal user process, so anything the app writes on its own
/// behalf (the user's keys in ~/.atsign/keys) stays owned by the user.
///
/// Windows: the app is already elevated through its manifest, so commands
/// run directly. macOS: `osascript ... with administrator privileges`,
/// which shows the system password prompt. Linux: `pkexec`.
abstract class PrivilegedRunner {
  /// Runs `sh -c script` (POSIX) or the command directly (Windows) with
  /// admin rights. Throws [ServiceException] with stderr on failure.
  Future<String> runShell(String script);

  /// Whether privileged operations can be attempted at all.
  Future<bool> isAvailable();

  /// True if this process already has the rights and no prompt is needed.
  Future<bool> alreadyPrivileged();

  static PrivilegedRunner? _instance;
  static PrivilegedRunner get instance => _instance ??= forPlatform();
  static set instance(PrivilegedRunner r) => _instance = r;

  static PrivilegedRunner forPlatform() {
    if (Platform.isWindows) return _DirectRunner();
    if (Platform.isMacOS) return _OsascriptRunner();
    return _PkexecRunner();
  }

  /// Quote for a POSIX shell.
  static String q(String s) => "'${s.replaceAll("'", "'\\''")}'";
}

class _DirectRunner extends PrivilegedRunner {
  @override
  Future<String> runShell(String script) async {
    final r = await Process.run('cmd', ['/c', script]);
    if (r.exitCode != 0) {
      throw ServiceException(
        (r.stderr.toString().trim().isNotEmpty ? r.stderr : r.stdout).toString().trim(),
      );
    }
    return r.stdout.toString();
  }

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> alreadyPrivileged() async {
    final r = await Process.run('net', ['session']);
    return r.exitCode == 0;
  }
}

Future<bool> _isRoot() async {
  final r = await Process.run('id', ['-u']);
  return r.stdout.toString().trim() == '0';
}

class _OsascriptRunner extends PrivilegedRunner {
  @override
  Future<String> runShell(String script) async {
    if (await _isRoot()) return _sh(script);
    // osascript needs the script as an AppleScript string literal.
    final escaped = script.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
    final r = await Process.run('osascript', [
      '-e',
      'do shell script "$escaped" with administrator privileges',
    ]);
    if (r.exitCode != 0) {
      final err = r.stderr.toString().trim();
      if (err.contains('-128')) {
        throw ServiceException('Cancelled at the password prompt.');
      }
      throw ServiceException(err.isEmpty ? 'exit ${r.exitCode}' : err);
    }
    return r.stdout.toString();
  }

  @override
  Future<bool> isAvailable() async =>
      (await Process.run('which', ['osascript'])).exitCode == 0;

  @override
  Future<bool> alreadyPrivileged() => _isRoot();
}

class _PkexecRunner extends PrivilegedRunner {
  @override
  Future<String> runShell(String script) async {
    if (await _isRoot()) return _sh(script);
    final r = await Process.run('pkexec', ['sh', '-c', script]);
    if (r.exitCode != 0) {
      if (r.exitCode == 126 || r.exitCode == 127) {
        throw ServiceException('Cancelled at the authentication prompt.');
      }
      final err = r.stderr.toString().trim();
      throw ServiceException(err.isEmpty ? 'exit ${r.exitCode}' : err);
    }
    return r.stdout.toString();
  }

  @override
  Future<bool> isAvailable() async =>
      (await Process.run('which', ['pkexec'])).exitCode == 0;

  @override
  Future<bool> alreadyPrivileged() => _isRoot();
}

Future<String> _sh(String script) async {
  final r = await Process.run('sh', ['-c', script]);
  if (r.exitCode != 0) {
    final err = r.stderr.toString().trim();
    throw ServiceException(err.isEmpty ? 'exit ${r.exitCode}' : err);
  }
  return r.stdout.toString();
}
