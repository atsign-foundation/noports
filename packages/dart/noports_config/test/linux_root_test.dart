@Tags(['linux-root'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noports_config/features/config/config_repository.dart';
import 'package:noports_config/features/config/cubit/config_cubit.dart';
import 'package:noports_config/features/config/model/config_schema.dart';
import 'package:noports_config/features/health/cubit/health_cubit.dart';
import 'package:noports_config/features/health/health_checks.dart';
import 'package:noports_config/features/service/cubit/service_cubit.dart';
import 'package:noports_config/platform/daemon_paths.dart';
import 'package:noports_config/platform/linux_service_manager.dart';
import 'package:noports_config/platform/privileged_runner.dart';
import 'package:noports_core/sshnpd.dart';

/// The Linux paths for real: /etc/noports, the sshnpd systemd unit from
/// the noports package, journalctl, and the one-call "save and restart".
///
/// Runs only as root on Linux (so the privileged runner needs no polkit
/// agent) with the noports package installed and an ephemeral environment
/// reachable:
///   EE_ROOT        atDirectory, e.g. vip.ve.atsign.zone:2500
///   EE_DEVICE_KEYS an .atKeys file for the device atsign (enrolled or
///                  master keys), readable by root
///   EE_DEVICE      the device atsign (default cfgdev)
///   EE_MANAGER     the manager atsign (default cfgmgr)
///   sudo -E env PATH=\$PATH flutter test --tags linux-root test/linux_root_test.dart
void main() {
  final env = Platform.environment;
  final root = env['EE_ROOT'];
  final deviceKeys = env['EE_DEVICE_KEYS'];
  final isRoot =
      Platform.isLinux &&
      Process.runSync('id', ['-u']).stdout.toString().trim() == '0';
  if (root == null || deviceKeys == null || !isRoot) {
    test(
      'linux root test not configured',
      () {},
      skip: 'needs root on Linux, EE_ROOT and EE_DEVICE_KEYS',
    );
    return;
  }
  final device = '@${(env['EE_DEVICE'] ?? 'cfgdev').replaceFirst('@', '')}';
  final manager = '@${(env['EE_MANAGER'] ?? 'cfgmgr').replaceFirst('@', '')}';

  final paths = DaemonPaths.instance; // the real ones
  final manager_ = LinuxServiceManager();
  final template = File('assets/sshnpd.template.yaml').readAsStringSync();

  setUpAll(() async {
    expect(paths.configNeedsPrivileges, isTrue);
    expect(paths.configDir.path, '/etc/noports');
    expect(await PrivilegedRunner.instance.alreadyPrivileged(), isTrue);
    expect(paths.sshnpdBinary.existsSync(), isTrue, reason: 'noports deb');
    expect(
      (await manager_.status()).isInstalled,
      isTrue,
      reason: 'sshnpd unit from the noports package',
    );
    await Process.run('systemctl', ['stop', 'sshnpd']);
  });

  tearDownAll(() async {
    await Process.run('systemctl', ['stop', 'sshnpd']);
  });

  test(
    'save and restart: one call writes /etc/noports and starts the unit',
    () async {
      final repo = ConfigRepository(template: () async => template);
      final cubit = ConfigCubit(repo);
      await cubit.load();
      cubit.update((d) {
        d.atsign = device.substring(1);
        d.keysFile = deviceKeys;
        d.managers = [manager];
        d.deviceName = 'linux-root-test';
      });
      cubit.setField(ConfigSchema.byOption(SshnpdOption.rootServer), root);
      expect(cubit.state.problems, isEmpty);

      final before = await manager_.status();
      expect(before.isRunning, isFalse);

      // The package's unit says User=1000; the daemon must run as the
      // person who enrolled (SUDO_USER here), like universal.sh arranges.
      final me = LinuxServiceManager.currentUser();
      final script = manager_.privilegedRestartScript;
      expect(script, endsWith('systemctl restart sshnpd'));
      if (manager_.unitUid() != me.uid) {
        expect(manager_.adoptedUser, me.name);
        expect(script, contains('systemctl daemon-reload'));
      }
      final ok = await cubit.save(andThen: script);
      expect(ok, isTrue, reason: cubit.state.error);
      expect(manager_.unitUid(), me.uid, reason: 'unit now runs as $me');
      expect(manager_.adoptedUser, isNull);
      expect(
        File('/etc/noports/sshnpd.yaml').readAsStringSync(),
        contains(device),
      );

      final service = ServiceCubit(
        manager_,
        pollInterval: const Duration(hours: 1),
      );
      expect(
        await service.settleAfterRestart(),
        isTrue,
        reason: service.state.error,
      );
      expect(service.state.status!.isRunning, isTrue);
      expect(service.state.status!.pid, isNotNull);

      // The daemon really came up on that file: it says so in the journal.
      String logs = '';
      for (var i = 0; i < 30 && !logs.contains('Daemon is running'); i++) {
        await Future<void>.delayed(const Duration(seconds: 2));
        logs = await manager_.recentLogs();
      }
      expect(logs, contains('Daemon is running'));
      expect(logs, contains('linux-root-test'));
      await service.close();
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'every in-app check passes against the live unit, and so does the doctor',
    () async {
      final health = HealthCubit(services: manager_);
      final results = await health.run();
      for (final r in results) {
        expect(
          r.level,
          isNot(CheckLevel.fail),
          reason: '${r.title}: ${r.message}',
        );
      }
      expect(
        results.firstWhere((r) => r.title == 'Daemon service').message,
        contains('Running'),
      );
      await health.runDoctor();
      expect(health.state.error, isNull);
      expect(health.state.doctorOutput, isNot(contains('ProcessException')));
      await health.close();
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test('a plain save keeps the unit as it was', () async {
    final repo = ConfigRepository(template: () async => template);
    final cubit = ConfigCubit(repo);
    await cubit.load();
    final pidBefore = (await manager_.status()).pid;
    cubit.setField(ConfigSchema.byOption(SshnpdOption.deviceGroup), 'g1');
    expect(await cubit.save(), isTrue, reason: cubit.state.error);
    expect(File('/etc/noports/sshnpd.yaml').readAsStringSync(), contains('g1'));
    expect(File('/etc/noports/sshnpd.yaml.bak').existsSync(), isTrue);
    expect((await manager_.status()).pid, pidBefore);
  });
}
