/// Catalogue: features/atsc/atsc.feature
@TestOn('!windows')
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  late Directory root;
  late Directory installation;
  late Directory onPath;
  late Directory elsewhere;

  /// The directory [relative] under the test's root, created if absent.
  Directory dir(String relative) =>
      Directory(path.join(root.path, relative))..createSync(recursive: true);

  /// Makes [file] executable.
  void executable(String file) {
    final result = Process.runSync('chmod', ['+x', file]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
  }

  /// Writes an executable called [name] into [where] that prints [label].
  void standIn(Directory where, String name, String label) {
    final file = path.join(where.path, name);
    File(file).writeAsStringSync("#!/bin/sh\necho '$label'\n");
    executable(file);
  }

  /// The environment with [onPath] first on the PATH.
  Map<String, String> pathFirst() => {
        'PATH': '${onPath.path}:${Platform.environment['PATH']}',
      };

  setUpAll(() async {
    root = Directory(
      Directory.systemTemp
          .createTempSync('srv_installation')
          .resolveSymbolicLinksSync(),
    );
    installation = dir('opt/a');
    final compiled = await Process.run(Platform.resolvedExecutable, [
      'compile',
      'exe',
      path.join('test', 'print_srv_path.dart'),
      '-o',
      path.join(installation.path, 'atsc'),
    ]);
    expect(compiled.exitCode, 0,
        reason: '${compiled.stdout}${compiled.stderr}');
    File(path.join(installation.path, 'srv')).createSync();
    for (final String name in ['sshnpd', 'npt']) {
      final String launcher = path.join(installation.path, name);
      File(path.join('launchers', name)).copySync(launcher);
      executable(launcher);
    }
    onPath = dir('on_path');
    standIn(onPath, 'atsc', 'atsc on the PATH');
    standIn(onPath, 'srv', 'srv on the PATH');
    elsewhere = dir('elsewhere');
    File(path.join(elsewhere.path, 'srv')).createSync();
  });

  tearDownAll(() => root.deleteSync(recursive: true));

  /// Runs the old name [name] from the installation, from another directory
  /// that holds an srv of its own, with a different atsc and srv first on the
  /// PATH.
  Future<ProcessResult> runFromInstallation(String name) async {
    final control = await Process.run('/bin/sh', ['-c', 'atsc; srv'],
        environment: pathFirst());
    expect(control.stdout, 'atsc on the PATH\nsrv on the PATH\n');

    return Process.run(path.join(installation.path, name), [],
        environment: pathFirst(), workingDirectory: elsewhere.path);
  }

  test("sshnpd starts each session's srv from its own installation", () async {
    final result = await runFromInstallation('sshnpd');

    expect(result.stdout, '${path.join(installation.path, 'srv')}\n',
        reason: '${result.stderr}');
  });

  test('a client starts its srv from its own installation', () async {
    final result = await runFromInstallation('npt');

    expect(result.stdout, '${path.join(installation.path, 'srv')}\n',
        reason: '${result.stderr}');
  });
}
