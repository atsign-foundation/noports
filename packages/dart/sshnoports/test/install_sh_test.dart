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
  late Directory shims;

  /// Makes [file] executable.
  void executable(String file) {
    final result = Process.runSync('chmod', ['+x', file]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
  }

  /// Writes an executable stand-in at [file] which prints [label] and then
  /// each argument it was given, one per line in brackets.
  void standIn(String file, String label) {
    File(file).writeAsStringSync(
      '#!/bin/sh\n'
      "echo '$label'\n"
      'for a in "\$@"; do printf \'[%s]\\n\' "\$a"; done\n',
    );
    executable(file);
  }

  /// Writes an `sh` script called [name], with [body], into the directory
  /// that install.sh finds first on its PATH.
  void shim(String name, String body) {
    final String file = path.join(shims.path, name);
    File(file).writeAsStringSync('#!/bin/sh\n$body');
    executable(file);
  }

  /// Runs install.sh from the bundle with [args] under [umask], as a user
  /// whose home is [home], with the shims in front of the PATH of this
  /// process.
  Future<ProcessResult> install(List<String> args, {String umask = '022'}) =>
      Process.run(
        '/bin/sh',
        [
          '-c',
          'umask "\$1"; shift; exec /bin/sh "\$@"',
          'sh',
          umask,
          path.join(bundle.path, 'install.sh'),
          ...args,
        ],
        environment: {
          'HOME': home.path,
          'USER': 'tester',
          'PATH': '${shims.path}:${Platform.environment['PATH']}',
        },
        includeParentEnvironment: false,
      );

  /// Runs install.sh as root would run it, with `id` and `uname` shims, into
  /// [prefix] with [args].
  Future<ProcessResult> installAsRoot(List<String> args, {String? umask}) {
    shim('id', 'if [ "\$1" = -u ]; then echo 0; else exec /usr/bin/id "\$@"; fi\n');
    shim('uname', 'echo Linux\n');
    return install(['-b', prefix.path, ...args], umask: umask ?? '022');
  }

  /// The names in [dir], sorted, or none when it does not exist.
  List<String> namesIn(String dir) => Directory(dir).existsSync()
      ? (Directory(dir).listSync().map((e) => path.basename(e.path)).toList()
        ..sort())
      : [];

  /// What [program] prints to stdout when it is run with [args].
  Future<String> output(String program, [List<String> args = const []]) async =>
      (await Process.run(program, args)).stdout as String;

  /// The permission bits of [file], in octal.
  String modeOf(String file) =>
      (File(file).statSync().mode & 0x1ff).toRadixString(8);

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
    shims = Directory(path.join(root.path, 'shims'))..createSync();
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

    test('installing a changed atsc keeps the previous one as atsc.old',
        () async {
      expect((await install(['-b', prefix.path, 'sshnp'])).exitCode, 0);
      standIn(path.join(bundle.path, 'atsc'), 'atsc 2');

      final result = await install(['-b', prefix.path, 'sshnp']);

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(await output(path.join(prefix.path, 'atsc')), 'atsc 2\n');
      expect(await output(path.join(prefix.path, 'atsc.old')), 'atsc 1\n');
    });

    test('installing an unchanged atsc again leaves it and atsc.old alone',
        () async {
      expect((await install(['-b', prefix.path, 'npt'])).exitCode, 0);
      standIn(path.join(bundle.path, 'atsc'), 'atsc 2');
      expect((await install(['-b', prefix.path, 'npt'])).exitCode, 0);

      final again = await install(['-b', prefix.path, 'npt']);

      expect(again.exitCode, 0, reason: '${again.stdout}${again.stderr}');
      expect(again.stderr, isEmpty);
      expect(
        again.stdout,
        contains('=> ${prefix.path}/atsc is already up to date'),
      );
      expect(await output(path.join(prefix.path, 'atsc')), 'atsc 2\n');
      expect(await output(path.join(prefix.path, 'atsc.old')), 'atsc 1\n');
    });

    test(
        'every file it installs can be read and run by everyone, whatever '
        'the umask', () async {
      final List<String> files = ['atsc', 'srv', 'sshnpd']
          .map((name) => path.join(prefix.path, name))
          .toList();

      final first = await install(['-b', prefix.path, 'sshnpd'], umask: '027');

      expect(first.exitCode, 0, reason: '${first.stdout}${first.stderr}');
      for (final String file in files) {
        expect(modeOf(file), '755', reason: file);
        expect(Process.runSync('chmod', ['750', file]).exitCode, 0);
      }

      final again = await install(['-b', prefix.path, 'sshnpd'], umask: '027');

      expect(again.exitCode, 0, reason: '${again.stdout}${again.stderr}');
      for (final String file in files) {
        expect(modeOf(file), '755', reason: '$file, already up to date');
      }
    });

    test(
        'a root install leaves each program readable and runnable by the '
        'user it links it for', () async {
      final String links = path.join(home.path, '.local', 'bin');

      final result = await installAsRoot(['sshnpd'], umask: '027');

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      for (final String name in ['atsc', 'srv', 'sshnpd']) {
        final String file = path.join(prefix.path, name);
        expect(modeOf(file), '755', reason: name);
        expect(Link(path.join(links, name)).targetSync(), file, reason: name);
      }
      expect(
        await output(path.join(links, 'sshnpd'), ['-x']),
        'atsc 1\n[sshnpd]\n[-x]\n',
      );
    });

    test(
        'a failed copy of atsc leaves the installed one in place, installs '
        'no program and fails', () async {
      expect((await install(['-b', prefix.path, 'atsc'])).exitCode, 0);
      final String newAtsc = path.join(bundle.path, 'atsc');
      standIn(newAtsc, 'atsc 2');
      expect(Process.runSync('chmod', ['000', newAtsc]).exitCode, 0);

      final result = await install(['-b', prefix.path, 'npt']);

      expect(result.exitCode, isNot(0));
      expect(
        result.stdout,
        contains('Failed to copy $newAtsc to ${prefix.path} - aborting, '
            '${prefix.path}/atsc is unchanged\n'),
      );
      expect(namesIn(prefix.path), ['atsc']);
      expect(await output(path.join(prefix.path, 'atsc')), 'atsc 1\n');
    });

    test('a failed rename leaves the installed atsc in place and fails',
        () async {
      expect((await install(['-b', prefix.path, 'npt'])).exitCode, 0);
      standIn(path.join(bundle.path, 'atsc'), 'atsc 2');
      shim(
        'mv',
        'for a in "\$@"; do last=\$a; done\n'
            'case \$last in */atsc) exit 1 ;; esac\n'
            'for d in /bin /usr/bin; do\n'
            '  if [ -x "\$d/mv" ]; then exec "\$d/mv" "\$@"; fi\n'
            'done\n'
            'exit 127\n',
      );

      final result = await install(['-b', prefix.path, 'npt']);

      expect(result.exitCode, isNot(0));
      expect(
        result.stdout,
        contains(' - aborting, ${prefix.path}/atsc is unchanged\n'),
      );
      expect(await output(path.join(prefix.path, 'atsc')), 'atsc 1\n');
      expect(namesIn(prefix.path), ['atsc', 'atsc.old', 'npt', 'srv']);
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
