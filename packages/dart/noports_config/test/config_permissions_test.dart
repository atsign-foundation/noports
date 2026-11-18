import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noports_config/features/config/config_repository.dart';
import 'package:noports_config/features/config/cubit/config_cubit.dart';
import 'package:noports_config/features/health/cubit/health_cubit.dart';
import 'package:noports_config/features/health/health_checks.dart';
import 'package:noports_config/platform/daemon_paths.dart';
import 'package:noports_config/platform/privileged_runner.dart';
import 'package:noports_config/platform/service_manager.dart';

/// Stands in for root: `cat` of the config answers with [content] whatever
/// the file's mode; everything else runs as the current user.
class RootReadsRunner extends PrivilegedRunner {
  RootReadsRunner(this.content);
  final String content;
  final scripts = <String>[];

  @override
  Future<String> runShell(String script) async {
    scripts.add(script);
    if (script.startsWith('cat ')) return content;
    final r = await Process.run('sh', ['-c', script]);
    if (r.exitCode != 0) throw Exception(r.stderr.toString());
    return r.stdout.toString();
  }

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> alreadyPrivileged() async => false;
}

class NoService extends ServiceManager {
  @override
  String get serviceName => 'none';
  @override
  String get logSourceDescription => 'none';
  @override
  Future<ServiceStatus> status() async => const ServiceStatus.notInstalled();
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<String> recentLogs({int lines = 200}) async => '';
  @override
  Future<bool> isElevated() async => true;
}

void main() {
  final isRoot =
      !Platform.isWindows &&
      Process.runSync('id', ['-u']).stdout.toString().trim() == '0';
  // A mode means nothing to root, and Windows has no chmod.
  final skip = Platform.isWindows || isRoot
      ? 'needs a POSIX account that is not root'
      : null;

  late Directory tmp;
  late DaemonPaths paths;
  final template = File('assets/sshnpd.template.yaml').readAsStringSync();
  const onDisk =
      'atsign:\n  atsign: "@dev"\naccess:\n  managers:\n    - "@client"\n';

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('noports_config_perm');
    paths = DaemonPaths.forTest(
      configDir: Directory('${tmp.path}/etc/noports')
        ..createSync(recursive: true),
      binDir: Directory('${tmp.path}/bin'),
      configNeedsPrivileges: true,
    );
  });

  tearDown(() {
    Process.runSync('chmod', ['-R', 'u+rw', tmp.path]);
    tmp.deleteSync(recursive: true);
  });

  /// What an earlier build left behind: a config only root can open.
  void lockOut() {
    paths.configFile.writeAsStringSync(onDisk);
    Process.runSync('chmod', ['000', paths.configFile.path]);
  }

  test(
    'a root-only config is read with administrator rights, then saved',
    () async {
      lockOut();
      final runner = RootReadsRunner(onDisk);
      final cubit = ConfigCubit(
        ConfigRepository(
          paths: paths,
          template: () async => template,
          runner: runner,
          ownerGroup: () => null,
        ),
      );
      await cubit.load();
      expect(cubit.state.error, isNull);
      expect(cubit.state.existed, isTrue);
      expect(cubit.state.doc!.atsign, '@dev');
      expect(runner.scripts.single, startsWith('cat '));
    },
    skip: skip,
  );

  test('a user-owned config that cannot be read is an error', () async {
    lockOut();
    final runner = RootReadsRunner(onDisk);
    final cubit = ConfigCubit(
      ConfigRepository(
        paths: DaemonPaths.forTest(
          configDir: paths.configDir,
          binDir: paths.binDir,
        ),
        template: () async => template,
        runner: runner,
      ),
    );
    await cubit.load();
    expect(cubit.state.error, isNotNull);
    expect(runner.scripts, isEmpty, reason: 'no prompt where none is needed');
  }, skip: skip);

  test('the config check says the file cannot be read, not bad YAML', () async {
    lockOut();
    final health = HealthCubit(paths: paths, services: NoService());
    final result = (await health.run()).firstWhere(
      (r) => r.title == 'Configuration file',
    );
    expect(result.level, CheckLevel.fail);
    expect(result.message, contains('Your account cannot read'));
    expect(result.message, isNot(contains('parsed')));
    expect(result.fix, HealthFix.configuration);
    await health.close();
  }, skip: skip);

  group('accountCanRead', () {
    final linuxOnly = Platform.isLinux && !isRoot ? null : 'Linux, not root';

    test('follows owner, group and mode', () {
      final me = int.parse(Process.runSync('id', ['-u']).stdout.toString());
      final file = File('${tmp.path}/f')..writeAsStringSync('x');
      const nobody = 65534;

      Process.runSync('chmod', ['640', file.path]);
      expect(DaemonPaths.accountCanRead(file, me), isTrue);
      expect(DaemonPaths.accountCanRead(file, nobody), isFalse);
      expect(DaemonPaths.accountCanRead(file, 0), isTrue);

      Process.runSync('chmod', ['644', file.path]);
      expect(DaemonPaths.accountCanRead(file, nobody), isTrue);

      // Owner locked out, group allowed: the owner class is the one used.
      Process.runSync('chmod', ['040', file.path]);
      expect(DaemonPaths.accountCanRead(file, me), isFalse);
    }, skip: linuxOnly);

    test(
      'the daemon account that cannot read the config fails the check',
      () async {
        paths.configFile.writeAsStringSync(onDisk);
        Process.runSync('chmod', ['640', paths.configFile.path]);
        final health = HealthCubit(
          paths: DaemonPaths.forTest(
            configDir: paths.configDir,
            binDir: paths.binDir,
            configNeedsPrivileges: true,
            serviceUid: 65534,
          ),
          services: NoService(),
        );
        final result = (await health.run()).firstWhere(
          (r) => r.title == 'Configuration file',
        );
        expect(result.level, CheckLevel.fail);
        expect(result.message, contains('The daemon runs as uid 65534'));
        await health.close();
      },
      skip: linuxOnly,
    );
  });
}
