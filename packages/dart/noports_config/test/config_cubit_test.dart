import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noports_config/features/config/config_repository.dart';
import 'package:noports_config/features/config/cubit/config_cubit.dart';
import 'package:noports_config/features/config/model/config_schema.dart';
import 'package:noports_config/platform/daemon_paths.dart';
import 'package:noports_config/platform/privileged_runner.dart';
import 'package:noports_core/sshnpd.dart';

/// Runs the shell script directly; the temp dir is ours so no rights needed.
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
  late Directory tmp;
  late ConfigRepository repo;
  final template = File('assets/sshnpd.template.yaml').readAsStringSync();

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('noports_config_test');
    repo = ConfigRepository(
      paths: DaemonPaths.forTest(
        configDir: Directory('${tmp.path}/etc'),
        binDir: Directory('${tmp.path}/bin'),
      ),
      template: () async => template,
      runner: DirectRunner(),
    );
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test('loads template when no file, saves creates file and backup', () async {
    final cubit = ConfigCubit(repo);
    await cubit.load();
    expect(cubit.state.status, ConfigStatus.ready);
    expect(cubit.state.existed, isFalse);
    expect(cubit.state.isUnconfigured, isTrue);
    // Unconfigured template cannot be saved: validation blocks it.
    expect(await cubit.save(), isFalse);
    expect(repo.file.existsSync(), isFalse);

    cubit.setField(ConfigSchema.byOption(SshnpdOption.atsign), '@dev');
    cubit.setField(ConfigSchema.byOption(SshnpdOption.managers), ['@client']);
    expect(cubit.state.isDirty, isTrue);
    expect(cubit.state.problems, isEmpty);
    expect(await cubit.save(), isTrue);
    expect(repo.file.existsSync(), isTrue);
    expect(cubit.state.isDirty, isFalse);
    expect(cubit.state.existed, isTrue);

    // Second save makes a backup of the first.
    cubit.setField(ConfigSchema.byOption(SshnpdOption.device), 'pc');
    expect(await cubit.save(), isTrue);
    expect(File('${repo.file.path}.bak').existsSync(), isTrue);
    expect(repo.file.readAsStringSync(), contains('name: pc'));
    expect(File('${repo.file.path}.tmp').existsSync(), isFalse);
  });

  test('atsign fields store @name whatever was typed', () async {
    final cubit = ConfigCubit(repo);
    await cubit.load();
    cubit.setField(ConfigSchema.byOption(SshnpdOption.atsign), 'CfgDev');
    expect(cubit.state.doc!.atsign, '@cfgdev');
    cubit.setField(ConfigSchema.byOption(SshnpdOption.managers), [
      'client',
      '@Other',
    ]);
    expect(cubit.state.doc!.managers, ['@client', '@other']);
    cubit.setField(ConfigSchema.byOption(SshnpdOption.policyManager), 'pol');
    expect(cubit.state.doc!.policyManager, '@pol');
    // Not an atsign at all: kept as typed so validation can point at it.
    cubit.setField(ConfigSchema.byOption(SshnpdOption.atsign), 'bad name');
    expect(cubit.state.doc!.atsign, 'bad name');
    expect(
      cubit.state.problems.map((p) => p.message).join(),
      contains('bad name'),
    );
  });

  test('invalid manager atsigns and port bounds are reported', () async {
    final cubit = ConfigCubit(repo);
    await cubit.load();
    cubit.setField(ConfigSchema.byOption(SshnpdOption.atsign), '@dev');
    cubit.setField(ConfigSchema.byOption(SshnpdOption.managers), ['al!ce']);
    expect(
      cubit.state.problems.map((p) => p.message).join(),
      contains('"al!ce" is not a valid atsign: invalid @sign'),
    );
    cubit.setField(ConfigSchema.byOption(SshnpdOption.managers), ['@c']);
    expect(cubit.state.problems, isEmpty);
    cubit.setField(ConfigSchema.byOption(SshnpdOption.policyManager), 'a@b');
    expect(cubit.state.problems.map((p) => p.option), [
      SshnpdOption.policyManager,
    ]);
    cubit.setField(ConfigSchema.byOption(SshnpdOption.policyManager), null);

    final port = ConfigSchema.byOption(SshnpdOption.localSshdPort);
    for (final (value, ok) in [
      (0, false),
      (1, true),
      (65535, true),
      (65536, false),
      ('abc', false),
    ]) {
      cubit.setField(port, value);
      expect(
        cubit.state.problems.any((p) => p.option == SshnpdOption.localSshdPort),
        !ok,
        reason: '$value',
      );
    }
  });

  test('device name follows the daemon rule, snakified first', () async {
    final cubit = ConfigCubit(repo);
    await cubit.load();
    cubit.setField(ConfigSchema.byOption(SshnpdOption.atsign), '@dev');
    cubit.setField(ConfigSchema.byOption(SshnpdOption.managers), ['@c']);
    final device = ConfigSchema.byOption(SshnpdOption.device);
    // What the daemon would accept after snakifying is accepted and stored
    // snakified.
    cubit.setField(device, 'My Laptop');
    expect(cubit.state.doc!.deviceName, 'my_laptop');
    expect(cubit.state.problems, isEmpty);
    cubit.update((d) => d.deviceName = 'Other  PC');
    expect(cubit.state.doc!.deviceName, 'other_pc');
  });

  test('device name follows the daemon rule', () async {
    final cubit = ConfigCubit(repo);
    await cubit.load();
    cubit.setField(ConfigSchema.byOption(SshnpdOption.atsign), '@dev');
    cubit.setField(ConfigSchema.byOption(SshnpdOption.managers), ['@c']);
    final device = ConfigSchema.byOption(SshnpdOption.device);
    for (final bad in ['x', '-pc', 'a' * 37]) {
      cubit.setField(device, bad);
      expect(
        cubit.state.problems.map((p) => p.option),
        contains(SshnpdOption.device),
        reason: bad,
      );
    }
    cubit.setField(device, 'my-pc');
    expect(cubit.state.problems, isEmpty);
  });

  test('revert restores saved text, replaceYaml reports errors', () async {
    final cubit = ConfigCubit(repo);
    await cubit.load();
    cubit.update((d) {
      d.atsign = '@dev';
      d.managers = ['@c'];
    });
    await cubit.save();
    final saved = cubit.state.source;

    cubit.setField(ConfigSchema.byOption(SshnpdOption.device), 'changed');
    expect(cubit.state.isDirty, isTrue);
    cubit.revert();
    expect(cubit.state.source, saved);
    expect(cubit.state.isDirty, isFalse);

    cubit.replaceYaml('atsign: [unclosed');
    expect(cubit.state.yamlError, isNotNull);
    expect(cubit.state.source, saved); // document untouched
    cubit.replaceYaml(
      saved
          .replaceFirst("'@dev'", "'@other'")
          .replaceFirst('"@dev"', '"@other"'),
    );
    expect(cubit.state.yamlError, isNull);
    expect(cubit.state.doc!.atsign, '@other');
  });
}
