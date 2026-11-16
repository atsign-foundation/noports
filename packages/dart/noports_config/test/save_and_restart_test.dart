import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noports_config/features/config/config_repository.dart';
import 'package:noports_config/features/config/cubit/config_cubit.dart';
import 'package:noports_config/features/config/model/config_schema.dart';
import 'package:noports_config/platform/daemon_paths.dart';
import 'package:noports_config/platform/linux_service_manager.dart';
import 'package:noports_config/platform/privileged_runner.dart';
import 'package:noports_core/sshnpd.dart';

/// Records every privileged call and runs it as the current user; the
/// temp dir is ours. Each call stands for one password prompt.
class RecordingRunner extends PrivilegedRunner {
  final scripts = <String>[];

  @override
  Future<String> runShell(String script) async {
    scripts.add(script);
    final r = await Process.run('sh', ['-c', script]);
    if (r.exitCode != 0) throw Exception(r.stderr.toString());
    return r.stdout.toString();
  }

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> alreadyPrivileged() async => false;
}

void main() {
  late Directory tmp;
  late RecordingRunner runner;
  late ConfigRepository repo;
  final template = File('assets/sshnpd.template.yaml').readAsStringSync();

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('noports_config_sr');
    runner = RecordingRunner();
    repo = ConfigRepository(
      paths: DaemonPaths.forTest(
        configDir: Directory('${tmp.path}/etc/noports'),
        binDir: Directory('${tmp.path}/bin'),
        configNeedsPrivileges: true,
      ),
      template: () async => template,
      runner: runner,
    );
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test('save and restart is one privileged call on Linux', () async {
    final cubit = ConfigCubit(repo);
    await cubit.load();
    cubit.setField(ConfigSchema.byOption(SshnpdOption.atsign), '@dev');
    cubit.setField(ConfigSchema.byOption(SshnpdOption.managers), ['@client']);

    final restart = LinuxServiceManager(runner: runner).privilegedRestartScript;
    expect(restart, 'systemctl restart sshnpd');

    // Stand in for systemctl: record that the restart ran after the write.
    final marker = File('${tmp.path}/restarted');
    final ok = await cubit.save(
      andThen: 'echo restarted > ${PrivilegedRunner.q(marker.path)}',
    );
    expect(ok, isTrue);
    expect(runner.scripts, hasLength(1), reason: 'exactly one prompt');
    expect(runner.scripts.single, contains('install -m 644'));
    expect(runner.scripts.single, contains('&& echo restarted > '));
    expect(repo.file.existsSync(), isTrue);
    expect(marker.existsSync(), isTrue);
  });

  test('a plain save stays a single call with nothing appended', () async {
    final cubit = ConfigCubit(repo);
    await cubit.load();
    cubit.setField(ConfigSchema.byOption(SshnpdOption.atsign), '@dev');
    cubit.setField(ConfigSchema.byOption(SshnpdOption.managers), ['@client']);
    expect(await cubit.save(), isTrue);
    expect(runner.scripts, hasLength(1));
    expect(runner.scripts.single, isNot(contains('&& systemctl')));
  });

  test('a failed restart surfaces as a save error', () async {
    final cubit = ConfigCubit(repo);
    await cubit.load();
    cubit.setField(ConfigSchema.byOption(SshnpdOption.atsign), '@dev');
    cubit.setField(ConfigSchema.byOption(SshnpdOption.managers), ['@client']);
    final ok = await cubit.save(andThen: 'echo boom >&2; exit 3');
    expect(ok, isFalse);
    expect(cubit.state.error, contains('boom'));
    // The file was still written before the restart failed.
    expect(repo.file.existsSync(), isTrue);
  });
}
