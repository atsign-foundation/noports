import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noports_config/features/config/config_repository.dart';
import 'package:noports_config/features/config/cubit/config_cubit.dart';
import 'package:noports_config/features/config/model/config_schema.dart';
import 'package:noports_config/platform/daemon_paths.dart';
import 'package:noports_core/sshnpd.dart';

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
    cubit.replaceYaml(saved.replaceFirst("'@dev'", "'@other'").replaceFirst('"@dev"', '"@other"'));
    expect(cubit.state.yamlError, isNull);
    expect(cubit.state.doc!.atsign, '@other');
  });
}
