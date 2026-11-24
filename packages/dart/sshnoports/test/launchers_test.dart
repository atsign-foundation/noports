/// Catalogue: features/atsc/atsc.feature
@TestOn('!windows')
library;

import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import 'subcommands.dart';

void main() {
  final String launchers = path.absolute('launchers');

  late Directory root;

  setUp(() {
    root = Directory(
      Directory.systemTemp
          .createTempSync('launchers_test')
          .resolveSymbolicLinksSync(),
    );
    addTearDown(() => root.deleteSync(recursive: true));
  });

  /// The directory [relative] under the test's root, created if absent.
  Directory dir(String relative) =>
      Directory(path.join(root.path, relative))..createSync(recursive: true);

  /// Makes [file] executable.
  void executable(String file) {
    final result = Process.runSync('chmod', ['+x', file]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
  }

  /// Writes a stand-in for atsc called [name] into [where], which prints
  /// [label] and then each argument it was given, one per line in brackets.
  String standIn(Directory where, String label, {String name = 'atsc'}) {
    final file = path.join(where.path, name);
    File(file).writeAsStringSync(
      '#!/bin/sh\n'
      "echo '$label'\n"
      'for a in "\$@"; do printf \'[%s]\\n\' "\$a"; done\n',
    );
    executable(file);
    return file;
  }

  /// Copies the launcher [launcher] into [where] as [name].
  String install(Directory where, String launcher, {String? name}) {
    final file = path.join(where.path, name ?? path.basename(launcher));
    File(path.join(launchers, launcher)).copySync(file);
    executable(file);
    return file;
  }

  /// The PATH of this process with [first] in front of it.
  Map<String, String> pathWith(Directory first) => {
        'PATH': '${first.path}:${Platform.environment['PATH']}',
      };

  test('the old names are exactly the subcommands of atsc', () {
    final List<String> names = Directory(launchers)
        .listSync()
        .whereType<File>()
        .map((f) => path.basename(f.path))
        .toList()
      ..sort();

    expect(names, [...subcommands]..sort());
  });

  test('the old names differ only in their own name, so npt stands for all',
      () {
    final String npt = File(path.join(launchers, 'npt')).readAsStringSync();
    for (final String name in subcommands) {
      final String launcher =
          File(path.join(launchers, name)).readAsStringSync();

      expect(launcher.replaceAll(name, 'npt'), npt, reason: name);
    }
  });

  test('each old name runs atsc with its own name', () async {
    final installation = dir('opt/a');
    standIn(installation, 'atsc in /opt/a');
    for (final String name in subcommands) {
      final result = await Process.run(install(installation, name), []);

      expect(result.stdout, 'atsc in /opt/a\n[$name]\n', reason: name);
    }
  });

  test('an old name passes every argument through unchanged', () async {
    final installation = dir('opt/a');
    standIn(installation, 'atsc in /opt/a');

    final result = await Process.run(install(installation, 'npt'), [
      '-d',
      'my device',
      '',
      '--key=a b',
      '-',
    ]);

    expect(
      result.stdout,
      'atsc in /opt/a\n[npt]\n[-d]\n[my device]\n[]\n[--key=a b]\n[-]\n',
    );
    expect(result.exitCode, 0);
  });

  test('a signal sent to an old name reaches the program', () async {
    final installation = dir('opt/a');
    final String pidFile = path.join(root.path, 'pid');
    final String received = path.join(root.path, 'received');
    final String atsc = path.join(installation.path, 'atsc');
    File(atsc).writeAsStringSync(
      '#!/bin/sh\n'
      "trap 'echo TERM > \"$received\"; kill \$child; exit 143' TERM\n"
      'echo \$\$ > "$pidFile"\n'
      'while :; do sleep 1 & child=\$!; wait \$child; done\n',
    );
    executable(atsc);
    final process = await Process.start(install(installation, 'sshnpd'), []);
    addTearDown(() => process.kill(ProcessSignal.sigkill));
    String pid = '';
    for (int i = 0; i < 200 && !pid.endsWith('\n'); i++) {
      await Future.delayed(Duration(milliseconds: 50));
      if (File(pidFile).existsSync()) pid = File(pidFile).readAsStringSync();
    }

    expect(int.parse(pid.trim()), process.pid);
    final String running = Process.runSync('ps', [
      '-o',
      'args=',
      '-p',
      '${process.pid}',
    ]).stdout.toString();
    expect(running, contains('$atsc sshnpd'));

    process.kill(ProcessSignal.sigterm);
    expect(await process.exitCode, 143);
    expect(File(received).readAsStringSync(), 'TERM\n');
  });

  group('an old name runs the atsc in its own installation', () {
    late Directory installation;
    late Directory elsewhere;

    setUp(() {
      installation = dir('opt/a');
      standIn(installation, 'atsc in /opt/a');
      install(installation, 'npt');
      elsewhere = dir('elsewhere');
      standIn(elsewhere, 'atsc elsewhere');
    });

    test('never one first on the PATH or in the current directory', () async {
      final control = await Process.run(
          '/bin/sh',
          [
            '-c',
            'atsc',
          ],
          environment: pathWith(elsewhere));
      expect(control.stdout, 'atsc elsewhere\n');

      final result = await Process.run(
        path.join(installation.path, 'npt'),
        ['--help'],
        environment: pathWith(elsewhere),
        workingDirectory: elsewhere.path,
      );

      expect(result.stdout, 'atsc in /opt/a\n[npt]\n[--help]\n');
    });

    test('when it is reached through symbolic links', () async {
      final links = dir('home/.local/bin');
      standIn(links, 'atsc beside the link');
      final String target = path.join(installation.path, 'npt');
      Link(path.join(links.path, 'npt')).createSync(target);
      Link(
        path.join(links.path, 'relative'),
      ).createSync(path.relative(target, from: links.path));
      Link(path.join(links.path, 'chained')).createSync('relative');

      for (final String link in ['npt', 'relative', 'chained']) {
        final result = await Process.run(path.join(links.path, link), []);

        expect(result.stdout, 'atsc in /opt/a\n[npt]\n', reason: link);
      }
    });

    test('and refuses to guess when it is run without a path', () async {
      install(elsewhere, 'npt');

      final result = await Process.run(
          '/bin/sh',
          [
            'npt',
          ],
          workingDirectory: elsewhere.path);

      expect(result.stdout, isEmpty);
      expect(result.stderr, contains('run npt by its path'));
      expect(result.exitCode, 127);
    });

    test('and stops with an error when atsc is not beside it', () async {
      final String alone = install(dir('alone'), 'npt');

      final result = await Process.run(alone, []);

      expect(result.stdout, isEmpty);
      expect(
        result.stderr,
        'npt: cannot find atsc beside ${path.dirname(alone)}; '
        'keep atsc, srv and the programs together\n',
      );
      expect(result.exitCode, 127);
    });

    test('and stops with an error when it cannot follow a link to it',
        () async {
      final links = dir('home/.local/bin');
      standIn(links, 'atsc beside the link');
      final String link = path.join(links.path, 'npt');
      Link(link).createSync(path.join(installation.path, 'npt'));
      final noReadlink = dir('no_readlink');

      final result = await Process.run(
        link,
        [],
        environment: {'PATH': noReadlink.path},
        includeParentEnvironment: false,
      );

      expect(result.stdout, isEmpty);
      expect(
        result.stderr,
        endsWith('$link: cannot follow the symbolic link $link\n'),
      );
      expect(result.exitCode, 127);
    });

    test('and stops with an error on a loop of symbolic links', () async {
      final links = dir('loop');
      standIn(links, 'atsc beside the loop');
      final String a = path.join(links.path, 'a');
      Link(a).createSync('b');
      Link(path.join(links.path, 'b')).createSync('a');

      // NOTE: the kernel will not run a loop, so the script is sourced with
      // the loop as its \$0.
      final process = await Process.start('/bin/sh', [
        '-c',
        '. "\$1"',
        a,
        path.join(installation.path, 'npt'),
      ]);
      addTearDown(() => process.kill(ProcessSignal.sigkill));
      final stdout = process.stdout.transform(systemEncoding.decoder).join();
      final stderr = process.stderr.transform(systemEncoding.decoder).join();
      final int exitCode = await process.exitCode.timeout(
        Duration(seconds: 20),
        onTimeout: () => fail('the launcher is still following the loop'),
      );

      expect(await stdout, isEmpty);
      expect(await stderr, '$a: too many symbolic links\n');
      expect(exitCode, 127);
    });
  });

  group('the debug srvd runs the debug build of atsc', () {
    test('when installed as debug_srvd beside the production atsc', () async {
      final bin = dir('usr/local/bin');
      standIn(bin, 'production atsc');
      standIn(bin, 'debug atsc', name: 'debug_atsc');
      final String debugSrvd = install(bin, 'debug/srvd', name: 'debug_srvd');
      final onPath = dir('on_path');
      standIn(onPath, 'atsc on the PATH');
      standIn(onPath, 'debug atsc on the PATH', name: 'debug_atsc');
      final links = dir('home/.local/bin');
      Link(path.join(links.path, 'debug_srvd')).createSync(debugSrvd);

      for (final String run in [
        debugSrvd,
        path.join(links.path, 'debug_srvd')
      ]) {
        final result = await Process.run(
            run,
            [
              '--help',
            ],
            environment: pathWith(onPath));

        expect(result.stdout, 'debug atsc\n[srvd]\n[--help]\n', reason: run);
      }
    });

    test('in the debug directory of an archive', () async {
      final archive = dir('sshnp');
      standIn(archive, 'production atsc');
      final debug = dir('sshnp/debug');
      standIn(debug, 'debug atsc');

      final result = await Process.run(install(debug, 'debug/srvd'), []);

      expect(result.stdout, 'debug atsc\n[srvd]\n');
    });

    test('and fails rather than run the production atsc', () async {
      final bin = dir('usr/local/bin');
      standIn(bin, 'production atsc');

      final result = await Process.run(
        install(bin, 'debug/srvd', name: 'debug_srvd'),
        [],
      );

      expect(result.stdout, isEmpty);
      expect(
        result.stderr,
        'debug_srvd: cannot find debug_atsc beside ${bin.path}; '
        'keep debug_atsc, srv and the programs together\n',
      );
      expect(result.exitCode, 127);
    });

    test('and stops with an error when it cannot follow a link to it',
        () async {
      final bin = dir('usr/local/bin');
      standIn(bin, 'debug atsc', name: 'debug_atsc');
      final String debugSrvd = install(bin, 'debug/srvd', name: 'debug_srvd');
      final links = dir('home/.local/bin');
      standIn(links, 'debug atsc beside the link', name: 'debug_atsc');
      final String link = path.join(links.path, 'debug_srvd');
      Link(link).createSync(debugSrvd);
      final noReadlink = dir('no_readlink');

      final result = await Process.run(
        link,
        [],
        environment: {'PATH': noReadlink.path},
        includeParentEnvironment: false,
      );

      expect(result.stdout, isEmpty);
      expect(
        result.stderr,
        endsWith('$link: cannot follow the symbolic link $link\n'),
      );
      expect(result.exitCode, 127);
    });
  });
}
