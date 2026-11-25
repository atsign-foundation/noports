@TestOn('!windows')
library;

import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  final bool isRoot =
      Process.runSync('id', ['-u']).stdout.toString().trim() == '0';
  final String script = path.join('bundles', 'universal.sh');

  /// Whether the shell function [function] in universal.sh succeeds here.
  bool universalSays(String function) {
    final result = Process.runSync('/bin/sh', [
      '-c',
      r'f=$(sed -n "/^$1() {/,/^}/p" "$2"); eval "$f"; '
          r'command -v "$1" > /dev/null || exit 99; "$1"',
      'sh',
      function,
      script,
    ]);
    if (result.exitCode == 99) {
      throw StateError('universal.sh has no function $function');
    }
    return result.exitCode == 0;
  }

  final bool inContainer = universalSays('is_container');
  final bool hasSystemd = universalSays('is_systemd_available');

  late Directory root;
  late Directory home;
  late Directory alice;
  late Directory shims;
  late Directory tools;
  late File calls;
  late String archive;

  /// Makes [file] executable.
  void executable(String file) {
    final result = Process.runSync('chmod', ['+x', file]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
  }

  /// Writes an `sh` script called [name], with [body], into the directory
  /// that universal.sh finds first on its PATH.
  void shim(String name, String body) {
    final String file = path.join(shims.path, name);
    File(file).writeAsStringSync('#!/bin/sh\n$body');
    executable(file);
  }

  /// A line of `sh` which appends [name] and the arguments of the script it
  /// is in to [calls].
  String record(String name) => 'echo "$name \$*" >> \'${calls.path}\'\n';

  /// The commands the shims were run with, in order.
  List<String> callsMade() => calls.existsSync() ? calls.readAsLinesSync() : [];

  /// Where [command] is on the PATH of this process.
  String which(String command) =>
      Process.runSync('/bin/sh', ['-c', 'command -v "\$1"', 'sh', command])
          .stdout
          .toString()
          .trim();

  /// Runs universal.sh with [args] and no input, as a user whose home is
  /// [home], with the shims and then [tools] as its whole PATH. A [sudoUser]
  /// is the account sudo was run from.
  Future<ProcessResult> universal(List<String> args, {String? sudoUser}) =>
      Process.run(
        '/bin/sh',
        ['-c', 'exec /bin/sh "\$@" < /dev/null', 'sh', script, ...args],
        environment: {
          'HOME': home.path,
          'USER': 'tester',
          'PATH': '${shims.path}:${tools.path}',
          if (sudoUser != null) 'SUDO_USER': sudoUser,
        },
        includeParentEnvironment: false,
      );

  /// Each path under [dir], relative to it, with its type, permissions,
  /// modification time and, for a file, its contents.
  Map<String, String> snapshot(Directory dir) => {
        for (final FileSystemEntity entity in [
          dir,
          ...dir.listSync(recursive: true, followLinks: false),
        ])
          path.relative(entity.path, from: dir.path): [
            entity.statSync().type,
            entity.statSync().modeString(),
            entity.statSync().modified.microsecondsSinceEpoch,
            if (entity is File) entity.readAsStringSync(),
          ].join(' '),
      };

  setUp(() {
    root = Directory(
      Directory.systemTemp
          .createTempSync('universal_sh_test')
          .resolveSymbolicLinksSync(),
    );
    addTearDown(() => root.deleteSync(recursive: true));
    home = Directory(path.join(root.path, 'home'))..createSync();
    alice = Directory(path.join(root.path, 'alice'))..createSync();
    shims = Directory(path.join(root.path, 'shims'))..createSync();
    tools = Directory(path.join(root.path, 'tools'))..createSync();
    calls = File(path.join(root.path, 'calls'));

    final String installer = path.join(root.path, 'archive', 'sshnp');
    Directory(installer).createSync(recursive: true);
    File(path.join(installer, 'install.sh'))
        .writeAsStringSync('#!/bin/sh\n${record('install.sh')}');
    executable(path.join(installer, 'install.sh'));
    archive = path.join(root.path, 'sshnp.tgz');
    final tar = Process.runSync('tar', [
      '-czf',
      archive,
      '-C',
      path.join(root.path, 'archive'),
      'sshnp',
    ]);
    expect(tar.exitCode, 0, reason: '${tar.stderr}');

    for (final String name in [
      'basename', 'cat', 'chmod', 'chown', 'cp', 'cut', 'date', 'dirname', //
      'find', 'grep', 'gzip', 'head', 'id', 'ls', 'mkdir', 'mv', 'readlink',
      'sed', 'seq', 'sleep', 'sort', 'tail', 'touch', 'tr', 'wc',
    ]) {
      final String found = which(name);
      if (found.isNotEmpty) {
        Link(path.join(tools.path, name)).createSync(found);
      }
    }
    shim(
      'rm',
      'for a in "\$@"; do\n'
          '  case "\$a" in\n'
          "  -* | '${root.path}'/* | /tmp/sshnp-*) ;;\n"
          '  *) ${record('rm refused')}exit 1 ;;\n'
          '  esac\n'
          'done\n'
          "exec '${which('rm')}' \"\$@\"\n",
    );
    shim('tar', "${record('tar')}exec '${which('tar')}' \"\$@\"\n");
    shim('uname', 'if [ "\$1" = -m ]; then echo x86_64; else echo Linux; fi\n');
    shim(
      'sudo',
      '${record('sudo')}'
          'if [ "\$1 \$2 \$3 \$4 \$5" = "-u alice sh -c echo \\\$HOME" ]; then\n'
          "  echo '${alice.path}'\n"
          '  exit 0\n'
          'fi\n'
          'exit 1\n',
    );
    for (final String name in ['crontab', 'tmux', 'systemctl']) {
      shim(name, '${record(name)}exit 1\n');
    }
  });

  group('universal.sh', () {
    group('Given universal.sh runs as root', () {
      test(
          'when a device install would use headless or tmux, then it refuses '
          'before installing anything and says to run it without sudo',
          () async {
        final List<String> device = [
          ...['--local', archive, '-t', 'device'],
          ...['-c', '@a', '-d', '@b', '-n', 'dev1'],
        ];
        final control = await universal([...device, '--dt', 'headless']);
        expect(control.exitCode, isNot(0));
        expect(
          callsMade(),
          containsAllInOrder([
            startsWith('tar -zxf /tmp/sshnp-'),
            'install.sh -b ${path.join(home.path, '.local', 'bin')} -u tester '
                'at_activate',
          ]),
          reason: 'as a regular user it installs: ${control.stderr}',
        );
        calls.deleteSync();
        shim(
          'id',
          'if [ "\$1" = -u ]; then echo 0; else exec \'${which('id')}\' "\$@"; '
              'fi\n',
        );
        final aliceBefore = snapshot(alice);
        final homeBefore = snapshot(home);

        for (final String? sudoUser in ['alice']) {
          for (final (List<String> chosen, String type) in [
            (['--dt', 'headless'], 'headless'),
            (['--dt', 'tmux'], 'tmux'),
            // NOTE as root universal.sh picks systemd where systemd is running.
            if (!hasSystemd) (<String>[], 'tmux'),
          ]) {
            final String reason = '$chosen, sudo user $sudoUser';
            final result =
                await universal([...device, ...chosen], sudoUser: sudoUser);

            expect(result.exitCode, 1, reason: reason);
            expect(
              result.stderr,
              contains('Error: a $type device installation runs as the user '
                  'who will run the daemon.\n'
                  'Run this script again as that user, not as root and '
                  'without sudo.\n'),
              reason: reason,
            );
            expect(
              result.stdout,
              isNot(contains('Using local archive')),
              reason: reason,
            );
            expect(
              callsMade(),
              [if (sudoUser != null) 'sudo -u alice sh -c echo \$HOME'],
              reason: reason,
            );
            if (calls.existsSync()) calls.deleteSync();
          }
        }

        expect(snapshot(alice), aliceBefore);
        expect(snapshot(home), homeBefore);
      });
    }, skip: inContainer ? 'universal.sh refuses device installs here' : false);
  }, skip: isRoot ? 'universal.sh installs as root' : false);
}
