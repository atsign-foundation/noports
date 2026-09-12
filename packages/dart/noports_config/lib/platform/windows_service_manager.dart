import 'dart:io';

import 'package:noports_config/platform/service_manager.dart';

/// Drives the `sshnpd` Windows service installed by the MSI through sc.exe
/// and reads its Event Log entries through PowerShell.
class WindowsServiceManager extends ServiceManager {
  WindowsServiceManager({this.serviceName = 'sshnpd'});

  @override
  final String serviceName;

  /// The .NET service wrapper logs under its application name (the service
  /// name). The MSI also registers a "NoPorts Daemon" event source, so read
  /// both.
  static const eventProviders = ['sshnpd', 'NoPorts Daemon'];

  @override
  String get logSourceDescription =>
      'Windows Event Log (Application, providers ${eventProviders.join(', ')})';

  static const _stateNames = {
    1: ServiceState.stopped,
    2: ServiceState.starting,
    3: ServiceState.stopping,
    4: ServiceState.running,
    5: ServiceState.starting, // CONTINUE_PENDING
    6: ServiceState.stopping, // PAUSE_PENDING
    7: ServiceState.stopped, // PAUSED
  };

  @override
  Future<ServiceStatus> status() async {
    final result = await Process.run('sc', ['query', serviceName]);
    final out = result.stdout.toString();
    if (result.exitCode == 1060 || out.contains('1060')) {
      return const ServiceStatus.notInstalled();
    }
    if (result.exitCode != 0) {
      return ServiceStatus(
        state: ServiceState.unknown,
        detail: (out + result.stderr.toString()).trim(),
      );
    }
    final stateMatch = RegExp(r'STATE\s*:\s*(\d+)').firstMatch(out);
    final state = _stateNames[int.tryParse(stateMatch?.group(1) ?? '')] ??
        ServiceState.unknown;
    final pid = int.tryParse(
      RegExp(r'PID\s*:\s*(\d+)').firstMatch(out)?.group(1) ?? '',
    );
    var exitCode = int.tryParse(
      RegExp(r'WIN32_EXIT_CODE\s*:\s*(\d+)').firstMatch(out)?.group(1) ?? '',
    );
    // 1066 means "service specific error"; the real code is the next field.
    if (exitCode == 1066) {
      exitCode = int.tryParse(
        RegExp(r'SERVICE_EXIT_CODE\s*:\s*(\d+)').firstMatch(out)?.group(1) ??
            '',
      );
    }
    String? startType;
    final qc = await Process.run('sc', ['qc', serviceName]);
    final st = RegExp(r'START_TYPE\s*:\s*\d+\s+(\w+)')
        .firstMatch(qc.stdout.toString())
        ?.group(1);
    if (st != null) {
      startType = switch (st) {
        'AUTO_START' => 'Automatic',
        'DEMAND_START' => 'Manual',
        'DISABLED' => 'Disabled',
        _ => st,
      };
    }
    return ServiceStatus(
      state: state,
      startType: startType,
      pid: pid == 0 ? null : pid,
      exitCode: exitCode == 0 ? null : exitCode,
      detail: out.trim(),
    );
  }

  @override
  Future<void> start() async {
    await runChecked('sc', ['start', serviceName]);
    final s = await waitFor((s) => !s.isTransitioning);
    if (!s.isRunning) {
      throw ServiceException(
        'Service did not reach the running state'
        '${s.exitCode != null ? ' (exit code ${s.exitCode})' : ''}. '
        'Check the log below.',
      );
    }
  }

  @override
  Future<void> stop() async {
    final result = await Process.run('sc', ['stop', serviceName]);
    // 1062: service not started. Not an error for our purposes.
    if (result.exitCode != 0 && !result.stdout.toString().contains('1062')) {
      throw ServiceException(result.stdout.toString().trim());
    }
    await waitFor((s) => s.state == ServiceState.stopped);
  }

  @override
  Future<String> recentLogs({int lines = 200}) async {
    final providers = eventProviders.map((p) => "'$p'").join(',');
    final script =
        "\$ErrorActionPreference='SilentlyContinue'; "
        "Get-WinEvent -FilterHashtable @{LogName='Application'; ProviderName=@($providers)} "
        "-MaxEvents $lines | Sort-Object TimeCreated | ForEach-Object { "
        "'{0:yyyy-MM-dd HH:mm:ss} [{1}] {2}' -f \$_.TimeCreated, \$_.LevelDisplayName, \$_.Message }";
    final result = await Process.run('powershell', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      script,
    ]);
    final out = result.stdout.toString().trim();
    if (out.isEmpty) {
      return 'No Event Log entries found for ${eventProviders.join(' / ')}.';
    }
    return out;
  }

  @override
  Future<bool> isElevated() async {
    final result = await Process.run('net', ['session']);
    return result.exitCode == 0;
  }
}
