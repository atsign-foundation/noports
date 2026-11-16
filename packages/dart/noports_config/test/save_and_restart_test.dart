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

    // The unit already runs as this user here; adoption has its own tests.
    final restart = LinuxServiceManager(
      runner: runner,
      appUser: (uid: 1234, name: 'alice'),
      unitUid: () => 1234,
    ).privilegedRestartScript;
    expect(restart, 'systemctl restart sshnpd');

    // Stand in for systemctl: record that the restart ran after the write.
    final marker = File('${tmp.path}/restarted');
    final ok = await cubit.save(
      andThen: 'echo restarted > ${PrivilegedRunner.q(marker.path)}',
    );
    expect(ok, isTrue);
    expect(runner.scripts, hasLength(1), reason: 'exactly one prompt');
    expect(runner.scripts.single, contains('install -m 640'));
    expect(runner.scripts.single, contains('&& echo restarted > '));
    expect(repo.file.existsSync(), isTrue);
    expect(marker.existsSync(), isTrue);
  });

  test(
    'paths with a space and a quote survive the shell; .bak is kept',
    () async {
      final odd = Directory("${tmp.path}/it's here/etc noports");
      final repo2 = ConfigRepository(
        paths: DaemonPaths.forTest(
          configDir: odd,
          binDir: Directory('${tmp.path}/bin'),
          configNeedsPrivileges: true,
        ),
        template: () async => template,
        runner: runner,
      );
      final cubit = ConfigCubit(repo2);
      await cubit.load();
      cubit.setField(ConfigSchema.byOption(SshnpdOption.atsign), '@dev');
      cubit.setField(ConfigSchema.byOption(SshnpdOption.managers), ['@client']);
      expect(await cubit.save(), isTrue, reason: cubit.state.error);
      expect(repo2.file.existsSync(), isTrue);
      expect(File('${repo2.file.path}.bak').existsSync(), isFalse);

      cubit.setField(ConfigSchema.byOption(SshnpdOption.device), 'pc');
      expect(await cubit.save(), isTrue, reason: cubit.state.error);
      expect(File('${repo2.file.path}.bak').existsSync(), isTrue);
      expect(
        File('${repo2.file.path}.bak').readAsStringSync(),
        isNot(contains('name: pc')),
      );
      expect(repo2.file.readAsStringSync(), contains('name: pc'));
      // Nothing of the staging survives.
      expect(
        Directory.systemTemp.listSync().where(
          (e) => e.path.contains('noports-config-'),
        ),
        isEmpty,
      );
    },
  );

  group('daemon account (systemd User=)', () {
    LinuxServiceManager managerFor({
      required int unitUid,
      String name = 'alice',
      int uid = 1234,
    }) => LinuxServiceManager(
      runner: runner,
      dropInDir: '${tmp.path}/sshnpd.service.d',
      appUser: (uid: uid, name: name),
      unitUid: () => unitUid,
    );

    test('nothing is added when the unit already runs as this user', () {
      final m = managerFor(unitUid: 1234);
      expect(m.adoptedUser, isNull);
      expect(m.adoptUserScript(), isEmpty);
      expect(m.privilegedRestartScript, 'systemctl restart sshnpd');
    });

    test('nothing is added when systemd cannot be asked', () {
      final m = LinuxServiceManager(
        runner: runner,
        appUser: (uid: 1234, name: 'alice'),
        unitUid: () => null,
      );
      expect(m.adoptedUser, isNull);
      expect(m.privilegedRestartScript, 'systemctl restart sshnpd');
    });

    test(
      "the package's User=1000 is replaced in place, like universal.sh",
      () async {
        final m = managerFor(unitUid: 1000);
        expect(m.adoptedUser, 'alice');
        final dir = Directory(m.dropInDir)..createSync(recursive: true);
        final override = File('${dir.path}/override.conf')
          ..writeAsStringSync(
            '# Configuration of sshnpd service\n[Unit]\n\n[Service]\n'
            '# MANDATORY: User to run the daemon as\nUser=1000\n',
          );
        expect(
          m.privilegedRestartScript,
          endsWith('&& systemctl daemon-reload && systemctl restart sshnpd'),
        );
        await runner.runShell(m.adoptUserScript());
        final text = override.readAsStringSync();
        expect(text, contains('\nUser=alice\n'));
        expect(text, isNot(contains('1000')));
        expect(text, contains('# MANDATORY'), reason: 'edited, not replaced');
      },
    );

    test('a missing override.conf is created', () async {
      final m = managerFor(unitUid: 0);
      await runner.runShell(m.adoptUserScript());
      expect(
        File('${m.dropInDir}/override.conf').readAsStringSync(),
        '[Service]\nUser=alice\n',
      );
    });

    test('a name the shell or systemd could misread falls back to the uid', () {
      final m = managerFor(unitUid: 1000, name: 'Al Ice\$', uid: 4321);
      expect(m.adoptUserScript(), contains('User=4321'));
      expect(m.adoptUserScript(), isNot(contains('Al Ice')));
    });

    test('the combined save carries the adoption in the one call', () async {
      final m = managerFor(unitUid: 1000);
      final cubit = ConfigCubit(repo);
      await cubit.load();
      cubit.setField(ConfigSchema.byOption(SshnpdOption.atsign), '@dev');
      cubit.setField(ConfigSchema.byOption(SshnpdOption.managers), ['@client']);
      // Only the adoption half can run here; stand in for systemctl.
      final ok = await cubit.save(andThen: '${m.adoptUserScript()} && true');
      expect(ok, isTrue, reason: cubit.state.error);
      expect(runner.scripts, hasLength(1), reason: 'still one prompt');
      expect(
        File('${m.dropInDir}/override.conf').readAsStringSync(),
        contains('User=alice'),
      );
    });
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
