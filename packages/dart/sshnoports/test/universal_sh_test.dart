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
  final bool isDebianLike = universalSays('is_debian_like');

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

        for (final String? sudoUser in ['alice', null]) {
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

    group('Given install.sh fails when universal.sh installs sshnpd', () {
      test(
          'when universal.sh makes a device install, then it prints what '
          'install.sh printed and exits non-zero', () async {
        final String installer = path.join(root.path, 'failing', 'sshnp');
        Directory(installer).createSync(recursive: true);
        File(path.join(installer, 'install.sh')).writeAsStringSync(
          '#!/bin/sh\n'
          '${record('install.sh')}'
          'case "\$*" in\n'
          "*sshnpd) echo 'install.sh stand-in: sshnpd not installed'; "
          'exit 1 ;;\n'
          'esac\n',
        );
        executable(path.join(installer, 'install.sh'));
        final String failing = path.join(root.path, 'failing.tgz');
        final tar = Process.runSync('tar', [
          '-czf',
          failing,
          '-C',
          path.join(root.path, 'failing'),
          'sshnp',
        ]);
        expect(tar.exitCode, 0, reason: '${tar.stderr}');
        final List<String> device = [
          ...['--local', failing, '-t', 'device'],
          ...['-c', '@a', '-d', '@b', '-n', 'dev1'],
        ];

        for (final (String type, bool asRoot, String call) in [
          (
            'tmux',
            false,
            'install.sh -b ${path.join(home.path, '.local', 'bin')} -u tester '
                'tmux sshnpd',
          ),
          ('systemd', true, 'install.sh -b /usr/bin -u alice sshnpd'),
        ]) {
          if (asRoot) {
            shim(
              'id',
              'if [ "\$1" = -u ]; then echo 0; else exec \'${which('id')}\' '
                  '"\$@"; fi\n',
            );
          }
          if (calls.existsSync()) calls.deleteSync();

          final result = await universal(
            [...device, '--dt', type],
            sudoUser: asRoot ? 'alice' : null,
          );

          expect(result.exitCode, isNot(0), reason: type);
          expect(
            result.stdout,
            contains('install.sh stand-in: sshnpd not installed\n'),
            reason: '$type: ${result.stdout}${result.stderr}',
          );
          expect(callsMade().last, call, reason: type);
        }
      });
    }, skip: inContainer ? 'universal.sh refuses device installs here' : false);

    group('Given an unsupported platform, or an invalid -t or --dt', () {
      test('when universal.sh runs, then it says why and exits 1', () async {
        for (final (List<String> args, String? platform, String line) in [
          (
            <String>[],
            'SunOS',
            'and provide the following information: SunOS\n',
          ),
          (['-t', 'tablet'], null, 'Valid options are: (device, client)\n'),
          (
            ['-t', 'device', '--dt', 'cron'],
            null,
            'Valid options are: (launchd, systemd, tmux, headless)\n',
          ),
        ]) {
          if (platform != null) {
            shim(
              'uname',
              'if [ "\$1" = -m ]; then echo x86_64; else echo $platform; fi\n',
            );
          }

          final result = await universal(args);

          expect(result.exitCode, 1, reason: '$args: ${result.stderr}');
          expect(result.stderr, contains(line), reason: '$args');
          expect(result.stderr, isNot(contains(' exit 1')), reason: '$args');
          shim(
            'uname',
            'if [ "\$1" = -m ]; then echo x86_64; else echo Linux; fi\n',
          );
        }
      });
    });

    group('Given universal.sh runs as root on macOS', () {
      test(
          'when it is asked to install, then it refuses before downloading '
          'anything', () async {
        shim(
          'uname',
          'if [ "\$1" = -m ]; then echo arm64; else echo Darwin; fi\n',
        );
        shim(
          'id',
          'if [ "\$1" = -u ]; then echo 0; else exec \'${which('id')}\' "\$@"; '
              'fi\n',
        );
        for (final String name in ['curl', 'wget']) {
          shim(name, '${record(name)}exit 1\n');
        }
        final aliceBefore = snapshot(alice);
        final homeBefore = snapshot(home);

        for (final String? sudoUser in ['alice', null]) {
          for (final List<String> args in [
            ['-t', 'device', '-c', '@a', '-d', '@b', '-n', 'dev1'],
            ['-t', 'client', '-c', '@a', '-d', '@b', '-r', '@rv'],
          ]) {
            final String reason = '$args, sudo user $sudoUser';
            final result = await universal(args, sudoUser: sudoUser);

            expect(result.exitCode, 1, reason: reason);
            expect(
              result.stderr,
              contains('Error: installing as root is not available on macOS.\n'
                  'Run this script again as the user who will run NoPorts, '
                  'not as root and without sudo.\n'),
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
    });

    group('Given universal.sh runs as a regular user on a host with apt', () {
      test('when a device install uses tmux, then it is not told to use sudo',
          () async {
        for (final String name in ['apt', 'apt-get', 'curl', 'wget']) {
          shim(name, '${record(name)}exit 1\n');
        }

        for (final List<String> chosen in [
          ['--dt', 'tmux'],
          // NOTE without --dt universal.sh picks tmux where systemd is not running.
          if (!hasSystemd) <String>[],
        ]) {
          final result = await universal([
            ...['-t', 'device', '-c', '@a', '-d', '@b', '-n', 'dev1'],
            ...chosen,
          ]);

          expect(result.exitCode, isNot(0), reason: '$chosen');
          expect(
            '${result.stdout}${result.stderr}',
            isNot(contains('re-run this script with sudo')),
            reason: '$chosen',
          );
          expect(
            callsMade(),
            [startsWith('curl -sSfL https://api.github.com/')],
            reason: '$chosen: it downloads the release instead of using apt',
          );
          if (calls.existsSync()) calls.deleteSync();
        }
      });
    },
        skip: inContainer
            ? 'universal.sh refuses device installs here'
            : isDebianLike
                ? false
                : 'universal.sh uses apt only on a Debian-like host');

    group(
        'Given universal.sh runs as a regular user on a host without systemd '
        'or tmux', () {
      test(
          'when crontab is on the PATH, then a device install uses a headless '
          'job', () async {
        File(path.join(shims.path, 'tmux')).deleteSync();
        shim('nohup', 'exec "\$@"\n');
        final probe = await Process.run(
          '/bin/sh',
          ['-c', 'command -v cron; command -v crontab'],
          environment: {'PATH': '${shims.path}:${tools.path}'},
          includeParentEnvironment: false,
        );
        expect(probe.stdout, '${path.join(shims.path, 'crontab')}\n');

        final result = await universal([
          ...['--local', archive, '-t', 'device'],
          ...['-c', '@a', '-d', '@b', '-n', 'dev1'],
        ]);

        expect(result.stderr, isNot(contains('crontab not available')));
        expect(
          callsMade(),
          contains(
            'install.sh -b ${path.join(home.path, '.local', 'bin')} -u tester '
            'headless sshnpd',
          ),
          reason: '${result.stdout}${result.stderr}',
        );
      });
    },
        skip: inContainer
            ? 'universal.sh refuses device installs here'
            : hasSystemd
                ? 'universal.sh suggests systemd here'
                : false);
  }, skip: isRoot ? 'universal.sh installs as root' : false);
}
