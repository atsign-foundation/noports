/// Catalogue: features/atsc/atsc.feature
@Timeout(Duration(minutes: 5))
library;

import 'dart:io';

import 'package:noports_core/version.dart' as core;
import 'package:path/path.dart' as path;
import 'package:sshnoports/src/version.dart' as binaries;
import 'package:test/test.dart';

/// Every program atsc runs as a subcommand.
const List<String> subcommands = [
  'at_activate',
  'noports',
  'np_admin',
  'npevents',
  'npp',
  'npp_atserver',
  'npp_file',
  'npt',
  'srvd',
  'sshnp',
  'sshnpd',
];

void main() {
  late Directory snapshots;

  /// Compiles bin/[name].dart to a kernel snapshot called [name].dill, from
  /// whose name the program derives its own, as a compiled binary does.
  Future<void> compile(String name) async {
    final result = await Process.run(Platform.resolvedExecutable, [
      'compile',
      'kernel',
      path.join('bin', '$name.dart'),
      '-o',
      path.join(snapshots.path, '$name.dill'),
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
  }

  /// Runs the snapshot of [name] with [args].
  Future<ProcessResult> run(String name, List<String> args) => Process.run(
        Platform.resolvedExecutable,
        [path.join(snapshots.path, '$name.dill'), ...args],
      );

  /// What `--version` prints for the program called [name].
  String versionOf(String name) =>
      '$name ${binaries.packageVersion} (core ${core.packageVersion})\n';

  /// Expects [usage] to be atsc's usage, listing exactly [subcommands].
  void expectAtscUsage(String usage) {
    final List<String> lines = usage.split('\n');
    expect(lines.first, 'Usage: atsc <command> [arguments]');
    expect(lines, contains('Commands:'));
    expect(
      lines
          .skipWhile((String line) => line != 'Commands:')
          .skip(1)
          .takeWhile((String line) => line.isNotEmpty)
          .toList(),
      [for (final String name in subcommands) '  $name'],
    );
  }

  setUpAll(() async {
    snapshots = Directory.systemTemp.createTempSync('atsc_test');
    await Future.wait([
      for (final String name in ['atsc', 'srv', ...subcommands]) compile(name),
    ]);
  });

  tearDownAll(() => snapshots.deleteSync(recursive: true));

  group('atsc <program> is the same program as <program>', () {
    for (final String program in subcommands) {
      test(program, () async {
        final viaAtsc = await run('atsc', [program, '--help']);
        final direct = await run(program, ['--help']);

        expect('${direct.stdout}${direct.stderr}', isNotEmpty);
        expect(viaAtsc.stdout, direct.stdout);
        expect(viaAtsc.stderr, direct.stderr);
        expect(direct.exitCode, 0);
        expect(viaAtsc.exitCode, 0);
      });
    }
  });

  test('a program names itself by its old name', () async {
    final version = await run('atsc', ['npt', '--version']);
    expect(version.stdout, versionOf('npt'));

    final help = await run('atsc', ['npt', '--help']);
    expect(
        (help.stdout as String).split('\n').first, startsWith('Usage: npt '));
  });

  test('atsc exits with the exit code of its subcommand', () async {
    final viaAtsc = await run('atsc', ['npt', '--no-such-option']);
    final direct = await run('npt', ['--no-such-option']);

    expect(direct.exitCode, isNot(0));
    expect(viaAtsc.exitCode, direct.exitCode);
  });

  test('atsc with no subcommand prints its usage', () async {
    final result = await run('atsc', []);

    expectAtscUsage(result.stderr);
    expect(result.exitCode, isNot(0));
  });

  test('atsc with an unknown subcommand refuses it', () async {
    final result = await run('atsc', ['no-such-program']);

    final List<String> lines = (result.stderr as String).split('\n');
    expect(lines.first, 'Invalid command: no-such-program');
    expectAtscUsage(lines.skip(1).join('\n'));
    expect(result.exitCode, isNot(0));
  });

  test('atsc prints its own version and help', () async {
    final version = await run('atsc', ['--version']);
    expect(version.stdout, versionOf('atsc'));
    expect(version.exitCode, 0);

    for (final String flag in ['--help', '-h']) {
      final help = await run('atsc', [flag]);
      expectAtscUsage(help.stdout);
      expect(help.exitCode, 0, reason: flag);
    }
  });

  test("a subcommand's own --version is not taken by atsc", () async {
    final result = await run('atsc', ['noports', 'activate', '--version']);

    expect(result.stdout, versionOf('noports'));
  });

  test('srv is its own binary beside atsc', () async {
    final refused = await run('atsc', ['srv']);
    final List<String> lines = (refused.stderr as String).split('\n');
    expect(lines.first, 'Invalid command: srv');
    expectAtscUsage(lines.skip(1).join('\n'));
    expect(refused.exitCode, isNot(0));

    final version = await run('srv', ['--version']);
    addTearDown(() {
      final log = File(
        path.join(
          Platform.isWindows ? Platform.environment['TEMP']! : '/tmp',
          'srv.${version.pid}.log',
        ),
      );
      if (log.existsSync()) log.deleteSync();
    });
    expect(version.stdout, versionOf('srv'));
  });

  test('atsc srvd names itself srvd in its version string', () async {
    final result = await run('atsc', ['srvd', '--version']);

    expect(result.stdout, versionOf('srvd'));
  });
}
