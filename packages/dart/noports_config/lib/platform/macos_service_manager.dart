import 'dart:io';

import 'package:noports_config/platform/service_manager.dart';

/// launchd control for the sshnpd LaunchDaemon. Requires root; the UI
/// explains this when [isElevated] is false.
class MacosServiceManager extends ServiceManager {
  MacosServiceManager({this.label = 'com.atsign.sshnpd'});

  final String label;

  @override
  String get serviceName => label;

  String get plistPath => '/Library/LaunchDaemons/$label.plist';

  @override
  String get logSourceDescription => 'Unified log (process sshnpd)';

  @override
  Future<ServiceStatus> status() async {
    final result = await Process.run('launchctl', ['print', 'system/$label']);
    final out = result.stdout.toString() + result.stderr.toString();
    if (result.exitCode != 0) {
      if (File(plistPath).existsSync()) {
        return ServiceStatus(
          state: ServiceState.stopped,
          startType: 'Not loaded',
          detail: out.trim(),
        );
      }
      return const ServiceStatus.notInstalled();
    }
    final stateStr =
        RegExp(r'state = (\w+)').firstMatch(out)?.group(1) ?? 'unknown';
    final pid = int.tryParse(
      RegExp(r'pid = (\d+)').firstMatch(out)?.group(1) ?? '',
    );
    final exit = int.tryParse(
      RegExp(r'last exit code = (\d+)').firstMatch(out)?.group(1) ?? '',
    );
    return ServiceStatus(
      state: switch (stateStr) {
        'running' => ServiceState.running,
        'spawn scheduled' || 'spawning' => ServiceState.starting,
        'exited' || 'not running' || 'waiting' => ServiceState.stopped,
        _ => ServiceState.unknown,
      },
      startType: out.contains('runatload = 1') ? 'Run at load' : 'On demand',
      pid: pid,
      exitCode: exit == 0 ? null : exit,
      detail: out.trim(),
    );
  }

  @override
  Future<void> start() async {
    final loaded =
        (await Process.run('launchctl', ['print', 'system/$label'])).exitCode ==
        0;
    if (!loaded) {
      await runChecked('launchctl', ['bootstrap', 'system', plistPath]);
    }
    await runChecked('launchctl', ['kickstart', 'system/$label']);
    await waitFor((s) => s.isRunning);
  }

  @override
  Future<void> stop() async {
    // bootout unloads the job, which is the only way to stop a KeepAlive
    // daemon without launchd immediately respawning it.
    await runChecked('launchctl', ['bootout', 'system/$label']);
    await waitFor((s) => !s.isRunning);
  }

  @override
  Future<String> recentLogs({int lines = 200}) async {
    final result = await Process.run('log', [
      'show',
      '--style',
      'compact',
      '--last',
      '2h',
      '--predicate',
      'process == "sshnpd"',
    ]);
    final all = result.stdout.toString().trim().split('\n');
    final tail = all.length > lines ? all.sublist(all.length - lines) : all;
    final text = tail.join('\n').trim();
    return text.isEmpty ? 'No log entries for sshnpd in the last 2 hours.' : text;
  }

  @override
  Future<bool> isElevated() async {
    final result = await Process.run('id', ['-u']);
    return result.stdout.toString().trim() == '0';
  }
}
