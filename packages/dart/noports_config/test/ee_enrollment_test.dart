@Tags(['ee'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noports_config/features/config/config_repository.dart';
import 'package:noports_config/features/config/cubit/config_cubit.dart';
import 'package:noports_config/features/config/model/config_schema.dart';
import 'package:noports_config/features/health/cubit/health_cubit.dart';
import 'package:noports_config/features/health/health_checks.dart';
import 'package:noports_config/features/keys/cubit/enrollment_cubit.dart';
import 'package:noports_config/features/keys/keys_repository.dart';
import 'package:noports_config/platform/daemon_paths.dart';
import 'package:noports_config/platform/device_names.dart';
import 'package:noports_config/platform/privileged_runner.dart';
import 'package:noports_config/platform/service_manager.dart';
import 'package:noports_core/sshnpd.dart';

/// End to end against a running ephemeral environment (EE).
///
/// Needs, in the environment:
///   EE_ROOT        atDirectory, e.g. vip.ve.atsign.zone:2500
///   EE_KEYS        directory holding the `@name_key.atKeys` files for the three
///                  atsigns below (as at_activate onboard wrote them)
///   EE_DEVICE      the device atsign, bare or with @ (default cfgdev)
///   EE_MANAGER     the client atsign allowed to connect (default cfgmgr)
///   EE_RELAY       the relay atsign (default cfgrelay)
///   EE_BIN         directory holding sshnpd (default ~/.local/bin; the
///                  Linux package puts it in /usr/bin)
/// and at_activate, sshnpd, sshnp and srvd on the PATH (EE_BIN and
/// ~/.local/bin are added). Run with:
///   flutter test --tags ee test/ee_enrollment_test.dart
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

class DirectRunner extends PrivilegedRunner {
  @override
  Future<String> runShell(String script) async {
    final r = await Process.run('sh', ['-c', script]);
    if (r.exitCode != 0) throw Exception(r.stderr.toString());
    return r.stdout.toString();
  }

  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<bool> alreadyPrivileged() async => true;
}

void main() {
  final env = Platform.environment;
  final root = env['EE_ROOT'];
  final keysDir = env['EE_KEYS'];
  if (root == null || keysDir == null) {
    test('EE not configured', () {}, skip: 'set EE_ROOT and EE_KEYS');
    return;
  }
  final device = '@${(env['EE_DEVICE'] ?? 'cfgdev').replaceFirst('@', '')}';
  final manager = '@${(env['EE_MANAGER'] ?? 'cfgmgr').replaceFirst('@', '')}';
  final relay = '@${(env['EE_RELAY'] ?? 'cfgrelay').replaceFirst('@', '')}';
  final bin = env['EE_BIN'] ?? '${env['HOME']}/.local/bin';
  final path = '$bin:${env['HOME']}/.local/bin:${env['PATH']}';
  final procEnv = {'PATH': path};

  Future<ProcessResult> atActivate(List<String> args) =>
      Process.run('at_activate', [...args, '-r', root], environment: procEnv);

  late Directory tmp;
  late DaemonPaths paths;
  final template = File('assets/sshnpd.template.yaml').readAsStringSync();

  setUpAll(() {
    tmp = Directory.systemTemp.createTempSync('noports_config_ee');
    paths = DaemonPaths.forTest(
      configDir: Directory('${tmp.path}/etc/noports'),
      binDir: Directory(bin),
      userHomeDir: Directory('${tmp.path}/home'),
    );
    DaemonPaths.instance = paths;
  });

  tearDownAll(() => tmp.deleteSync(recursive: true));

  /// A fresh OTP for the device atsign, issued with its manager keys.
  Future<String> freshOtp() async {
    final otpRes = await atActivate([
      'otp',
      '-a',
      device,
      '-k',
      '$keysDir/${device}_key.atKeys',
    ]);
    final otp = otpRes.stdout
        .toString()
        .replaceAll(RegExp(r'\x1B\[[0-9;]*[A-Za-z]'), '')
        .trim()
        .split('\n')
        .last
        .trim();
    expect(otp, matches(r'^[A-Z0-9]{6}$'), reason: 'otp: ${otpRes.stdout}');
    return otp;
  }

  /// Runs one enrollment of [device] as [name] into [into] and, once the
  /// request id is known, answers it with at_activate [verb] (approve or
  /// deny). Returns the final cubit state.
  Future<EnrollmentState> enrollAnd(
    String verb, {
    required DaemonPaths into,
    required String name,
  }) async {
    final otp = await freshOtp();
    final cubit = EnrollmentCubit(
      rootDomain: root,
      paths: into,
      retryInterval: const Duration(seconds: 2),
    );
    final answered = cubit.stream
        .firstWhere((s) => s.step == EnrollmentStep.awaitingApproval)
        .then(
          (s) => atActivate([
            verb,
            '-a',
            device,
            '-k',
            '$keysDir/${device}_key.atKeys',
            '-i',
            s.enrollmentId!,
          ]),
        );
    // ignore: avoid_print
    cubit.stream.listen((s) => print('[ee:$verb] ${s.step} ${s.error ?? ''}'));
    final done = cubit.stream.firstWhere(
      (s) => s.step == EnrollmentStep.done || s.error != null,
    );
    await cubit.enroll(rawAtsign: device, deviceName: name, passcode: otp);
    final last = await done;
    final r = await answered;
    expect(r.exitCode, 0, reason: '$verb: ${r.stdout}${r.stderr}');
    await cubit.close();
    return last;
  }

  test(
    'a denied enrollment leaves no usable keys behind and does not block a retry',
    () async {
      // Its own keys directory: the approve test above owns the main one.
      final home = Directory('${tmp.path}/home-denied')..createSync();
      final into = DaemonPaths.forTest(
        configDir: Directory('${tmp.path}/etc/noports'),
        binDir: Directory(bin),
        userHomeDir: home,
      );
      final stamp = DateTime.now().millisecondsSinceEpoch % 100000;
      final name = '${DeviceNames.fromHostname()}-deny$stamp';
      final dest = into.keysFileFor(device);

      final denied = await enrollAnd('deny', into: into, name: name);
      expect(denied.step, isNot(EnrollmentStep.done));
      expect(denied.error, contains('denied'), reason: denied.error);
      // Whatever the SDK left in the file must not look like device keys.
      if (dest.existsSync()) {
        final seen = KeysRepository.inspectSync(dest);
        // ignore: avoid_print
        print('[ee:deny] leftover ${dest.path}: ${seen.status}');
        expect(seen.status, isNot(KeysFileStatus.readable));
      }

      // The same device name again, approved this time. If this fails with
      // "Not overwriting" or AT0032 the app has a dead end to fix.
      final again = await enrollAnd('approve', into: into, name: name);
      expect(again.error, isNull, reason: again.error);
      expect(again.step, EnrollmentStep.done);
      expect(KeysRepository.inspectSync(dest).status, KeysFileStatus.readable);
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );

  late File deviceKeys;
  late String deviceName;

  test(
    'enroll with a bare atsign and an OTP, approve, keys land in ~/.atsign/keys',
    () async {
      final otpRes = await atActivate([
        'otp',
        '-a',
        device,
        '-k',
        '$keysDir/${device}_key.atKeys',
      ]);
      // The code is the last line; the rest is coloured progress text.
      final otp = otpRes.stdout
          .toString()
          .replaceAll(RegExp(r'\x1B\[[0-9;]*[A-Za-z]'), '')
          .trim()
          .split('\n')
          .last
          .trim();
      expect(otp, matches(r'^[A-Z0-9]{6}$'), reason: 'otp: ${otpRes.stdout}');

      // A fresh name each run: the atServer refuses a second enrollment for
      // an app/device pair that is already approved (AT0032).
      final stamp = DateTime.now().millisecondsSinceEpoch % 100000;
      deviceName = '${DeviceNames.fromHostname()}-$stamp';
      expect(DeviceNames.isValid(deviceName), isTrue);
      // ignore: avoid_print
      print('[ee] otp issued; enrolling $device as $deviceName');
      final cubit = EnrollmentCubit(
        rootDomain: root,
        paths: paths,
        retryInterval: const Duration(seconds: 2),
      );
      // Approve from "NoPorts Desktop" (here: at_activate with the manager
      // keys of the device atsign) as soon as the request id is known.
      final approved = cubit.stream
          .firstWhere((s) => s.step == EnrollmentStep.awaitingApproval)
          .then((s) async {
            final r = await atActivate([
              'approve',
              '-a',
              device,
              '-k',
              '$keysDir/${device}_key.atKeys',
              '-i',
              s.enrollmentId!,
            ]);
            return r;
          });
      // ignore: avoid_print
      cubit.stream.listen((s) => print('[ee] ${s.step} ${s.error ?? ''}'));
      final done = cubit.stream.firstWhere(
        (s) => s.step == EnrollmentStep.done || s.error != null,
      );
      // Bare atsign on purpose: what the reviewer typed.
      await cubit.enroll(
        rawAtsign: device.substring(1),
        deviceName: deviceName,
        passcode: otp,
      );
      final last = await done;
      expect(last.error, isNull);
      final approve = await approved;
      expect(approve.exitCode, 0, reason: '${approve.stdout}${approve.stderr}');
      expect(last.step, EnrollmentStep.done);
      expect(last.atsign, device);
      deviceKeys = last.keysFile!;
      expect(deviceKeys.path, '${paths.keysDir.path}/${device}_key.atKeys');
      expect(deviceKeys.existsSync(), isTrue);
      final json = jsonDecode(deviceKeys.readAsStringSync()) as Map;
      expect(json['atsign'], device);
      expect(json['enrollmentId'], last.enrollmentId);
      expect(KeysRepository.atsignOf(deviceKeys), device);
      await cubit.close();
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  late File configFile;

  test(
    'the saved sshnpd.yaml passes the in-app checks and the doctor',
    () async {
      final repo = ConfigRepository(
        paths: paths,
        template: () async => template,
        runner: DirectRunner(),
      );
      final cubit = ConfigCubit(repo);
      await cubit.load();
      cubit.update((d) {
        d.atsign = device.substring(1); // bare again; the setter normalizes
        d.keysFile = deviceKeys.path;
        d.managers = [manager.substring(1)];
        d.deviceName = deviceName;
      });
      cubit.setField(ConfigSchema.byOption(SshnpdOption.rootServer), root);
      cubit.setField(ConfigSchema.byOption(SshnpdOption.verbose), true);
      expect(cubit.state.problems, isEmpty);
      expect(await cubit.save(), isTrue);
      configFile = repo.file;
      final yaml = configFile.readAsStringSync();
      expect(yaml, contains(device));
      expect(yaml, contains(manager));
      expect(yaml, contains(deviceName));

      final health = HealthCubit(paths: paths, services: NoService());
      final results = await health.run();
      final failed = results.where((r) => r.level == CheckLevel.fail).toList();
      // Only the service check may fail: there is no unit in a temp dir.
      expect(failed.map((r) => r.title), ['Daemon service']);
      expect(failed.single.message, contains('install'));

      await health.runDoctor();
      expect(health.state.error, isNull);
      final out = health.state.doctorOutput!;
      expect(out, isNot(contains('ProcessException')));
      expect(out.toLowerCase(), contains('sshnpd'));
      await health.close();
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('sshnpd runs from that file and the manager sees the device', () async {
    final relayProc = await Process.start('srvd', [
      '-a',
      relay,
      '-k',
      '$keysDir/${relay}_key.atKeys',
      '-i',
      '127.0.0.1',
      '--pss',
      '--root-server',
      root,
    ], environment: procEnv);
    // --config, not SSHNPD_CONFIG: the released daemon ignores the variable.
    final daemon = await Process.start('sshnpd', [
      '--config',
      configFile.path,
    ], environment: procEnv);
    final daemonLog = StringBuffer();
    daemon.stdout.transform(utf8.decoder).listen(daemonLog.write);
    daemon.stderr.transform(utf8.decoder).listen(daemonLog.write);
    final relayLog = StringBuffer();
    relayProc.stdout.transform(utf8.decoder).listen(relayLog.write);
    relayProc.stderr.transform(utf8.decoder).listen(relayLog.write);
    try {
      ProcessResult? ls;
      final deadline = DateTime.now().add(const Duration(seconds: 120));
      while (DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(seconds: 3));
        ls = await Process.run('sshnp', [
          '-f',
          manager,
          '-t',
          device,
          '-r',
          relay,
          '-k',
          '$keysDir/${manager}_key.atKeys',
          '--root-server',
          root,
          '--list-devices',
          '--daemon-ping-timeout',
          '5',
        ], environment: procEnv);
        if ((ls.stdout.toString() + ls.stderr.toString()).contains(
          deviceName,
        )) {
          break;
        }
      }
      final listing = ls!.stdout.toString() + ls.stderr.toString();
      expect(
        listing,
        contains(deviceName),
        reason:
            'listing:\n$listing\n\ndaemon:\n$daemonLog\n\nrelay:\n$relayLog',
      );
    } finally {
      daemon.kill();
      relayProc.kill();
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
