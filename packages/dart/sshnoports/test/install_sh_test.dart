@TestOn('!windows')
library;

import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  final bool isRoot =
      Process.runSync('id', ['-u']).stdout.toString().trim() == '0';

  late Directory root;
  late Directory bundle;
  late Directory home;
  late Directory prefix;

  /// Writes an executable stand-in at [file] which prints [label] and then
  /// each argument it was given, one per line in brackets.
  void standIn(String file, String label) {
    File(file).writeAsStringSync(
      '#!/bin/sh\n'
      "echo '$label'\n"
      'for a in "\$@"; do printf \'[%s]\\n\' "\$a"; done\n',
    );
    final result = Process.runSync('chmod', ['+x', file]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
  }

  /// Runs install.sh from the bundle with [args], as a user whose home is
  /// [home].
  Future<ProcessResult> install(List<String> args) => Process.run(
        '/bin/sh',
        [path.join(bundle.path, 'install.sh'), ...args],
        environment: {
          'HOME': home.path,
          'USER': 'tester',
          'PATH': Platform.environment['PATH']!,
        },
        includeParentEnvironment: false,
      );

  /// The names in [dir], sorted, or none when it does not exist.
  List<String> namesIn(String dir) => Directory(dir).existsSync()
      ? (Directory(dir).listSync().map((e) => path.basename(e.path)).toList()
        ..sort())
      : [];

  setUp(() {
    root = Directory(
      Directory.systemTemp
          .createTempSync('install_sh_test')
          .resolveSymbolicLinksSync(),
    );
    addTearDown(() => root.deleteSync(recursive: true));
    bundle = Directory(path.join(root.path, 'sshnp'))..createSync();
    Directory(path.join(bundle.path, 'debug')).createSync();
    home = Directory(path.join(root.path, 'home'))..createSync();
    prefix = Directory(path.join(root.path, 'prefix'));
    File(path.join('bundles', 'shell', 'install.sh'))
        .copySync(path.join(bundle.path, 'install.sh'));
    final copy = Process.runSync('cp', ['-R', 'launchers/.', bundle.path]);
    expect(copy.exitCode, 0, reason: '${copy.stderr}');
    standIn(path.join(bundle.path, 'atsc'), 'atsc 1');
    standIn(path.join(bundle.path, 'srv'), 'srv');
    standIn(path.join(bundle.path, 'debug', 'atsc'), 'debug atsc');
  });

  group('install.sh', () {
    test(
        'a non-root install into a chosen directory links nothing into '
        '~/.local/bin', () async {
      final result = await install(['-b', prefix.path, 'npt']);

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(namesIn(prefix.path), ['atsc', 'npt', 'srv']);
      expect(namesIn(path.join(home.path, '.local', 'bin')), isEmpty);
    });

    test(
        'installing a program also installs the atsc it runs, and srv when '
        'it needs one', () async {
      final activate = await install(['-b', prefix.path, 'at_activate']);
      expect(activate.exitCode, 0);
      expect(namesIn(prefix.path), ['at_activate', 'atsc']);

      final npt = await install(['-b', prefix.path, 'npt']);
      expect(npt.exitCode, 0);
      expect(namesIn(prefix.path), ['at_activate', 'atsc', 'npt', 'srv']);

      final run = await Process.run(path.join(prefix.path, 'npt'), ['-x']);
      expect(run.stdout, 'atsc 1\n[npt]\n[-x]\n');
    });

    test(
        'installing an unchanged atsc again keeps the previous one as '
        'atsc.old', () async {
      expect((await install(['-b', prefix.path, 'sshnp'])).exitCode, 0);
      standIn(path.join(bundle.path, 'atsc'), 'atsc 2');

      expect((await install(['-b', prefix.path, 'sshnp'])).exitCode, 0);
      expect((await install(['-b', prefix.path, 'npt'])).exitCode, 0);

      final current = await Process.run(path.join(prefix.path, 'atsc'), []);
      final old = await Process.run(path.join(prefix.path, 'atsc.old'), []);
      expect(current.stdout, 'atsc 2\n');
      expect(old.stdout, 'atsc 1\n');
    });

    test('the debug srvd is installed with debug_atsc in the chosen directory',
        () async {
      final result = await install(['-b', prefix.path, 'debug_srvd']);

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(namesIn(prefix.path), ['debug_atsc', 'debug_srvd']);
      final run = await Process.run(path.join(prefix.path, 'debug_srvd'), []);
      expect(run.stdout, 'debug atsc\n[srvd]\n');
    });

    test('a missing ~/.profile is created with ~/.local/bin on its PATH',
        () async {
      final result = await install(['-b', prefix.path, 'npt']);

      expect(result.stderr, isEmpty);
      expect(
        File(path.join(home.path, '.profile')).readAsStringSync(),
        'PATH="\$PATH:\$HOME/.local/bin"\n',
      );
    });

    test('a ~/.profile that puts ~/.local/bin on the PATH is left alone',
        () async {
      final profile = File(path.join(home.path, '.profile'))
        ..writeAsStringSync('export PATH="\$HOME/.local/bin:\$PATH"\n');

      final result = await install(['-b', prefix.path, 'npt']);

      expect(result.stderr, isEmpty);
      expect(
        profile.readAsStringSync(),
        'export PATH="\$HOME/.local/bin:\$PATH"\n',
      );
    });

    test('a ~/.profile without ~/.local/bin on the PATH has it added',
        () async {
      final profile = File(path.join(home.path, '.profile'))
        ..writeAsStringSync('umask 022\n');

      final result = await install(['-b', prefix.path, 'npt']);

      expect(result.stderr, isEmpty);
      expect(
        profile.readAsStringSync(),
        'umask 022\nPATH="\$PATH:\$HOME/.local/bin"\n',
      );
    });
  }, skip: isRoot ? 'install.sh installs differently as root' : false);
}
