import 'dart:io';

import 'package:noports_config/platform/privileged_runner.dart';
import 'package:noports_config/platform/service_manager.dart';

/// launchd control for the sshnpd LaunchDaemon. Status is read as the
/// current user; start and stop go through the admin password prompt.
class MacosServiceManager extends ServiceManager {
  MacosServiceManager({this.label = 'com.atsign.sshnpd', PrivilegedRunner? runner})
    : _runner = runner;

  final String label;
  final PrivilegedRunner? _runner;
  PrivilegedRunner get runner => _runner ?? PrivilegedRunner.instance;

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
      if (!File(plistPath).existsSync()) return const ServiceStatus.notInstalled();
      // Reading the system domain can be refused for non-root users; fall
      // back to looking for the process.
      final pg = await Process.run('pgrep', ['-x', 'sshnpd']);
      final pid = int.tryParse(pg.stdout.toString().trim().split('\n').first);
      return ServiceStatus(
        state: pid != null ? ServiceState.running : ServiceState.stopped,
        startType: 'Run at load',
        pid: pid,
        detail: out.trim(),
      );
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
    final q = PrivilegedRunner.q;
    await runner.runShell(
      '( launchctl print system/$label >/dev/null 2>&1 || '
      'launchctl bootstrap system ${q(plistPath)} ) && '
      'launchctl kickstart system/$label',
    );
    await waitFor((s) => s.isRunning);
  }

  @override
  Future<void> stop() async {
    // bootout unloads the job, which is the only way to stop a KeepAlive
    // daemon without launchd immediately respawning it.
    await runner.runShell('launchctl bootout system/$label');
    await waitFor((s) => !s.isRunning);
  }

  @override
  Future<void> restart() async {
    // One prompt instead of two.
    final q = PrivilegedRunner.q;
    await runner.runShell(
      '( launchctl bootout system/$label 2>/dev/null || true ) && '
      'launchctl bootstrap system ${q(plistPath)} && '
      'launchctl kickstart system/$label',
    );
    await waitFor((s) => s.isRunning);
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
  Future<bool> isElevated() => runner.isAvailable();
}
