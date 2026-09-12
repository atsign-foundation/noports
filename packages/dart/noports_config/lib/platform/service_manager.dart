import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:noports_config/platform/linux_service_manager.dart';
import 'package:noports_config/platform/macos_service_manager.dart';
import 'package:noports_config/platform/windows_service_manager.dart';

enum ServiceState { running, stopped, starting, stopping, notInstalled, unknown }

class ServiceStatus extends Equatable {
  const ServiceStatus({
    required this.state,
    this.startType,
    this.pid,
    this.exitCode,
    this.detail,
  });

  final ServiceState state;

  /// Human readable start mode, e.g. "Automatic" or "enabled".
  final String? startType;
  final int? pid;

  /// Last exit code reported by the service manager, if any.
  final int? exitCode;

  /// Raw text from the service manager for the details panel.
  final String? detail;

  bool get isRunning => state == ServiceState.running;
  bool get isInstalled => state != ServiceState.notInstalled;
  bool get isTransitioning =>
      state == ServiceState.starting || state == ServiceState.stopping;

  const ServiceStatus.notInstalled() : this(state: ServiceState.notInstalled);

  @override
  List<Object?> get props => [state, startType, pid, exitCode, detail];
}

class ServiceException implements Exception {
  ServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Controls the sshnpd system service. One implementation per platform;
/// all of them shell out to the platform's own tooling (sc.exe, launchctl,
/// systemctl) so there is nothing to compile natively.
abstract class ServiceManager {
  String get serviceName;

  /// Where the daemon's log lines come from, for display in the UI.
  String get logSourceDescription;

  Future<ServiceStatus> status();
  Future<void> start();
  Future<void> stop();

  Future<void> restart() async {
    final current = await status();
    if (current.isRunning || current.isTransitioning) {
      await stop();
    }
    await start();
  }

  /// Most recent log lines, oldest first.
  Future<String> recentLogs({int lines = 200});

  /// Whether this process has the rights needed to control the service.
  Future<bool> isElevated();

  static ServiceManager? _instance;

  static ServiceManager get instance => _instance ??= forPlatform();

  /// Test hook.
  static set instance(ServiceManager m) => _instance = m;

  static ServiceManager forPlatform() {
    if (Platform.isWindows) return WindowsServiceManager();
    if (Platform.isMacOS) return MacosServiceManager();
    return LinuxServiceManager();
  }

  /// Poll [status] until [done] returns true or [timeout] elapses.
  Future<ServiceStatus> waitFor(
    bool Function(ServiceStatus) done, {
    Duration timeout = const Duration(seconds: 30),
    Duration interval = const Duration(milliseconds: 500),
  }) async {
    final deadline = DateTime.now().add(timeout);
    var s = await status();
    while (!done(s) && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(interval);
      s = await status();
    }
    return s;
  }
}

/// Shared helper: run a process and return trimmed stdout, throwing a
/// [ServiceException] carrying stderr when it fails.
Future<String> runChecked(
  String executable,
  List<String> args, {
  bool throwOnError = true,
}) async {
  final ProcessResult result;
  try {
    result = await Process.run(executable, args, runInShell: false);
  } on ProcessException catch (e) {
    throw ServiceException('Could not run $executable: ${e.message}');
  }
  final out = result.stdout.toString();
  if (result.exitCode != 0 && throwOnError) {
    final err = result.stderr.toString().trim();
    throw ServiceException(
      err.isNotEmpty ? err : out.trim().isNotEmpty ? out.trim() : 'exit ${result.exitCode}',
    );
  }
  return out;
}
