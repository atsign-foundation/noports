import 'dart:io';

import 'package:noports_core/srv.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  final String postfix = Platform.isWindows ? '.exe' : '';

  late Directory installation;

  /// Creates an empty file called [name] in [installation].
  String place(String name) =>
      (File(path.join(installation.path, '$name$postfix'))..createSync()).path;

  setUp(() {
    installation = Directory.systemTemp.createTempSync('srv_beside');
    addTearDown(() => installation.deleteSync(recursive: true));
  });

  group('Given srv is installed in the same directory as the executable', () {
    setUp(() => place('srv'));

    test('atsc runs the srv beside it', () async {
      expect(
        await Srv.getBinaryPathBeside(place('atsc')),
        File(path.join(installation.path, 'srv$postfix')).absolute.path,
      );
    });

    test('sshnp, sshnpd and npt run the srv beside them', () async {
      for (final String name in ['sshnp', 'sshnpd', 'npt']) {
        expect(
          await Srv.getBinaryPathBeside(place(name)),
          File(path.join(installation.path, 'srv$postfix')).absolute.path,
          reason: name,
        );
      }
    });

    test('an executable with any other name finds no srv', () async {
      for (final String name in ['other', 'srvd', 'dart']) {
        expect(
          await Srv.getBinaryPathBeside(place(name)),
          isNull,
          reason: '$name is not atsc, sshnp, sshnpd or npt',
        );
      }
    });
  });

  test('atsc with no srv beside it finds none', () async {
    expect(await Srv.getBinaryPathBeside(place('atsc')), isNull);
  });

  group('Given srv and atsc in one directory', () {
    late String atsc;

    setUp(() {
      place('srv');
      atsc = place('atsc');
    });

    test('atsc named by an absolute path runs the srv beside it', () async {
      expect(path.isAbsolute(atsc), isTrue);
      expect(
        await Srv.getBinaryPathBeside(atsc),
        File(path.join(installation.path, 'srv$postfix')).absolute.path,
      );
    });

    test('atsc named by a relative path finds no srv', () async {
      final String relative = path.relative(atsc, from: Directory.current.path);

      expect(path.isRelative(relative), isTrue);
      expect(await Srv.getBinaryPathBeside(relative), isNull);
    });
  });

  test(
    'atsc run by its bare name through PATH runs the srv beside it,'
    ' not one in its current directory',
    () async {
      final compiled = await Process.run(Platform.resolvedExecutable, [
        'compile',
        'exe',
        path.join('test', 'srv', 'print_local_binary_path.dart'),
        '-o',
        path.join(installation.path, 'atsc'),
      ]);
      expect(
        compiled.exitCode,
        0,
        reason: '${compiled.stdout}${compiled.stderr}',
      );
      place('srv');
      final Directory elsewhere = Directory.systemTemp.createTempSync(
        'srv_elsewhere',
      );
      addTearDown(() => elsewhere.deleteSync(recursive: true));
      File(path.join(elsewhere.path, 'srv')).createSync();

      final result = await Process.run(
        '/bin/sh',
        ['-c', 'exec atsc'],
        workingDirectory: elsewhere.path,
        environment: {'PATH': installation.path},
      );

      expect(result.exitCode, 0, reason: '${result.stderr}');
      final List<String> lines = (result.stdout as String).split('\n');
      expect(lines[0], 'atsc', reason: 'atsc is run by its bare name');
      expect(
        lines[1],
        path.join(installation.resolveSymbolicLinksSync(), 'srv'),
      );
    },
    skip: Platform.isWindows ? 'runs atsc through sh' : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
