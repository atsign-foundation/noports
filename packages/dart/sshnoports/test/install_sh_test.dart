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

  /// Writes a `tmux` shim which has a session of every name. A new session
  /// records the `~/.tmux.conf` that tmux would read from its HOME, and the
  /// command sent to it records that it runs with that HOME.
  void tmuxWithSessions() {
    final String session = path.join(root.path, 'session_home');
    shim(
      'tmux',
      '${record('tmux')}'
          'case "\$1" in\n'
          'has-session) exit 0 ;;\n'
          'new-session)\n'
          '  if [ -f "\$HOME/.tmux.conf" ]; then\n'
          "    echo \"tmux reads \$HOME/.tmux.conf\" >> '${calls.path}'\n"
          '  fi\n'
          "  printf '%s' \"\$HOME\" > '$session' ;;\n"
          'send-keys)\n'
          "  echo \"job runs with HOME=\$(cat '$session')\" >> '${calls.path}' ;;\n"
          'esac\n',
    );
  }

  /// The commands the shims were run with, in order.
  List<String> callsMade() => calls.existsSync() ? calls.readAsLinesSync() : [];

  /// The step that stops an earlier root job, up to the quoted pattern for
  /// its script.
  const String stopStep = r"""  sudo sh -c 'for p in $(pgrep -u 0 -f -- "^[^ ]*sh $1\$"); do pkill -P "$p"; kill "$p"; done' sh '""";

  /// [text] with a backslash before each character that is special in an
  /// extended regular expression.
  String ereEscaped(String text) => text.replaceAllMapped(
        RegExp(r'[\[\\.*^$+?(){|]'),
        (Match match) => '\\${match[0]}',
      );

  /// Writes [entries] as the passwd file that install.sh reads.
  void passwd(String entries) =>
      File(path.join(root.path, 'passwd')).writeAsStringSync(entries);

  /// Runs install.sh from the bundle with [args] under [umask], with
  /// [homeDir], or else [home], as its HOME, and [searchPath] as its PATH, or
  /// else the shims in front of the PATH of this process. A [sudoUser] is the
  /// account sudo was run from, and a [workingDirectory] the directory it
  /// runs in.
  Future<ProcessResult> install(
    List<String> args, {
    String umask = '022',
    Directory? homeDir,
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
          'HOME': (homeDir ?? home).path,
          'USER': 'tester',
          'PATH': searchPath ?? '${shims.path}:${Platform.environment['PATH']}',
          if (sudoUser != null) 'SUDO_USER': sudoUser,
        },
        includeParentEnvironment: false,
        workingDirectory: workingDirectory,
      );

  /// Writes the `id`, `uname`, `chown` and `sed` shims that make install.sh
  /// run as root would run it on Linux, and records its `mkdir`, `touch` and
  /// `chmod` calls.
  void shimRoot() {
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
  }

  /// Runs install.sh as root would run it on Linux, into [prefix] with
  /// [args].
  Future<ProcessResult> installAsRoot(
    List<String> args, {
    String? umask,
    Directory? homeDir,
    String? sudoUser,
  }) {
    shimRoot();
    return install(
      ['-b', prefix.path, ...args],
      umask: umask ?? '022',
      homeDir: homeDir,
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
    const String passwdLine = 'passwd_file=/etc/passwd\n';
    final String source =
        File(path.join('bundles', 'shell', 'install.sh')).readAsStringSync();
    expect(passwdLine.allMatches(source).length, 1);
    File(path.join(bundle.path, 'install.sh')).writeAsStringSync(
      source.replaceFirst(
        passwdLine,
        "passwd_file='${path.join(root.path, 'passwd')}'\n",
      ),
    );
    passwd('root:*:0:0:System Administrator:${home.path}:/bin/sh\n');
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

    group('Given install.sh runs as root with no -b', () {
      test(
          'when it installs npt, then atsc, srv and npt are installed into '
          '/usr/local/bin', () async {
        const String usrLocalBin = '/usr/local/bin';
        const List<String> writers = [
          'chmod', 'cp', 'ln', 'mkdir', 'mv', 'rm', 'touch', //
        ];
        shimRoot();
        for (final String name in writers) {
          shim(
            name,
            '${record(name)}'
            'case "\$*" in *$usrLocalBin*) exit 0 ;; esac\n'
            'for d in /bin /usr/bin; do\n'
            '  if [ -x "\$d/$name" ]; then exec "\$d/$name" "\$@"; fi\n'
            'done\n'
            'exit 127\n',
          );
        }
        for (final String name in ['cmp', 'dirname', 'readlink', 'sh']) {
          shim(
            name,
            'for d in /bin /usr/bin; do\n'
            '  if [ -x "\$d/$name" ]; then exec "\$d/$name" "\$@"; fi\n'
            'done\n'
            'exit 127\n',
          );
        }
        final probe = await Process.run(
          '/bin/sh',
          ['-c', 'for c in "\$@"; do command -v \$c; done', 'sh', ...writers],
          environment: {'PATH': shims.path},
          includeParentEnvironment: false,
        );
        expect(
          probe.stdout,
          writers.map((name) => '${path.join(shims.path, name)}\n').join(),
        );
        final unshimmed = await Process.run(
          '/bin/sh',
          ['-c', 'command -v dd || command -v install || command -v tee'],
          environment: {'PATH': shims.path},
          includeParentEnvironment: false,
        );
        expect(
          unshimmed.exitCode,
          isNot(0),
          reason: 'install.sh finds only the stand-ins: ${unshimmed.stdout}',
        );
        final String atsc = path.join(bundle.path, 'atsc');
        final String fenced = path.join(root.path, 'fence$usrLocalBin');
        for (final List<String> args in [
          ['chmod', '755', fenced],
          ['cp', '-f', atsc, fenced],
          ['ln', '-s', atsc, fenced],
          ['mkdir', '-p', fenced],
          ['mv', '-f', atsc, fenced],
          ['rm', '-f', atsc, fenced],
          ['touch', fenced],
        ]) {
          final result = Process.runSync(
            path.join(shims.path, args.first),
            args.sublist(1),
          );
          expect(result.exitCode, 0, reason: '$args: ${result.stderr}');
        }
        expect(
          Directory(path.join(root.path, 'fence')).existsSync(),
          isFalse,
          reason: 'the shims run nothing on paths in $usrLocalBin',
        );
        expect(File(atsc).existsSync(), isTrue);
        final String outside = path.join(root.path, 'outside');
        expect(
          Process.runSync(path.join(shims.path, 'mkdir'), [outside]).exitCode,
          0,
        );
        expect(
          Directory(outside).existsSync(),
          isTrue,
          reason: 'the shims run the command on other paths',
        );
        if (calls.existsSync()) calls.deleteSync();
        final List<String> namesBefore = namesIn(usrLocalBin);

        final result = await install(
          ['npt'],
          searchPath: shims.path,
          sudoUser: 'alice',
        );

        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        for (final String name in ['atsc', 'srv', 'npt']) {
          final String file = '$usrLocalBin/$name';
          expect(
            callsMade(),
            containsAllInOrder([
              matches(RegExp('^mv -f $usrLocalBin/\\.$name\\.new\\.\\d+ '
                  '${RegExp.escape(file)}\$')),
              startsWith('chown -h root'),
            ]),
            reason: name,
          );
          expect(
            result.stdout,
            contains('=> Installed $name to $usrLocalBin\n'),
          );
        }
        final String actors = [...writers, 'chown'].join('|');
        expect(
          callsMade().where((String call) => call.contains(usrLocalBin)),
          everyElement(matches(RegExp('^($actors) '))),
          reason: 'only the shims act on $usrLocalBin',
        );
        expect(namesIn(usrLocalBin), namesBefore);
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

    group(
        "Given install.sh runs as root from a root login whose HOME is another "
        "account's home", () {
      test(
          "when it installs a headless job, then the job is in root's crontab "
          "and runs from the home in root's entry in /etc/passwd", () async {
        await expectShimsFirst();
        final String logs = path.join(home.path, '.sshnpd', 'logs');
        final String job = path.join(home.path, '.local', 'bin', 'sshnpd.sh');
        final aliceBefore = snapshot(alice);

        final result =
            await installAsRoot(['headless', 'sshnpd'], homeDir: alice);

        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        expect(
          crontab.readAsStringSync(),
          '\n@reboot nohup $job > $logs/sshnpd.log 2> $logs/sshnpd.err\n',
        );
        expect(
          result.stdout,
          contains('To start the job immediately:\n'
              "  HOME='${home.path}' nohup $job > $logs/sshnpd.log 2> "
              '$logs/sshnpd.err &\n'),
        );
        expect(File(job).existsSync(), isTrue);
        expect(changes(aliceBefore, snapshot(alice)), isEmpty);
      });

      test(
          'when it installs a tmux job whose session exists, then it restarts '
          "the session with root's home, reading no tmux configuration in "
          "that account's home, and prints a start command that sets HOME to "
          "root's home", () async {
        await expectShimsFirst();
        tmuxWithSessions();
        final String job = path.join(home.path, '.local', 'bin', 'sshnpd.sh');
        for (final Directory dir in [alice, home]) {
          File(path.join(dir.path, '.tmux.conf')).writeAsStringSync('\n');
        }
        final aliceBefore = snapshot(alice);

        final result = await installAsRoot(['tmux', 'sshnpd'], homeDir: alice);

        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        expect(
          callsMade(),
          containsAllInOrder([
            'tmux kill-session -t sshnpd',
            'tmux reads ${home.path}/.tmux.conf',
            'job runs with HOME=${home.path}',
          ]),
        );
        expect(
          callsMade().where((String call) => call.contains(alice.path)),
          isEmpty,
        );
        expect(
          crontab.readAsStringSync(),
          '\n@reboot tmux new-session -d -s sshnpd && tmux send-keys -t sshnpd '
          '$job C-m\n',
        );
        expect(
          result.stdout,
          contains('To start the service immediately:\n'
              "  HOME='${home.path}' tmux new-session -d -s sshnpd && tmux "
              'send-keys -t sshnpd $job C-m &\n'),
        );
        expect(changes(aliceBefore, snapshot(alice)), isEmpty);
      });

      test(
          'when it installs the sshnpd systemd unit, with or without -u root, '
          "then it sets up root's keys and touches nothing in that account's "
          'home', () async {
        expectSystemdUnitsUnwritable();
        final String keys = path.join(home.path, '.ssh', 'authorized_keys');

        for (final (String? sudoUser, List<String> args) in [
          (null, <String>[]),
          (null, ['-u', 'root']),
          ('alice', ['-u', 'root']),
        ]) {
          final String reason = '$args, sudo user $sudoUser';
          final aliceBefore = snapshot(alice);
          final Directory ssh = Directory(path.dirname(keys));
          if (ssh.existsSync()) ssh.deleteSync(recursive: true);
          if (calls.existsSync()) calls.deleteSync();

          final result = await installAsRoot(
            [...args, 'systemd', 'sshnpd'],
            homeDir: alice,
            sudoUser: sudoUser,
          );

          expect(
            result.exitCode,
            0,
            reason: '$reason: ${result.stdout}${result.stderr}',
          );
          expect(callsMade(), contains('touch $keys'), reason: reason);
          expect(
            callsMade().where((String call) => call.contains(alice.path)),
            isEmpty,
            reason: reason,
          );
          expect(
            callsMade(),
            isNot(contains(startsWith('sudo -H -u root '))),
            reason: reason,
          );
          expect(
            changes(aliceBefore, snapshot(alice)),
            isEmpty,
            reason: reason,
          );
        }
      });
    });

    group('Given /etc/passwd has no entry for root with uid 0', () {
      test(
          'when install.sh runs as root from a root login, then it refuses '
          'before changing anything', () async {
        final aliceBefore = snapshot(alice);
        final homeBefore = snapshot(home);

        for (final String entries in [
          'daemon:*:1:1:daemon:/var/root:/bin/sh\n',
          'root:*:501:20:root:${home.path}:/bin/sh\n'
              'toor:*:0:0:toor:${home.path}:/bin/sh\n',
        ]) {
          passwd(entries);
          if (calls.existsSync()) calls.deleteSync();

          final result =
              await installAsRoot(['systemd', 'sshnpd'], homeDir: alice);

          expect(result.exitCode, 1, reason: entries);
          expect(
            result.stdout,
            "Error: could not find root's home directory in "
            '${path.join(root.path, 'passwd')}\n',
            reason: entries,
          );
          expect(callsMade(), isEmpty, reason: entries);
          expect(prefix.existsSync(), isFalse, reason: entries);
        }
        expect(changes(aliceBefore, snapshot(alice)), isEmpty);
        expect(changes(homeBefore, snapshot(home)), isEmpty);
      });
    });

    group(
        "Given root's entry is the last line of /etc/passwd, with no newline "
        'after it', () {
      test(
          'when install.sh runs as root from a root login, then it finds '
          "root's home there", () async {
        expectSystemdUnitsUnwritable();
        final String keys = path.join(home.path, '.ssh', 'authorized_keys');

        for (final String entries in [
          'root:*:0:0:root:${home.path}:/bin/sh',
          'daemon:*:1:1:daemon:/var/root:/bin/sh\n'
              'root:*:0:0:root:${home.path}:/bin/sh',
        ]) {
          passwd(entries);
          final Directory ssh = Directory(path.dirname(keys));
          if (ssh.existsSync()) ssh.deleteSync(recursive: true);
          if (calls.existsSync()) calls.deleteSync();

          final result =
              await installAsRoot(['systemd', 'sshnpd'], homeDir: alice);

          expect(
            result.exitCode,
            0,
            reason: '$entries: ${result.stdout}${result.stderr}',
          );
          expect(callsMade(), contains('touch $keys'), reason: entries);
        }
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

    group('Given an option after a command', () {
      test(
          'when install.sh installs npt and then, after -b, srv, then npt is '
          'installed into the default directory and srv into the -b '
          'directory', () async {
        final result = await install(['npt', '-b', prefix.path, 'srv']);

        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        expect(
          namesIn(path.join(home.path, '.local', 'bin')),
          ['atsc', 'npt', 'srv'],
        );
        expect(namesIn(prefix.path), ['srv']);
      });

      test(
          'when install.sh runs as root through sudo and -u bob follows a '
          'headless job, then it refuses before installing anything', () async {
        final bobBefore = snapshot(bob);

        final result = await installAsRoot(
          ['npt', 'headless', 'sshnpd', '-u', 'bob'],
          sudoUser: 'alice',
        );

        expect(result.exitCode, 1, reason: '${result.stdout}');
        expect(
          result.stdout,
          'Error: run install.sh headless sshnpd without sudo, as the user who '
          'will run the daemon\n',
        );
        expect(prefix.existsSync(), isFalse);
        expect(crontab.existsSync(), isFalse);
        expect(changes(bobBefore, snapshot(bob)), isEmpty);
      });

      test(
          'when no command follows an option, or an option has no value, then '
          'install.sh refuses before changing anything, with an error naming '
          'the option', () async {
        await expectShimsFirst();
        expectSystemdUnitsUnwritable();
        const String noValueB = 'Error: -b needs a directory';
        const String noValueU = 'Error: -u needs an account name';

        for (final (
              List<String> args,
              bool asRoot,
              String? sudoUser,
              String error,
            ) in [
          (
            ['npt', '-b', prefix.path],
            false,
            null,
            'Error: -b ${prefix.path} is not followed by a command',
          ),
          (
            ['npt', '-u', 'bob'],
            false,
            null,
            'Error: -u bob is not followed by a command',
          ),
          (
            ['-b', prefix.path, '-u', 'bob'],
            false,
            null,
            'Error: -b ${prefix.path} is not followed by a command',
          ),
          (
            ['npt', 'headless', 'sshnpd', '-u', 'bob'],
            true,
            null,
            'Error: -u bob is not followed by a command',
          ),
          (
            ['systemd', 'sshnpd', '-u', 'bob'],
            true,
            null,
            'Error: -u bob is not followed by a command',
          ),
          (
            ['systemd', 'sshnpd', '-u', 'bob'],
            true,
            'alice',
            'Error: -u bob is not followed by a command',
          ),
          (['npt', '-b'], false, null, noValueB),
          (['-b', '', 'npt'], false, null, noValueB),
          (['npt', '-u'], false, null, noValueU),
          (['-u', '', 'npt'], false, null, noValueU),
        ]) {
          final String reason = '$args, root $asRoot, sudo user $sudoUser';
          final homeBefore = snapshot(home);
          final aliceBefore = snapshot(alice);
          final bobBefore = snapshot(bob);
          if (calls.existsSync()) calls.deleteSync();

          final result = asRoot
              ? await installAsRoot(args, sudoUser: sudoUser)
              : await install(args);

          expect(result.exitCode, 1, reason: '$reason: ${result.stderr}');
          expect(result.stdout, '$error\n', reason: reason);
          expect(prefix.existsSync(), isFalse, reason: reason);
          expect(crontab.existsSync(), isFalse, reason: reason);
          expect(
            callsMade(),
            everyElement(endsWith(' sh -c echo \$HOME')),
            reason: reason,
          );
          expect(changes(homeBefore, snapshot(home)), isEmpty, reason: reason);
          expect(
            changes(aliceBefore, snapshot(alice)),
            isEmpty,
            reason: reason,
          );
          expect(changes(bobBefore, snapshot(bob)), isEmpty, reason: reason);
        }
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

      test(
          "when it cannot set up root's ~/.ssh/authorized_keys, then it stops "
          'with an error and exits non-zero', () async {
        expectSystemdUnitsUnwritable();
        final ssh = Directory(path.join(home.path, '.ssh'))..createSync();
        expect(Process.runSync('chmod', ['500', ssh.path]).exitCode, 0);
        addTearDown(() => Process.runSync('chmod', ['700', ssh.path]));

        final result = await installAsRoot(['systemd', 'sshnpd']);

        expect(result.exitCode, 1, reason: '${result.stdout}');
        expect(
          result.stdout,
          endsWith('Error: could not set up ${ssh.path}/authorized_keys\n'),
        );
        expect(namesIn(ssh.path), isEmpty);
      });
    });

    group(
        "Given install.sh runs as root and cannot set up an account's "
        '~/.ssh/authorized_keys as that account', () {
      test(
          'when it installs the sshnpd systemd unit, then it stops before '
          'installing the unit, with an error naming the command that moves '
          "that account's ~/.ssh aside as that account, and exits non-zero",
          () async {
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
            'Error: could not set up ~/.ssh/authorized_keys as $account\n'
            "Move $account's ~/.ssh aside, as $account, with:\n"
            "  sudo -H -u '$account' sh -c 'mv ~/.ssh ~/.ssh.old'\n"
            'then run install.sh again, and copy back, as $account, anything '
            'in ~/.ssh.old that is still needed, such as the keys in '
            '~/.ssh.old/authorized_keys.\n',
            reason: account,
          );
          expect(result.stdout, isNot(contains('chown')), reason: account);
          expect(
            callsMade(),
            isNot(contains('systemctl daemon-reload')),
            reason: '$account: the unit is not installed',
          );
          expect(
            prefix.existsSync(),
            isFalse,
            reason: '$account: no program is installed',
          );
          expect(
            callsMade().where((String call) => call.contains(dir.path)),
            everyElement(startsWith('$account: ')),
            reason: "only $account acts in $account's home",
          );
          expect(changes(before, snapshot(dir)), isEmpty, reason: account);
        }
      });

      test(
          'when ~/.ssh.old is taken, then the move step and the last line name '
          'the first free one of ~/.ssh.old.2, ~/.ssh.old.3 and so on',
          () async {
        expectSystemdUnitsUnwritable();
        final ssh = Directory(path.join(alice.path, '.ssh'))..createSync();
        expect(Process.runSync('chmod', ['500', ssh.path]).exitCode, 0);
        addTearDown(() => Process.runSync('chmod', ['700', ssh.path]));
        Directory(path.join(alice.path, '.ssh.old')).createSync();
        Link(path.join(alice.path, '.ssh.old.2'))
            .createSync(path.join(root.path, 'nowhere'));
        final before = snapshot(alice);

        final result =
            await installAsRoot(['systemd', 'sshnpd'], sudoUser: 'alice');

        expect(result.exitCode, 1, reason: '${result.stdout}');
        expect(
          result.stdout,
          'Error: could not set up ~/.ssh/authorized_keys as alice\n'
          "Move alice's ~/.ssh aside, as alice, with:\n"
          "  sudo -H -u 'alice' sh -c 'mv ~/.ssh ~/.ssh.old.3'\n"
          'then run install.sh again, and copy back, as alice, anything in '
          '~/.ssh.old.3 that is still needed, such as the keys in '
          '~/.ssh.old.3/authorized_keys.\n',
        );
        expect(prefix.existsSync(), isFalse);
        expect(changes(before, snapshot(alice)), isEmpty);
      });

      test(
          'when the account has no ~/.ssh and cannot create one, then the error '
          'says to check its home directory, with no move step', () async {
        expectSystemdUnitsUnwritable();

        for (final (List<String> args, String account, Directory dir) in [
          (<String>[], 'alice', alice),
          (['-u', 'bob'], 'bob', bob),
        ]) {
          expect(Process.runSync('chmod', ['500', dir.path]).exitCode, 0);
          addTearDown(() => Process.runSync('chmod', ['700', dir.path]));
          final before = snapshot(dir);

          final result = await installAsRoot(
            [...args, 'systemd', 'sshnpd'],
            sudoUser: 'alice',
          );

          expect(result.exitCode, 1, reason: '$account: ${result.stdout}');
          expect(
            result.stdout,
            'Error: $account could not create ~/.ssh; check that $account owns '
            'its home directory and can write to it\n',
            reason: account,
          );
          expect(prefix.existsSync(), isFalse, reason: account);
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
        bob.deleteSync();
        final aliceBefore = snapshot(alice);
        final homeBefore = snapshot(home);

        for (final String account in ['nobody', 'bob']) {
          if (calls.existsSync()) calls.deleteSync();

          final result = await installAsRoot(
            ['-u', account, 'systemd', 'sshnpd'],
            sudoUser: 'alice',
          );

          expect(result.exitCode, 1, reason: account);
          expect(
            result.stdout,
            'Error: could not find the home directory of $account\n',
            reason: account,
          );
          expect(
            callsMade(),
            [
              'sudo -H -u alice sh -c echo \$HOME',
              'sudo -H -u $account sh -c echo \$HOME',
            ],
            reason: account,
          );
          expect(prefix.existsSync(), isFalse, reason: account);
          expect(bob.existsSync(), isFalse, reason: account);
        }
        expect(changes(aliceBefore, snapshot(alice)), isEmpty);
        expect(changes(homeBefore, snapshot(home)), isEmpty);
      });
    });

    group('Given install.sh runs with -u and sudo is not installed', () {
      test(
          'when it installs npt, then it refuses before changing anything and '
          'says that sudo is not installed', () async {
        final homeBefore = snapshot(home);
        final bobBefore = snapshot(bob);

        final result = await install(
          ['-u', 'bob', 'npt'],
          searchPath: pathWithout('sudo'),
        );

        expect(result.exitCode, 1, reason: '${result.stderr}');
        expect(
          result.stdout,
          'Error: could not find the home directory of bob: sudo is not '
          'installed\n',
        );
        expect(changes(homeBefore, snapshot(home)), isEmpty);
        expect(changes(bobBefore, snapshot(bob)), isEmpty);
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

      test(
          'when it installs a headless or tmux job into a directory whose name '
          'has & or |, then the job runs the programs from that directory',
          () async {
        await expectShimsFirst();
        final String dir = path.join(root.path, 'a&b|c');
        final String script =
            path.join(home.path, '.local', 'bin', 'sshnpd.sh');

        for (final String kind in ['headless', 'tmux']) {
          if (File(script).existsSync()) File(script).deleteSync();

          final result = await install(['-b', dir, kind, 'sshnpd']);

          expect(
            result.exitCode,
            0,
            reason: '$kind: ${result.stdout}${result.stderr}',
          );
          expect(File(path.join(dir, 'sshnpd')).existsSync(), isTrue);
          expect(
            File(script).readAsLinesSync(),
            contains('binary_path="$dir"'),
            reason: kind,
          );
        }
      });
    });

    group('Given a -b directory whose name has ", \$, `, \\ or a newline', () {
      test(
          'when install.sh installs a headless or tmux job into it, then it '
          'refuses before installing anything, with an error naming -b',
          () async {
        final homeBefore = snapshot(home);

        for (final String char in ['"', r'$', '`', r'\', '\n']) {
          final String dir = path.join(root.path, 'a${char}b');
          for (final List<String> args in [
            ['-b', dir, 'headless', 'sshnpd'],
            ['-b', dir, 'npt', 'tmux', 'srvd'],
          ]) {
            final result = await install(args);

            expect(result.exitCode, 1, reason: '$args: ${result.stderr}');
            expect(
              result.stdout,
              'Error: the directory given with -b cannot contain ", \$, `, \\ '
              'or a newline: $dir\n',
              reason: '$args',
            );
            expect(Directory(dir).existsSync(), isFalse, reason: '$args');
          }
        }
        expect(changes(homeBefore, snapshot(home)), isEmpty);
        expect(callsMade(), isEmpty);
      });

      test('when install.sh installs npt into it, then it installs npt',
          () async {
        final String dir = path.join(root.path, r'a$b');

        final result = await install(['-b', dir, 'npt']);

        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        expect(namesIn(dir), ['atsc', 'npt', 'srv']);
      });
    });

    group('Given a headless or tmux command with no job name', () {
      test(
          'when install.sh runs it, then it prints the usage text and exits 1 '
          'having installed nothing, and with --help it exits 0', () async {
        final homeBefore = snapshot(home);

        for (final String kind in ['headless', 'tmux']) {
          final help = await install([kind, '--help']);
          expect(help.exitCode, 0, reason: '$kind --help: ${help.stderr}');
          expect(help.stdout, contains('headless <job>'), reason: kind);

          for (final List<String> args in [
            [kind],
            ['npt', kind],
          ]) {
            final result = await install(args);

            expect(result.exitCode, 1, reason: '$args: ${result.stderr}');
            expect(result.stdout, help.stdout, reason: '$args');
          }
        }
        expect(changes(homeBefore, snapshot(home)), isEmpty);
        expect(callsMade(), isEmpty);
      });
    });

    group(
        'Given install.sh runs as a regular user who cannot set up '
        '~/.ssh/authorized_keys', () {
      test(
          'when it installs a headless job, a tmux job or a launchd unit, then '
          'it exits 1 having installed nothing', () async {
        await expectShimsFirst();
        final ssh = Directory(path.join(home.path, '.ssh'))..createSync();
        expect(Process.runSync('chmod', ['500', ssh.path]).exitCode, 0);
        addTearDown(() => Process.runSync('chmod', ['700', ssh.path]));
        final homeBefore = snapshot(home);

        for (final (List<String> args, String system) in [
          (['headless', 'sshnpd'], 'Linux'),
          (['tmux', 'sshnpd'], 'Linux'),
          (['launchd', 'sshnpd'], 'Darwin'),
        ]) {
          shim('uname', 'echo $system\n');
          if (calls.existsSync()) calls.deleteSync();

          final result = await install(args);

          expect(result.exitCode, 1, reason: '$args: ${result.stderr}');
          expect(
            result.stdout,
            'Error: could not set up ${ssh.path}/authorized_keys\n',
            reason: '$args',
          );
          expect(changes(homeBefore, snapshot(home)), isEmpty, reason: '$args');
          expect(callsMade(), isEmpty, reason: '$args');
        }
        expect(crontab.existsSync(), isFalse);
      });
    });

    group('Given an account whose ~/.ssh/authorized_keys cannot be set up', () {
      test(
          'when install.sh installs srvd as a headless job, a tmux job or a '
          'systemd unit, then it installs it', () async {
        await expectShimsFirst();
        expectSystemdUnitsUnwritable();

        for (final (List<String> args, bool asRoot, String? sudoUser) in [
          (['headless', 'srvd'], false, null),
          (['tmux', 'srvd'], false, null),
          (['systemd', 'srvd'], true, null),
          (['systemd', 'srvd'], true, 'alice'),
        ]) {
          final String reason = '$args, root $asRoot, sudo user $sudoUser';
          final Directory dir = sudoUser == 'alice' ? alice : home;
          final ssh = Directory(path.join(dir.path, '.ssh'))..createSync();
          expect(Process.runSync('chmod', ['500', ssh.path]).exitCode, 0);
          addTearDown(() => Process.runSync('chmod', ['700', ssh.path]));
          final sshBefore = snapshot(ssh);
          for (final File file in [crontab, calls]) {
            if (file.existsSync()) file.deleteSync();
          }

          final result = asRoot
              ? await installAsRoot(args, sudoUser: sudoUser)
              : await install(args);

          expect(
            result.exitCode,
            0,
            reason: '$reason: ${result.stdout}${result.stderr}',
          );
          final String bin =
              asRoot ? prefix.path : path.join(home.path, '.local', 'bin');
          expect(
            File(path.join(bin, 'srvd')).existsSync(),
            isTrue,
            reason: reason,
          );
          expect(
            callsMade(),
            asRoot
                ? contains('systemctl daemon-reload')
                : containsAllInOrder(['crontab -l', 'crontab -']),
            reason: reason,
          );
          expect(
            callsMade().where((String call) => call.contains('.ssh')),
            isEmpty,
            reason: reason,
          );
          expect(changes(sshBefore, snapshot(ssh)), isEmpty, reason: reason);
        }
      });
    });

    group(
        'Given install.sh runs as a regular user whose job script or log '
        'directory belongs to another account', () {
      test(
          'when it installs a headless or tmux job, then it stops before '
          'changing anything and prints the steps that the user runs to move '
          'the topmost of them in each tree aside and copy it back', () async {
        await expectShimsFirst();
        final String account =
            Process.runSync('id', ['-un']).stdout.toString().trim();
        final String local = path.join(home.path, '.local');
        final String bin = path.join(local, 'bin');
        final String sshnpd = path.join(home.path, '.sshnpd');
        final String nowhere = path.join(root.path, 'nowhere');

        /// The step that moves [p] aside to [old], or else to `<p>.old`, and
        /// copies it back with [cp].
        String move(String cp, String p, [String? old]) {
          old ??= '$p.old';
          return "  mv '$p' '$old' && $cp '$old' '$p'\n";
        }

        for (final (
              List<String> args,
              Map<String, String> links,
              Map<String, String?> taken,
              List<String> listed,
              String moves,
            ) in [
          (
            ['headless', 'sshnpd'],
            {'.local/bin/sshnpd.sh': '/etc/hosts'},
            {},
            [path.join(bin, 'sshnpd.sh')],
            move('cp', path.join(bin, 'sshnpd.sh')),
          ),
          (
            ['npt', 'headless', 'sshnpd'],
            {'.local/bin/sshnpd.sh': '/etc/hosts'},
            {},
            [path.join(bin, 'sshnpd.sh')],
            move('cp', path.join(bin, 'sshnpd.sh')),
          ),
          (
            ['headless', 'srvd'],
            {'.sshnpd/logs': '/usr'},
            {},
            [path.join(sshnpd, 'logs')],
            move('cp -R', path.join(sshnpd, 'logs')),
          ),
          (
            ['tmux', 'sshnpd'],
            {'.local/bin': '/usr'},
            {},
            [bin],
            move('cp -R', bin),
          ),
          (
            ['headless', 'sshnpd'],
            {'.local': '/usr'},
            {},
            [local, bin],
            move('cp -R', local),
          ),
          (
            ['headless', 'sshnpd'],
            {'.local': '/usr', '.sshnpd': '/usr'},
            {},
            [local, bin, sshnpd],
            move('cp -R', local) + move('cp -R', sshnpd),
          ),
          (
            ['headless', 'sshnpd'],
            {'.local': '/usr'},
            {'.local.old': null, '.local.old.2': nowhere},
            [local, bin],
            move('cp -R', local, '$local.old.3'),
          ),
          (
            ['tmux', 'sshnpd'],
            {'.local/bin/sshnpd.sh': '/etc/hosts'},
            {'.local/bin/sshnpd.sh.old': null},
            [path.join(bin, 'sshnpd.sh')],
            move(
              'cp',
              path.join(bin, 'sshnpd.sh'),
              path.join(bin, 'sshnpd.sh.old.2'),
            ),
          ),
        ]) {
          final String reason = '$args, $links, $taken';
          for (final FileSystemEntity entity
              in home.listSync(followLinks: false)) {
            entity.deleteSync(recursive: true);
          }
          for (final MapEntry(:String key, :String value) in links.entries) {
            final String link = path.join(home.path, key);
            Directory(path.dirname(link)).createSync(recursive: true);
            Link(link).createSync(value);
            expect(
              Process.runSync('/bin/sh', ['-c', '[ -O "\$1" ]', 'sh', link])
                  .exitCode,
              1,
              reason: 'this process owns $value',
            );
          }
          for (final MapEntry(:String key, :String? value) in taken.entries) {
            final String name = path.join(home.path, key);
            if (value == null) {
              Directory(name).createSync(recursive: true);
            } else {
              Link(name).createSync(value);
            }
          }
          final String job = args.last;
          final String script = path.join(bin, '$job.sh');
          final homeBefore = snapshot(home);
          if (calls.existsSync()) calls.deleteSync();

          final result = await install(args);

          final String kindJob = args.sublist(args.length - 2).join(' ');
          expect(result.exitCode, 1, reason: '$reason: ${result.stderr}');
          expect(
            result.stdout,
            'Error: install.sh $kindJob writes to these, which $account does '
            'not own:\n'
            '${listed.map((String p) => '  $p\n').join()}'
            'To clean up an earlier install, first have an admin remove its '
            'root cron job and stop it with:\n'
            "  sudo sh -c 'crontab -l | grep -v -F -- \"\$1\" | crontab -' sh "
            "'$script'\n"
            '$stopStep${ereEscaped(script)}\'\n'
            'then move these aside and copy them back, as $account, with:\n'
            '$moves'
            'and run install.sh again.\n',
            reason: reason,
          );
          expect(result.stdout, isNot(contains('chown')), reason: reason);
          expect(callsMade(), isEmpty, reason: reason);
          expect(changes(homeBefore, snapshot(home)), isEmpty, reason: reason);
        }
        expect(crontab.existsSync(), isFalse);
      });
    });

    group(
        'Given a job script whose path has characters that are special in an '
        'extended regular expression', () {
      test(
          'when install.sh prints the step that stops an earlier root job, '
          'then its pattern selects only that script run by a shell', () async {
        await expectShimsFirst();
        const String name = r'h.o+m*e?(1)[2]{3}|^$';
        final odd = Directory(path.join(root.path, name))..createSync();
        final String bin = path.join(odd.path, '.local', 'bin');
        Directory(bin).createSync(recursive: true);
        final String script = path.join(bin, 'sshnpd.sh');
        Link(script).createSync('/etc/hosts');

        final result = await install(['headless', 'sshnpd'], homeDir: odd);

        expect(result.exitCode, 1, reason: '${result.stdout}${result.stderr}');
        final String step = (result.stdout as String)
            .split('\n')
            .singleWhere((String line) => line.startsWith(stopStep));
        expect(step, endsWith("'"));
        final String pattern =
            '^[^ ]*sh ${step.substring(stopStep.length, step.length - 1)}\$';
        for (final (String line, bool selected) in [
          ('/bin/sh $script', true),
          ('sh $script', true),
          ('/usr/bin/bash $script', true),
          ('/bin/sh ${script.replaceAll('.', 'x')}', false),
          for (final String char in name.split('').toSet())
            if (!RegExp(r'[a-z0-9]').hasMatch(char))
              ('/bin/sh ${script.replaceFirst(name, name.replaceAll(char, ''))}',
                  false),
          ('/bin/sh $script -v', false),
          ('sudo sh $script', false),
          ('sh -c kill sh $script', false),
        ]) {
          final grep = await Process.run('/bin/sh', [
            '-c',
            'printf "%s\\n" "\$2" | grep -E -q -- "\$1"',
            'sh',
            pattern,
            line,
          ]);
          expect(grep.exitCode, selected ? 0 : 1, reason: line);
        }
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

    group('Given install.sh runs as a regular user with -u root', () {
      test(
          'when it installs a tmux job whose session exists, then the session '
          "runs with the user's own HOME, and the start command it prints sets "
          'no HOME', () async {
        await expectShimsFirst();
        tmuxWithSessions();
        final String job = path.join(home.path, '.local', 'bin', 'sshnpd.sh');

        final result =
            await install(['-u', 'root', 'tmux', 'sshnpd'], homeDir: alice);

        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        expect(callsMade(), contains('job runs with HOME=${alice.path}'));
        expect(
          result.stdout,
          contains('To start the service immediately:\n'
              '  tmux new-session -d -s sshnpd && tmux send-keys -t sshnpd '
              '$job C-m &\n'),
        );
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
