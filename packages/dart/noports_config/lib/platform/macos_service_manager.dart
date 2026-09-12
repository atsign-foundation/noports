import 'dart:io';

import 'package:noports_config/platform/daemon_paths.dart';
import 'package:noports_config/platform/service_manager.dart';
import 'package:path/path.dart' as p;

/// launchd control for the per-user sshnpd LaunchAgent that universal.sh
/// installs (`~/Library/LaunchAgents/com.atsign.sshnpd.plist`, loaded in
/// the user's `gui/<uid>` domain). Everything runs as the user; no admin
/// prompt is involved.
class MacosServiceManager extends ServiceManager {
  MacosServiceManager({this.label = 'com.atsign.sshnpd', DaemonPaths? paths})
    : _paths = paths;

  final String label;
  final DaemonPaths? _paths;
  String? _uid;

  DaemonPaths get paths => _paths ?? DaemonPaths.instance;

  @override
  String get serviceName => label;

  File get plistFile => File(
    p.join(paths.userHomeDir.path, 'Library', 'LaunchAgents', '$label.plist'),
  );

  File get logFile =>
      File(p.join(paths.userHomeDir.path, '.sshnpd', 'logs', 'sshnpd.log'));

  @override
  String get logSourceDescription => plistFile.existsSync() &&
          parseProgramArguments(plistFile.readAsStringSync()).isNotEmpty &&
          _standardOutPath(plistFile.readAsStringSync()) != null
      ? _standardOutPath(plistFile.readAsStringSync())!
      : 'Unified log (process sshnpd)';

  Future<String> _domain() async {
    _uid ??= (await Process.run('id', ['-u'])).stdout.toString().trim();
    return 'gui/$_uid';
  }

  @override
  bool get canInstall => true;

  @override
  Future<ServiceStatus> status() async {
    final plistExists = plistFile.existsSync();
    String? warning;
    if (plistExists) {
      final args = parseProgramArguments(plistFile.readAsStringSync());
      if (!isManagedDefinition(args, paths.configFile.path)) {
        warning = 'The service definition passes settings on the command line '
            '(${args.skip(1).join(' ')}). Those override sshnpd.yaml. Update the '
            'service definition to run from the configuration file.';
      } else if (args.isNotEmpty && !File(args.first).existsSync()) {
        warning = 'The service points at ${args.first}, which does not exist.';
      }
    }
    final result = await Process.run('launchctl', ['print', '${await _domain()}/$label']);
    final out = result.stdout.toString() + result.stderr.toString();
    if (result.exitCode != 0) {
      if (!plistExists) return const ServiceStatus.notInstalled();
      return ServiceStatus(
        state: ServiceState.stopped,
        startType: 'Not loaded',
        detail: out.trim(),
        warning: warning,
      );
    }
    final stateStr = RegExp(r'state = ([\w ]+)').firstMatch(out)?.group(1)?.trim() ?? 'unknown';
    final pid = int.tryParse(RegExp(r'pid = (\d+)').firstMatch(out)?.group(1) ?? '');
    final exit = int.tryParse(RegExp(r'last exit code = (\d+)').firstMatch(out)?.group(1) ?? '');
    return ServiceStatus(
      state: switch (stateStr) {
        'running' => ServiceState.running,
        'spawn scheduled' || 'spawning' => ServiceState.starting,
        _ => ServiceState.stopped,
      },
      startType: out.contains('runatload = 1') ? 'Run at login' : 'On demand',
      pid: pid,
      exitCode: exit == 0 ? null : exit,
      detail: out.trim(),
      warning: warning,
    );
  }

  Future<bool> _loaded() async =>
      (await Process.run('launchctl', ['print', '${await _domain()}/$label'])).exitCode == 0;

  @override
  Future<void> start() async {
    if (!plistFile.existsSync()) {
      throw ServiceException('No service definition at ${plistFile.path}. Install the service first.');
    }
    final domain = await _domain();
    if (!await _loaded()) {
      await runChecked('launchctl', ['bootstrap', domain, plistFile.path]);
    }
    await runChecked('launchctl', ['kickstart', '-k', '$domain/$label']);
    final s = await waitFor((s) => s.isRunning, timeout: const Duration(seconds: 15));
    if (!s.isRunning) {
      throw ServiceException(
        'The daemon did not stay running'
        '${s.exitCode != null ? ' (exit code ${s.exitCode})' : ''}. Check the log below.',
      );
    }
  }

  @override
  Future<void> stop() async {
    final domain = await _domain();
    // bootout unloads the job; a KeepAlive agent would otherwise respawn.
    final r = await Process.run('launchctl', ['bootout', '$domain/$label']);
    if (r.exitCode != 0 && await _loaded()) {
      throw ServiceException(r.stderr.toString().trim());
    }
    await waitFor((s) => !s.isRunning, timeout: const Duration(seconds: 15));
  }

  @override
  Future<void> restart() async {
    if (await _loaded()) {
      await runChecked('launchctl', ['kickstart', '-k', '${await _domain()}/$label']);
      await waitFor((s) => s.isRunning, timeout: const Duration(seconds: 15));
    } else {
      await start();
    }
  }

  /// Writes (or rewrites) the LaunchAgent so the daemon runs from
  /// sshnpd.yaml, then loads it. Existing definitions are backed up.
  @override
  Future<void> install() async {
    final bin = paths.sshnpdBinary;
    if (!bin.existsSync()) {
      throw ServiceException(
        '${bin.path} not found. Install NoPorts first (universal.sh puts it in ~/.local/bin).',
      );
    }
    await logFile.parent.create(recursive: true);
    if (plistFile.existsSync()) {
      await plistFile.copy('${plistFile.path}.bak');
      if (await _loaded()) {
        await Process.run('launchctl', ['bootout', '${await _domain()}/$label']);
      }
    }
    await plistFile.parent.create(recursive: true);
    await plistFile.writeAsString(
      buildPlist(
        label: label,
        programArguments: [bin.path, '--config', paths.configFile.path],
        logPath: logFile.path,
      ),
      flush: true,
    );
    await runChecked('launchctl', ['bootstrap', await _domain(), plistFile.path]);
  }

  @override
  Future<String> recentLogs({int lines = 200}) async {
    final plist = plistFile.existsSync() ? plistFile.readAsStringSync() : '';
    final path = _standardOutPath(plist);
    if (path != null && File(path).existsSync()) {
      final all = (await File(path).readAsString()).trimRight().split('\n');
      final tail = all.length > lines ? all.sublist(all.length - lines) : all;
      final text = tail.join('\n').trim();
      return text.isEmpty ? 'Log file $path is empty.' : text;
    }
    final result = await Process.run('log', [
      'show', '--style', 'compact', '--last', '2h',
      '--predicate', 'process == "sshnpd"',
    ]);
    final all = result.stdout.toString().trim().split('\n');
    final tail = all.length > lines ? all.sublist(all.length - lines) : all;
    final text = tail.join('\n').trim();
    return text.isEmpty ? 'No log entries for sshnpd in the last 2 hours.' : text;
  }

  @override
  Future<bool> isElevated() async => true;

  // ---- plist helpers (pure, unit tested) ----

  static String _xml(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  static String buildPlist({
    required String label,
    required List<String> programArguments,
    required String logPath,
  }) {
    final args = programArguments.map((a) => '\t\t<string>${_xml(a)}</string>').join('\n');
    return '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
\t<key>Label</key>
\t<string>${_xml(label)}</string>
\t<key>ProgramArguments</key>
\t<array>
$args
\t</array>
\t<key>KeepAlive</key>
\t<true/>
\t<key>RunAtLoad</key>
\t<true/>
\t<key>StandardOutPath</key>
\t<string>${_xml(logPath)}</string>
\t<key>StandardErrorPath</key>
\t<string>${_xml(logPath)}</string>
</dict>
</plist>
''';
  }

  static List<String> parseProgramArguments(String plist) {
    final m = RegExp(r'<key>ProgramArguments</key>\s*<array>(.*?)</array>', dotAll: true)
        .firstMatch(plist);
    if (m == null) return const [];
    return RegExp(r'<string>(.*?)</string>', dotAll: true)
        .allMatches(m.group(1)!)
        .map((x) => x.group(1)!.trim().replaceAll('&amp;', '&').replaceAll('&lt;', '<').replaceAll('&gt;', '>'))
        .toList();
  }

  static String? _standardOutPath(String plist) {
    final m = RegExp(r'<key>StandardOutPath</key>\s*<string>(.*?)</string>', dotAll: true)
        .firstMatch(plist);
    return m?.group(1)?.trim();
  }

  /// A definition this app wrote: binary plus `--config <our yaml>` only.
  static bool isManagedDefinition(List<String> args, String configPath) =>
      args.length == 3 && args[1] == '--config' && args[2] == configPath;
}
