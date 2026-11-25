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
  late Directory alice;
  late Directory bob;
  late Directory prefix;
  late Directory shims;
  late File calls;
  late File crontab;

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

  /// A line of `sh` which appends [name] and the arguments of the script it
  /// is in to [calls], after the account the `sudo` shim runs it as, if any.
  String record(String name) =>
      'echo "\${SHIM_ACCOUNT:+\$SHIM_ACCOUNT: }$name \$*" >> \'${calls.path}\'\n';

  /// Writes a shim called [name] which records each call and then runs the
  /// [name] in /bin or /usr/bin.
  void passThrough(String name) => shim(
        name,
        '${record(name)}'
        'for d in /bin /usr/bin; do\n'
        '  if [ -x "\$d/$name" ]; then exec "\$d/$name" "\$@"; fi\n'
        'done\n'
        'exit 127\n',
      );

  /// The commands the shims were run with, in order.
  List<String> callsMade() => calls.existsSync() ? calls.readAsLinesSync() : [];

  /// Runs install.sh from the bundle with [args] under [umask], as a user
  /// whose home is [home], with [searchPath] as its PATH, or else the shims
  /// in front of the PATH of this process. A [sudoUser] is the account sudo
  /// was run from, and a [workingDirectory] the directory it runs in.
  Future<ProcessResult> install(
    List<String> args, {
    String umask = '022',
    String? searchPath,
    String? sudoUser,
    String? workingDirectory,
  }) =>
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
          'PATH': searchPath ?? '${shims.path}:${Platform.environment['PATH']}',
          if (sudoUser != null) 'SUDO_USER': sudoUser,
        },
        includeParentEnvironment: false,
        workingDirectory: workingDirectory,
      );

  /// Runs install.sh as root would run it on Linux, with `id`, `uname`,
  /// `chown` and `sed` shims and with its `mkdir`, `touch` and `chmod` calls
  /// recorded, into [prefix] with [args].
  Future<ProcessResult> installAsRoot(
    List<String> args, {
    String? umask,
    String? sudoUser,
  }) {
    shim('id',
        'if [ "\$1" = -u ]; then echo 0; else exec /usr/bin/id "\$@"; fi\n');
    shim('uname', 'echo Linux\n');
    shim('chown', record('chown'));
    shim(
      'sed',
      'if [ "\$1" = -i ] && [ -n "\$2" ] && [ "\$(/usr/bin/uname)" = Darwin ]; '
          'then\n'
          '  shift\n'
          '  exec /usr/bin/sed -i "" "\$@"\n'
          'fi\n'
          'for d in /bin /usr/bin; do\n'
          '  if [ -x "\$d/sed" ]; then exec "\$d/sed" "\$@"; fi\n'
          'done\n'
          'exit 127\n',
    );
    for (final String name in ['mkdir', 'touch', 'chmod']) {
      passThrough(name);
    }
    return install(
      ['-b', prefix.path, ...args],
      umask: umask ?? '022',
      sudoUser: sudoUser,
    );
  }

  /// Each path under [dir], relative to it, with its type, permissions,
  /// modification time and, for a file, its contents.
  Map<String, String> snapshot(Directory dir) => {
        for (final FileSystemEntity entity in [
          dir,
          ...dir.listSync(recursive: true, followLinks: false),
        ])
          path.relative(entity.path, from: dir.path): [
            if (entity is Link) 'link ${entity.targetSync()}',
            entity.statSync().type,
            entity.statSync().modeString(),
            entity.statSync().modified.microsecondsSinceEpoch,
            if (entity is File) entity.readAsStringSync(),
          ].join(' '),
      };

  /// The paths that [after] adds to [before], removes from it or changes.
  List<String> changes(Map<String, String> before, Map<String, String> after) =>
      {...before.keys, ...after.keys}
          .where((String key) => before[key] != after[key])
          .toList()
        ..sort();

  /// Fails unless `crontab`, `tmux` and `systemctl` are the shims on the PATH
  /// that [install] gives install.sh.
  Future<void> expectShimsFirst() async {
    final probe = await Process.run(
      '/bin/sh',
      ['-c', 'for c in crontab tmux systemctl; do command -v \$c; done'],
      environment: {'PATH': '${shims.path}:${Platform.environment['PATH']}'},
      includeParentEnvironment: false,
    );
    expect(
      probe.stdout,
      ['crontab', 'tmux', 'systemctl']
          .map((name) => '${path.join(shims.path, name)}\n')
          .join(),
    );
  }

  /// Fails unless this process is unable to write /etc/systemd/system, where
  /// install.sh writes systemd units.
  void expectSystemdUnitsUnwritable() {
    final probe = Process.runSync('/bin/sh', [
      '-c',
      'd=/etc/systemd/system; while ! [ -e "\$d" ]; do d=\$(dirname "\$d"); '
          'done; [ -w "\$d" ]',
    ]);
    expect(probe.exitCode, 1, reason: 'this process can write systemd units');
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

  /// A PATH that finds every command on the PATH of this process except
  /// [command].
  String pathWithout(String command) {
    final without = Directory(path.join(root.path, 'without_$command'))
      ..createSync();
    final Set<String> linked = {};
    for (final String dir in Platform.environment['PATH']!.split(':')) {
      final List<FileSystemEntity> entities;
      try {
        entities = Directory(dir).listSync();
      } on FileSystemException {
        continue;
      }
      for (final FileSystemEntity entity in entities) {
        final String name = path.basename(entity.path);
        if (name == command || !linked.add(name)) continue;
        Link(path.join(without.path, name)).createSync(entity.path);
      }
    }
    return without.path;
  }

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
    alice = Directory(path.join(root.path, 'alice'))..createSync();
    bob = Directory(path.join(root.path, 'bob'))..createSync();
    prefix = Directory(path.join(root.path, 'prefix'));
    shims = Directory(path.join(root.path, 'shims'))..createSync();
    calls = File(path.join(root.path, 'calls'));
    crontab = File(path.join(root.path, 'crontab'));
    File(path.join('bundles', 'shell', 'install.sh'))
        .copySync(path.join(bundle.path, 'install.sh'));
    for (final String from in ['launchers/.', 'bundles/shell/headless']) {
      final copy = Process.runSync('cp', ['-R', from, bundle.path]);
      expect(copy.exitCode, 0, reason: '${copy.stderr}');
    }
    standIn(path.join(bundle.path, 'atsc'), 'atsc 1');
    standIn(path.join(bundle.path, 'srv'), 'srv');
    standIn(path.join(bundle.path, 'debug', 'atsc'), 'debug atsc');
    shim(
      'crontab',
      '${record('crontab')}'
          'case "\$1" in\n'
          "-l) cat '${crontab.path}' 2>/dev/null ;;\n"
          "-) cat > '${crontab.path}' ;;\n"
          '*) exit 1 ;;\n'
          'esac\n',
    );
    shim('tmux', '${record('tmux')}exit 1\n');
    shim('systemctl', record('systemctl'));
    shim('pgrep', '${record('pgrep')}exit 1\n');
    shim(
      'sudo',
      '${record('sudo')}'
          'set_home=false\n'
          'if [ "\$1" = -H ]; then set_home=true; shift; fi\n'
          'case "\$1 \$2" in\n'
          "'-u alice') home='${alice.path}' ;;\n"
          "'-u bob') home='${bob.path}' ;;\n"
          '*) exit 1 ;;\n'
          'esac\n'
          'if \$set_home; then HOME=\$home; fi\n'
          'SHIM_ACCOUNT=\$2\n'
          'export HOME SHIM_ACCOUNT\n'
          'shift 2\n'
          'umask 0002\n'
          'exec "\$@"\n',
    );
  });

  group('install.sh', () {
    group('Given a non-root install into a directory chosen with -b', () {
      test(
          'when it installs npt, then it links nothing into ~/.local/bin and '
          'leaves ~/.profile alone', () async {
        final result = await install(['-b', prefix.path, 'npt']);

        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        expect(namesIn(prefix.path), ['atsc', 'npt', 'srv']);
        expect(namesIn(path.join(home.path, '.local', 'bin')), isEmpty);
        expect(File(path.join(home.path, '.profile')).existsSync(), isFalse);
      });

      test('when it installs atsc alone, then it installs only atsc', () async {
        final result = await install(['-b', prefix.path, 'atsc']);

        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        expect(namesIn(prefix.path), ['atsc']);
      });

      test(
          'when it installs a program, then it also installs the atsc the '
          'program runs, and srv when the program needs one', () async {
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
          'when it installs debug_srvd, then it installs debug_atsc with it in '
          'that directory', () async {
        final result = await install(['-b', prefix.path, 'debug_srvd']);

        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        expect(namesIn(prefix.path), ['debug_atsc', 'debug_srvd']);
        final run = await Process.run(path.join(prefix.path, 'debug_srvd'), []);
        expect(run.stdout, 'debug atsc\n[srvd]\n');
      });
    });

    group('Given atsc is already installed in the chosen directory', () {
      test(
          'when a changed atsc is installed, then the previous one is kept as '
          'atsc.old', () async {
        expect((await install(['-b', prefix.path, 'sshnp'])).exitCode, 0);
        standIn(path.join(bundle.path, 'atsc'), 'atsc 2');

        final result = await install(['-b', prefix.path, 'sshnp']);

        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        expect(await output(path.join(prefix.path, 'atsc')), 'atsc 2\n');
        expect(await output(path.join(prefix.path, 'atsc.old')), 'atsc 1\n');
      });

      for (final bool withCmp in [true, false]) {
        test(
            'when the same atsc is installed again'
            '${withCmp ? '' : ' without cmp'}, then it and atsc.old are '
            'left alone', () async {
          String? searchPath;
          if (!withCmp) {
            searchPath = pathWithout('cmp');
            final probe = await Process.run(
              '/bin/sh',
              ['-c', 'command -v cksum; command -v cmp'],
              environment: {'PATH': searchPath},
              includeParentEnvironment: false,
            );
            expect(probe.stdout, '$searchPath/cksum\n');
            expect(probe.exitCode, isNot(0));
          }
          final first =
              await install(['-b', prefix.path, 'npt'], searchPath: searchPath);
          expect(first.exitCode, 0);
          expect(first.stderr, isEmpty);
          standIn(path.join(bundle.path, 'atsc'), 'atsc 2');
          final changed =
              await install(['-b', prefix.path, 'npt'], searchPath: searchPath);
          expect(changed.exitCode, 0);
          expect(changed.stderr, isEmpty);

          final again =
              await install(['-b', prefix.path, 'npt'], searchPath: searchPath);

          expect(again.exitCode, 0, reason: '${again.stdout}${again.stderr}');
          expect(again.stderr, isEmpty);
          expect(
            again.stdout,
            contains('=> ${prefix.path}/atsc is already up to date'),
          );
          expect(await output(path.join(prefix.path, 'atsc')), 'atsc 2\n');
          expect(await output(path.join(prefix.path, 'atsc.old')), 'atsc 1\n');
        });
      }

      for (final bool partWay in [false, true]) {
        test(
            'when copying a new atsc fails${partWay ? ' part way' : ''}, then '
            'the installed one stays, no program is installed and install.sh '
            'fails', () async {
          expect((await install(['-b', prefix.path, 'atsc'])).exitCode, 0);
          final String newAtsc = path.join(bundle.path, 'atsc');
          standIn(newAtsc, 'atsc 2');
          if (partWay) {
            shim(
              'cp',
              'for a in "\$@"; do last=\$a; done\n'
                  'case \$last in */.atsc.new.*) echo part > "\$last"; '
                  'exit 1 ;; esac\n'
                  'for d in /bin /usr/bin; do\n'
                  '  if [ -x "\$d/cp" ]; then exec "\$d/cp" "\$@"; fi\n'
                  'done\n'
                  'exit 127\n',
            );
          } else {
            expect(Process.runSync('chmod', ['000', newAtsc]).exitCode, 0);
          }

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
      }

      test(
          'when renaming a new atsc into place fails, then the installed one '
          'stays and install.sh fails', () async {
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
    });

    group('Given any umask', () {
      test(
          'when install.sh installs a program, or installs it again, then '
          'every file it installs can be read and run by everyone', () async {
        final List<String> files = ['atsc', 'srv', 'sshnpd']
            .map((name) => path.join(prefix.path, name))
            .toList();

        final first =
            await install(['-b', prefix.path, 'sshnpd'], umask: '027');

        expect(first.exitCode, 0, reason: '${first.stdout}${first.stderr}');
        for (final String file in files) {
          expect(modeOf(file), '755', reason: file);
          expect(Process.runSync('chmod', ['750', file]).exitCode, 0);
        }

        final again =
            await install(['-b', prefix.path, 'sshnpd'], umask: '027');

        expect(again.exitCode, 0, reason: '${again.stdout}${again.stderr}');
        for (final String file in files) {
          expect(modeOf(file), '755', reason: '$file, already up to date');
        }
      });
    });

    group('Given install.sh runs as root through sudo from the account alice',
        () {
      test(
          'when it installs npt, then atsc, srv and npt are in /usr/local/bin '
          "and nothing in alice's home is created or changed", () async {
        File(path.join(alice.path, '.profile'))
            .writeAsStringSync('umask 022\n');
        final aliceBefore = snapshot(alice);
        final homeBefore = snapshot(home);

        final result =
            await installAsRoot(['npt'], umask: '027', sudoUser: 'alice');

        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        expect(callsMade(), contains('sudo -H -u alice sh -c echo \$HOME'));
        expect(namesIn(prefix.path), ['atsc', 'npt', 'srv']);
        for (final String name in ['atsc', 'srv', 'npt']) {
          final String file = path.join(prefix.path, name);
          expect(modeOf(file), '755', reason: name);
          expect(
            callsMade(),
            contains(allOf(startsWith('chown -h root'), endsWith(' $file'))),
            reason: name,
          );
        }
        expect(
          await output(path.join(prefix.path, 'npt'), ['-x']),
          'atsc 1\n[npt]\n[-x]\n',
        );
        expect(changes(aliceBefore, snapshot(alice)), isEmpty);
        expect(changes(homeBefore, snapshot(home)), isEmpty);
      });
    });

    group('Given install.sh runs as root', () {
      test(
          'when it installs the sshnpd systemd unit for alice, then the only '
          "thing it writes in alice's home is ~/.ssh/authorized_keys, owned by "
          'alice', () async {
        expectSystemdUnitsUnwritable();
        final String keys = path.join(alice.path, '.ssh', 'authorized_keys');
        final aliceBefore = snapshot(alice);
        final homeBefore = snapshot(home);

        final result =
            await installAsRoot(['systemd', 'sshnpd'], sudoUser: 'alice');

        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        expect(callsMade(), contains('systemctl daemon-reload'));
        expect(
          changes(aliceBefore, snapshot(alice)),
          ['.', '.ssh', path.join('.ssh', 'authorized_keys')],
        );
        expect(File(keys).existsSync(), isTrue);
        expect(callsMade(), contains('alice: touch $keys'));
        expect(changes(homeBefore, snapshot(home)), isEmpty);
      });
    });

    group(
        'Given install.sh runs as root for another account, through sudo or '
        'with -u', () {
      test(
          'when it is asked to install a headless or tmux job, then it refuses '
          'before changing anything and says to run it without sudo, as the '
          'user who will run the daemon', () async {
        await expectShimsFirst();
        final aliceBefore = snapshot(alice);
        final bobBefore = snapshot(bob);
        final homeBefore = snapshot(home);

        for (final (String? sudoUser, List<String> args, String refused) in [
          for (final String kind in ['headless', 'tmux'])
            for (final String job in ['sshnpd', 'srvd'])
              ('alice', [kind, job], '$kind $job'),
          ('alice', ['npt', 'headless', 'sshnpd'], 'headless sshnpd'),
          (null, ['-u', 'bob', 'headless', 'sshnpd'], 'headless sshnpd'),
          (null, ['-u', 'bob', 'tmux', 'srvd'], 'tmux srvd'),
          ('alice', ['-u', 'bob', 'tmux', 'sshnpd'], 'tmux sshnpd'),
        ]) {
          final String reason = '$args, sudo user $sudoUser';
          final result = await installAsRoot(args, sudoUser: sudoUser);

          expect(result.exitCode, 1, reason: reason);
          expect(
            result.stdout,
            'Error: run install.sh $refused without sudo, as the user who '
            'will run the daemon\n',
            reason: reason,
          );
          expect(prefix.existsSync(), isFalse, reason: reason);
        }

        expect(callsMade(), everyElement(endsWith(' sh -c echo \$HOME')));
        expect(crontab.existsSync(), isFalse);
        expect(changes(aliceBefore, snapshot(alice)), isEmpty);
        expect(changes(bobBefore, snapshot(bob)), isEmpty);
        expect(changes(homeBefore, snapshot(home)), isEmpty);
      });
    });

    group('Given install.sh runs as root from a root login without -u', () {
      test(
          "when it installs a headless job, then the job is in root's crontab "
          "and runs from root's home", () async {
        await expectShimsFirst();
        final String logs = path.join(home.path, '.sshnpd', 'logs');
        final String job = path.join(home.path, '.local', 'bin', 'sshnpd.sh');

        final result = await installAsRoot(['headless', 'sshnpd']);

        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        expect(
          callsMade().where((String call) => call.startsWith(
                RegExp('(sudo|crontab) '),
              )),
          ['crontab -l', 'crontab -'],
          reason: 'root installs the job in its own crontab, without sudo',
        );
        expect(
          crontab.readAsStringSync(),
          '\n@reboot nohup $job > $logs/sshnpd.log 2> $logs/sshnpd.err\n',
        );
        expect(
          File(job).readAsLinesSync(),
          contains('binary_path="${prefix.path}"'),
        );
        expect(File(path.join(prefix.path, 'sshnpd')).existsSync(), isTrue);
      });
    });

    group('Given install.sh runs as root with -u bob', () {
      test(
          "when it installs the sshnpd systemd unit, then it sets up bob's "
          '~/.ssh/authorized_keys', () async {
        expectSystemdUnitsUnwritable();
        final String keys = path.join(bob.path, '.ssh', 'authorized_keys');
        final aliceBefore = snapshot(alice);
        final homeBefore = snapshot(home);

        final result = await installAsRoot(
          ['-u', 'bob', 'systemd', 'sshnpd'],
          sudoUser: 'alice',
        );

        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        expect(File(keys).existsSync(), isTrue);
        expect(modeOf(keys), '644');
        expect(changes(aliceBefore, snapshot(alice)), isEmpty);
        expect(changes(homeBefore, snapshot(home)), isEmpty);
      });
    });

    group('Given install.sh runs as root with -u naming another account', () {
      test(
          'when it installs the sshnpd systemd unit, then that account\'s '
          '~/.ssh/authorized_keys is created by that account', () async {
        expectSystemdUnitsUnwritable();
        final String keys = path.join(bob.path, '.ssh', 'authorized_keys');

        final result = await installAsRoot(
          ['-u', 'bob', 'systemd', 'sshnpd'],
          umask: '077',
          sudoUser: 'alice',
        );

        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        expect(
          callsMade().where((String call) => call.contains(bob.path)),
          [
            'bob: mkdir -p ${path.dirname(keys)}',
            'bob: touch $keys',
            'bob: chmod 644 $keys',
          ],
          reason: "each step in bob's home runs as bob, through sudo -u bob",
        );
        expect(modeOf(keys), '644');
      });

      test(
          'when it installs the sshnpd systemd unit, then nothing in the '
          "invoking user's home is created or changed", () async {
        expectSystemdUnitsUnwritable();
        final aliceKeys = File(path.join(alice.path, '.ssh', 'authorized_keys'))
          ..createSync(recursive: true)
          ..writeAsStringSync('ssh-ed25519 AAAA alice\n');
        expect(Process.runSync('chmod', ['600', aliceKeys.path]).exitCode, 0);
        final aliceBefore = snapshot(alice);
        final homeBefore = snapshot(home);

        final result = await installAsRoot(
          ['-u', 'bob', 'systemd', 'sshnpd'],
          sudoUser: 'alice',
        );

        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        expect(
          callsMade().where(
            (String call) =>
                call.contains(alice.path) || call.contains(home.path),
          ),
          isEmpty,
          reason: "nothing runs on the invoking user's paths",
        );
        expect(changes(aliceBefore, snapshot(alice)), isEmpty);
        expect(changes(homeBefore, snapshot(home)), isEmpty);
      });

      test(
          "when it creates that account's ~/.ssh, then the directory gets the "
          "mode root's umask gives it", () async {
        expectSystemdUnitsUnwritable();
        final dir = Directory(path.join(bob.path, '.ssh'));

        for (final (String umask, String mode) in [
          ('022', '755'),
          ('077', '700'),
        ]) {
          if (dir.existsSync()) dir.deleteSync(recursive: true);

          final result = await installAsRoot(
            ['-u', 'bob', 'systemd', 'sshnpd'],
            umask: umask,
            sudoUser: 'alice',
          );

          expect(
            result.exitCode,
            0,
            reason: '$umask: ${result.stdout}${result.stderr}',
          );
          expect(
            modeOf(dir.path),
            mode,
            reason: "~/.ssh gets the mode root's umask $umask gives it",
          );
        }
      });
    });

    group('Given install.sh runs as root with no sudo user', () {
      test(
          'when it installs the sshnpd systemd unit, then it sets up root\'s '
          '~/.ssh/authorized_keys without sudo', () async {
        expectSystemdUnitsUnwritable();
        final String keys = path.join(home.path, '.ssh', 'authorized_keys');

        final result = await installAsRoot(['systemd', 'sshnpd']);

        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        expect(
          callsMade().where((String call) => call.startsWith('sudo')),
          isEmpty,
          reason: "root's own steps run without sudo",
        );
        expect(callsMade(), contains('touch $keys'));
        expect(modeOf(keys), '644');
      });
    });

    group(
        "Given install.sh runs as root and cannot set up an account's "
        '~/.ssh/authorized_keys as that account', () {
      test(
          'when it installs the sshnpd systemd unit, then it stops with an '
          'error naming the chown to run, and exits non-zero', () async {
        expectSystemdUnitsUnwritable();

        for (final (List<String> args, String account, Directory dir) in [
          (<String>[], 'alice', alice),
          (['-u', 'bob'], 'bob', bob),
        ]) {
          final ssh = Directory(path.join(dir.path, '.ssh'))..createSync();
          expect(Process.runSync('chmod', ['500', ssh.path]).exitCode, 0);
          addTearDown(() => Process.runSync('chmod', ['700', ssh.path]));
          final before = snapshot(dir);
          if (calls.existsSync()) calls.deleteSync();

          final result = await installAsRoot(
            [...args, 'systemd', 'sshnpd'],
            sudoUser: 'alice',
          );

          expect(result.exitCode, 1, reason: '$account: ${result.stdout}');
          expect(
            result.stdout,
            allOf(
              contains('Error: could not set up ~/.ssh/authorized_keys as '
                  '$account\n'),
              contains("  sudo chown -h '$account' '${ssh.path}'\n"),
            ),
            reason: account,
          );
          expect(
            callsMade().where((String call) => call.contains(dir.path)),
            everyElement(startsWith('$account: ')),
            reason: "only $account acts in $account's home",
          );
          expect(changes(before, snapshot(dir)), isEmpty, reason: account);
        }
      });
    });

    group(
        'Given install.sh runs as root with -u naming an account whose home '
        'it cannot find', () {
      test(
          'when it installs the sshnpd systemd unit, then it refuses before '
          'changing anything', () async {
        final aliceBefore = snapshot(alice);
        final homeBefore = snapshot(home);

        final result = await installAsRoot(
          ['-u', 'nobody', 'systemd', 'sshnpd'],
          sudoUser: 'alice',
        );

        expect(result.exitCode, 1);
        expect(
          result.stdout,
          'Error: could not find the home directory of nobody\n',
        );
        expect(callsMade(), [
          'sudo -H -u alice sh -c echo \$HOME',
          'sudo -H -u nobody sh -c echo \$HOME',
        ]);
        expect(prefix.existsSync(), isFalse);
        expect(changes(aliceBefore, snapshot(alice)), isEmpty);
        expect(changes(homeBefore, snapshot(home)), isEmpty);
      });
    });

    group('Given install.sh runs as a regular user', () {
      test(
          "when it installs a headless job, then the job is in that user's "
          'crontab', () async {
        await expectShimsFirst();
        final String logs = path.join(home.path, '.sshnpd', 'logs');
        final String job = path.join(home.path, '.local', 'bin', 'sshnpd.sh');

        for (final List<String> user in [
          <String>[],
          ['-u', 'tester'],
        ]) {
          for (final File file in [crontab, calls]) {
            if (file.existsSync()) file.deleteSync();
          }
          final result = await install([...user, 'headless', 'sshnpd']);

          expect(
            result.exitCode,
            0,
            reason: '$user: ${result.stdout}${result.stderr}',
          );
          expect(callsMade(), ['crontab -l', 'crontab -'], reason: '$user');
          expect(
            crontab.readAsStringSync(),
            '\n@reboot nohup $job > $logs/sshnpd.log 2> $logs/sshnpd.err\n',
            reason: '$user',
          );
          expect(File(job).existsSync(), isTrue, reason: '$user');
        }
      });

      test(
          'when it installs a headless or tmux job, then the job runs the '
          'programs from the directory they were installed into', () async {
        await expectShimsFirst();
        final String jobs = path.join(home.path, '.local', 'bin');

        for (final (String kind, String job, List<String> into, String dir) in [
          ('headless', 'sshnpd', <String>[], jobs),
          ('headless', 'srvd', ['-b', prefix.path], prefix.path),
          ('tmux', 'sshnpd', ['-b', 'prefix'], prefix.path),
          ('tmux', 'srvd', <String>[], jobs),
        ]) {
          final String script = path.join(jobs, '$job.sh');
          for (final File file in [File(script), crontab]) {
            if (file.existsSync()) file.deleteSync();
          }

          final result = await install(
            [...into, kind, job],
            workingDirectory: root.path,
          );

          expect(
            result.exitCode,
            0,
            reason: '$kind $job $into: ${result.stdout}${result.stderr}',
          );
          expect(File(path.join(dir, job)).existsSync(), isTrue);
          expect(
            File(script).readAsLinesSync(),
            contains('binary_path="$dir"'),
            reason: '$kind $job $into',
          );
        }
      });

      test(
          'when it installs a headless or tmux job again into another '
          'directory, then the job runs the programs from that directory',
          () async {
        await expectShimsFirst();
        final String first = path.join(root.path, 'first');
        final String second = path.join(root.path, 'second');

        for (final String kind in ['headless', 'tmux']) {
          final String script =
              path.join(home.path, '.local', 'bin', 'sshnpd.sh');
          if (File(script).existsSync()) File(script).deleteSync();
          for (final String dir in [first, second]) {
            final result = await install(['-b', dir, kind, 'sshnpd']);

            expect(
              result.exitCode,
              0,
              reason: '$kind $dir: ${result.stdout}${result.stderr}',
            );
            expect(
              File(script).readAsLinesSync(),
              contains('binary_path="$dir"'),
              reason: '$kind $dir',
            );
          }
        }
      });
    });

    group(
        'Given install.sh runs as a regular user whose job script or log '
        'directory belongs to another account', () {
      test(
          'when it installs a headless or tmux job, then it stops before '
          'changing anything and prints the commands to clean up the earlier '
          'install', () async {
        await expectShimsFirst();
        final String local = path.join(home.path, '.local');
        final String sshnpd = path.join(home.path, '.sshnpd');

        for (final (List<String> args, String linked, String target) in [
          (['headless', 'sshnpd'], '.local/bin/sshnpd.sh', '/etc/hosts'),
          (['npt', 'headless', 'sshnpd'], '.local/bin/sshnpd.sh', '/etc/hosts'),
          (['headless', 'srvd'], '.sshnpd/logs', '/usr'),
          (['tmux', 'sshnpd'], '.local/bin', '/usr'),
        ]) {
          for (final String dir in [local, sshnpd]) {
            if (Directory(dir).existsSync()) {
              Directory(dir).deleteSync(recursive: true);
            }
          }
          final String link = path.join(home.path, linked);
          Directory(path.dirname(link)).createSync(recursive: true);
          Link(link).createSync(target);
          expect(
            Process.runSync('/bin/sh', ['-c', '[ -O "\$1" ]', 'sh', link])
                .exitCode,
            1,
            reason: 'this process owns $target',
          );
          final String job = args.last;
          final String script = path.join(local, 'bin', '$job.sh');
          final bool hasScript = File(script).existsSync();
          final String owner = linked.startsWith('.local') ? local : sshnpd;
          final homeBefore = snapshot(home);
          if (calls.existsSync()) calls.deleteSync();

          final result = await install(args);

          final String kindJob = args.sublist(args.length - 2).join(' ');
          expect(result.exitCode, 1, reason: '$args: ${result.stderr}');
          expect(
            result.stdout,
            'Error: install.sh $kindJob writes to these, which tester does not '
            'own:\n'
            '  $link\n'
            'To clean up an earlier install as root, run:\n'
            "  sudo sh -c 'crontab -l | grep -v -F -- \"\$1\" | crontab -' sh "
            "'$script'\n"
            "  sudo chown -R -h 'tester' '$owner'\n"
            '${hasScript ? 'then copy any settings you need from $script and '
                'remove it with:\n'
                "  rm -f '$script'\n" : ''}'
            'and run install.sh again.\n',
            reason: '$args',
          );
          expect(callsMade(), isEmpty, reason: '$args');
          expect(changes(homeBefore, snapshot(home)), isEmpty, reason: '$args');
        }
        expect(crontab.existsSync(), isFalse);
      });
    });

    group(
        'Given install.sh runs as a regular user with -u naming another '
        'account', () {
      test(
          "when it installs npt, then npt is in that account's ~/.local/bin "
          "and nothing in the user's own home is created or changed", () async {
        final homeBefore = snapshot(home);

        final result = await install(['-u', 'bob', 'npt']);

        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        expect(callsMade(), ['sudo -H -u bob sh -c echo \$HOME']);
        expect(
          namesIn(path.join(bob.path, '.local', 'bin')),
          ['atsc', 'npt', 'srv'],
        );
        expect(
          File(path.join(bob.path, '.profile')).readAsStringSync(),
          'PATH="\$PATH:\$HOME/.local/bin"\n',
        );
        expect(changes(homeBefore, snapshot(home)), isEmpty);
      });
    });

    group('Given links left in the chosen directory by an earlier root install',
        () {
      test(
          'when a non-root install runs, then it replaces the links rather '
          'than follow them', () async {
        final rootBin = Directory(path.join(root.path, 'usr_local_bin'))
          ..createSync();
        standIn(path.join(rootBin.path, 'atsc'), 'root atsc');
        for (final String name in ['srv', 'npt']) {
          File(path.join(bundle.path, name))
              .copySync(path.join(rootBin.path, name));
          executable(path.join(rootBin.path, name));
        }
        prefix.createSync();
        for (final String name in ['atsc', 'srv', 'npt']) {
          Link(path.join(prefix.path, name))
              .createSync(path.join(rootBin.path, name));
        }

        final result = await install(['-b', prefix.path, 'npt']);

        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        for (final String name in ['atsc', 'srv', 'npt']) {
          expect(
            FileSystemEntity.isLinkSync(path.join(prefix.path, name)),
            isFalse,
            reason: name,
          );
        }
        expect(await output(path.join(prefix.path, 'npt')), 'atsc 1\n[npt]\n');
        expect(await output(path.join(rootBin.path, 'atsc')), 'root atsc\n');
      });

      test(
          'when a non-root install cannot read the files they link to, then it '
          'replaces the links', () async {
        final rootBin = Directory(path.join(root.path, 'usr_local_bin'))
          ..createSync();
        final String rootAtsc = path.join(rootBin.path, 'atsc');
        standIn(rootAtsc, 'root atsc');
        prefix.createSync();
        Link(path.join(prefix.path, 'atsc')).createSync(rootAtsc);
        expect(Process.runSync('chmod', ['311', rootAtsc]).exitCode, 0);
        addTearDown(() => Process.runSync('chmod', ['755', rootAtsc]));

        final result = await install(['-b', prefix.path, 'atsc']);

        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        expect(namesIn(prefix.path), ['atsc']);
        expect(await output(path.join(prefix.path, 'atsc')), 'atsc 1\n');
      });
    });

    group('Given no ~/.profile', () {
      test(
          'when install.sh installs into ~/.local/bin, then it creates '
          '~/.profile with ~/.local/bin on its PATH', () async {
        final result = await install(['npt']);

        expect(result.stderr, isEmpty);
        expect(
          File(path.join(home.path, '.profile')).readAsStringSync(),
          'PATH="\$PATH:\$HOME/.local/bin"\n',
        );
      });
    });

    group('Given a ~/.profile that puts ~/.local/bin on the PATH', () {
      test(
          'when install.sh installs into ~/.local/bin, then it leaves '
          '~/.profile alone', () async {
        final profile = File(path.join(home.path, '.profile'))
          ..writeAsStringSync('export PATH="\$HOME/.local/bin:\$PATH"\n');

        final result = await install(['npt']);

        expect(result.stderr, isEmpty);
        expect(
          profile.readAsStringSync(),
          'export PATH="\$HOME/.local/bin:\$PATH"\n',
        );
      });
    });

    group('Given a ~/.profile without ~/.local/bin on the PATH', () {
      test(
          'when install.sh installs into ~/.local/bin, then it adds '
          '~/.local/bin to the PATH there', () async {
        final profile = File(path.join(home.path, '.profile'))
          ..writeAsStringSync('umask 022\n');

        final result = await install(['npt']);

        expect(result.stderr, isEmpty);
        expect(
          profile.readAsStringSync(),
          'umask 022\nPATH="\$PATH:\$HOME/.local/bin"\n',
        );
      });
    });
  }, skip: isRoot ? 'install.sh installs differently as root' : false);
}
