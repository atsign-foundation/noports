@TestOn('!windows')
library;

import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  late Directory root;
  late Directory shims;

  /// Writes an `sh` script called [name], with [body], into the shims.
  void shim(String name, String body) {
    final String file = path.join(shims.path, name);
    File(file).writeAsStringSync('#!/bin/sh\n$body');
    final result = Process.runSync('chmod', ['+x', file]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
  }

  /// Copies [items] from this package into [dir].
  void copy(List<String> items, Directory dir) {
    for (final String item in items) {
      final result = Process.runSync('cp', ['-R', item, dir.path]);
      expect(result.exitCode, 0, reason: '${result.stderr}');
    }
  }

  /// Runs the bash [script] in [dir], with a dart that fails to compile
  /// [fail] and compiles everything else.
  Future<ProcessResult> build(String script, Directory dir, {String? fail}) =>
      Process.run(
        'bash',
        [script],
        workingDirectory: dir.path,
        environment: {
          'PATH': '${shims.path}:${Platform.environment['PATH']}',
          if (fail != null) 'FAIL': fail,
        },
      );

  setUp(() {
    root = Directory(
      Directory.systemTemp
          .createTempSync('build_scripts_test')
          .resolveSymbolicLinksSync(),
    );
    addTearDown(() => root.deleteSync(recursive: true));
    shims = Directory(path.join(root.path, 'shims'))..createSync();
    shim(
      'dart',
      'out=\n'
          'while [ \$# -gt 0 ]; do\n'
          '  if [ "\$1" = -o ]; then out=\$2; fi\n'
          '  shift\n'
          'done\n'
          'if [ -n "\${FAIL:-}" ] && [ "\$out" = "\$FAIL" ]; then\n'
          '  echo "cannot compile \$out" >&2\n'
          '  exit 1\n'
          'fi\n'
          'if [ -n "\$out" ]; then echo compiled > "\$out"; fi\n',
    );
    shim('npm', 'exit 0\n');
  });

  group('buildBinaries', () {
    late Directory package;

    setUp(() {
      package = Directory(path.join(root.path, 'sshnoports'))..createSync();
      Directory(path.join(package.path, 'bin', 'demo'))
          .createSync(recursive: true);
      copy(['buildBinaries', 'launchers'], package);
    });

    test('copies the launchers once every compile has succeeded', () async {
      final result = await build('buildBinaries', package);

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(File(path.join(package.path, 'bin', 'atsc')).existsSync(), isTrue);
      expect(File(path.join(package.path, 'bin', 'npt')).existsSync(), isTrue);
    });

    test('stops before the launchers when a compile fails', () async {
      final result = await build('buildBinaries', package, fail: 'bin/srv');

      expect(result.exitCode, isNot(0));
      expect(result.stdout, contains('Failed to compile: srv\n'));
      expect(File(path.join(package.path, 'bin', 'npt')).existsSync(), isFalse);
    });
  });

  group('buildArchive', () {
    late Directory package;
    late String buildArchive;

    setUp(() {
      package = Directory(
        path.join(root.path, 'packages', 'dart', 'sshnoports'),
      )..createSync(recursive: true);
      copy(['buildArchive', 'launchers', 'bundles', 'LICENSE'], package);
      buildArchive = path.join(package.path, 'buildArchive');
      final dist = Directory(
        path.join(root.path, 'apps', 'admin', 'webapp', 'dist'),
      )..createSync(recursive: true);
      File(path.join(dist.path, 'index.html')).writeAsStringSync('admin\n');
    });

    test('archives the launchers once every compile has succeeded', () async {
      final result = await build(buildArchive, root);

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      final String archive = path.join(package.path, 'build', 'sshnp');
      expect(File(path.join(archive, 'atsc')).existsSync(), isTrue);
      expect(File(path.join(archive, 'debug', 'atsc')).existsSync(), isTrue);
      expect(File(path.join(archive, 'npt')).existsSync(), isTrue);
      expect(File('$archive.tgz').existsSync(), isTrue);
    });

    test('stops before the launchers when a compile fails', () async {
      final result =
          await build(buildArchive, root, fail: 'build/sshnp/debug/atsc');

      expect(result.exitCode, isNot(0));
      expect(
        result.stdout,
        contains('Failed to compile: build/sshnp/debug/atsc\n'),
      );
      expect(
        File(path.join(package.path, 'build', 'sshnp', 'npt')).existsSync(),
        isFalse,
      );
    });
  });
}
