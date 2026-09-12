import 'dart:io';

import 'package:noports_config/platform/service_manager.dart';

/// systemd control for the sshnpd unit installed by universal.sh or the
/// deb/rpm packages.
class LinuxServiceManager extends ServiceManager {
  LinuxServiceManager({this.serviceName = 'sshnpd'});

  @override
  final String serviceName;

  @override
  String get logSourceDescription => 'journalctl -u $serviceName';

  @override
  Future<ServiceStatus> status() async {
    final result = await Process.run('systemctl', [
      'show',
      serviceName,
      '-p',
      'LoadState,ActiveState,SubState,MainPID,ExecMainStatus,UnitFileState',
    ]);
    final props = <String, String>{};
    for (final line in result.stdout.toString().split('\n')) {
      final i = line.indexOf('=');
      if (i > 0) props[line.substring(0, i)] = line.substring(i + 1).trim();
    }
    if (result.exitCode != 0 || props['LoadState'] == 'not-found') {
      return const ServiceStatus.notInstalled();
    }
    final active = props['ActiveState'];
    final state = switch (active) {
      'active' => ServiceState.running,
      'activating' || 'reloading' => ServiceState.starting,
      'deactivating' => ServiceState.stopping,
      'inactive' || 'failed' => ServiceState.stopped,
      _ => ServiceState.unknown,
    };
    final pid = int.tryParse(props['MainPID'] ?? '');
    final exit = int.tryParse(props['ExecMainStatus'] ?? '');
    return ServiceStatus(
      state: state,
      startType: props['UnitFileState'],
      pid: pid == 0 ? null : pid,
      exitCode: exit == 0 ? null : exit,
      detail: '$active (${props['SubState']})',
    );
  }

  @override
  Future<void> start() async {
    await runChecked('systemctl', ['start', serviceName]);
    final s = await waitFor((s) => !s.isTransitioning);
    if (!s.isRunning) {
      throw ServiceException(
        'Unit did not become active (${s.detail}). Check the log below.',
      );
    }
  }

  @override
  Future<void> stop() async {
    await runChecked('systemctl', ['stop', serviceName]);
    await waitFor((s) => s.state == ServiceState.stopped);
  }

  @override
  Future<void> restart() async {
    await runChecked('systemctl', ['restart', serviceName]);
    await waitFor((s) => !s.isTransitioning);
  }

  @override
  Future<String> recentLogs({int lines = 200}) async {
    final result = await Process.run('journalctl', [
      '-u',
      serviceName,
      '-n',
      '$lines',
      '--no-pager',
      '-o',
      'short-iso',
    ]);
    final out = result.stdout.toString().trim();
    return out.isEmpty ? 'No journal entries for $serviceName.' : out;
  }

  @override
  Future<bool> isElevated() async {
    final result = await Process.run('id', ['-u']);
    return result.stdout.toString().trim() == '0';
  }
}
