@TestOn('!windows')
library;

import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory(
      Directory.systemTemp
          .createTempSync('packaging_test')
          .resolveSymbolicLinksSync(),
    );
    addTearDown(() => root.deleteSync(recursive: true));
  });

  /// Writes an `sh` script called [name], with [body], into [dir].
  void shim(Directory dir, String name, String body) {
    final String file = path.join(dir.path, name);
    File(file).writeAsStringSync('#!/bin/sh\n$body');
    final result = Process.runSync('chmod', ['+x', file]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
  }

  test(
      'every file the deb and rpm take is in the archive multibuild builds '
      'for Linux', () async {
    final Map workflow = loadYaml(
        File('../../../.github/workflows/multibuild.yaml').readAsStringSync());
    final Map job = workflow['jobs']['main_build'];
    final Map<String, bool> onLinux = {
      "\${{ matrix.platform != 'windows' }}": true,
      "\${{ matrix.platform == 'linux' }}": true,
      "\${{ matrix.platform == 'windows' }}": false,
    };
    final List<String> runs = [];
    bool started = false;
    for (final Map step in job['steps']) {
      final String? run = step['run'];
      if (step['name'] == 'Create directories') started = true;
      if (!started || run == null) continue;
      if (run.contains('nfpm pkg')) break;
      final String? condition = step['if'];
      expect(
        condition == null || onLinux.containsKey(condition),
        isTrue,
        reason: 'step "${step['name']}" has a condition this test does not '
            'know: $condition',
      );
      if (condition == null || onLinux[condition]!) runs.add(run);
    }
    final String script =
        runs.join('\n').replaceAll('\${{ matrix.arch }}', 'amd64');
    expect(script, isNot(contains('\${{')));
    expect(script, contains('help2man'));

    final work = Directory(path.join(root.path, 'sshnoports'))..createSync();
    for (final String item in [
      'launchers',
      'man',
      'bundles',
      'LICENSE',
      'CHANGELOG.md',
    ]) {
      final copy = Process.runSync('cp', ['-R', item, work.path]);
      expect(copy.exitCode, 0, reason: '${copy.stderr}');
    }
    final shims = Directory(path.join(root.path, 'shims'))..createSync();
    shim(
      shims,
      'dart',
      'out=\n'
          'while [ \$# -gt 0 ]; do\n'
          '  if [ "\$1" = -o ]; then out=\$2; fi\n'
          '  shift\n'
          'done\n'
          'if [ -n "\$out" ]; then\n'
          '  printf \'#!/bin/sh\\necho compiled\\n\' > "\$out"\n'
          '  chmod +x "\$out"\n'
          'fi\n',
    );
    shim(shims, 'sudo', 'exit 0\n');
    shim(
      shims,
      'help2man',
      'include= out= program=\n'
          'while [ \$# -gt 0 ]; do\n'
          '  case \$1 in\n'
          '  --include) include=\$2; shift ;;\n'
          '  -o) out=\$2; shift ;;\n'
          '  -*) ;;\n'
          '  *) program=\$1 ;;\n'
          '  esac\n'
          '  shift\n'
          'done\n'
          '[ -f "\$include" ] || { echo "no \$include" >&2; exit 1; }\n'
          '"\$program" --help > /dev/null || exit 1\n'
          'echo "\$program" > "\$out"\n',
    );
    final String scriptFile = path.join(root.path, 'steps.sh');
    File(scriptFile).writeAsStringSync(script);

    final result = await Process.run(
      'bash',
      ['--noprofile', '--norc', '-eo', 'pipefail', scriptFile],
      workingDirectory: work.path,
      environment: {
        'PATH': '${shims.path}:${Platform.environment['PATH']}',
        'ARCH': 'amd64',
        'BINS': job['env']['BINS'],
        'CROSS': '',
        'EXT': '',
        'VERSION': '0.0.0',
      },
    );
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');

    final Map nfpm = loadYaml(File('nfpm.yaml').readAsStringSync());
    final List<String> sources = [
      for (final Map content in nfpm['contents']) content['src'],
      ...(nfpm['scripts'] as Map).values.cast<String>(),
    ];
    expect(sources.where((s) => s.startsWith('./sshnp/')), isNotEmpty);
    expect(
      sources.where((s) => !File(path.join(work.path, s)).existsSync()),
      isEmpty,
      reason: 'of ${sources.length} sources',
    );
  });

  test(
      "universal.sh's cleanup removes atsc, srv and each program install.sh "
      'installs', () {
    final String universal =
        File(path.join('bundles', 'universal.sh')).readAsStringSync();
    final String cleanup = RegExp(
      r'^cleanup_old_installation\(\) \{\n(.*?)\n\}\n',
      multiLine: true,
      dotAll: true,
    ).firstMatch(universal)!.group(1)!;
    final List<String> removed =
        RegExp(r'^ *binaries="([^"]*)"$', multiLine: true)
            .firstMatch(cleanup)!
            .group(1)!
            .split(' ');
    final String install =
        File(path.join('bundles', 'shell', 'install.sh')).readAsStringSync();
    final Set<String> installed = {
      'atsc',
      'srv',
      for (final Match m
          in RegExp(r'install_program "([a-z_]+)"').allMatches(install))
        m.group(1)!,
    };
    expect(installed, hasLength(greaterThan(2)));

    expect(removed, containsAll(installed));
  });
}
