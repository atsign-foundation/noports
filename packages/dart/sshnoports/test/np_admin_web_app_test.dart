/// Catalogue: features/atsc/atsc.feature
library;

import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  test(
    'np_admin serves its web app from beside atsc',
    () async {
      final Directory installation =
          Directory.systemTemp.createTempSync('np_admin_installation');
      addTearDown(() => installation.deleteSync(recursive: true));
      Directory(path.join(installation.path, 'web', 'admin'))
          .createSync(recursive: true);
      final compiled = await Process.run(Platform.resolvedExecutable, [
        'compile',
        'exe',
        path.join('test', 'admin', 'print_web_app_directory.dart'),
        '-o',
        path.join(installation.path, 'atsc'),
      ]);
      expect(compiled.exitCode, 0,
          reason: '${compiled.stdout}${compiled.stderr}');
      final Directory elsewhere =
          Directory.systemTemp.createTempSync('np_admin_elsewhere');
      addTearDown(() => elsewhere.deleteSync(recursive: true));
      Directory(path.join(elsewhere.path, 'web', 'admin'))
          .createSync(recursive: true);

      final result = await Process.run(
        '/bin/sh',
        ['-c', 'exec atsc'],
        workingDirectory: elsewhere.path,
        environment: {'PATH': installation.path},
      );

      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(
        result.stdout,
        '${path.join(installation.resolveSymbolicLinksSync(), 'web', 'admin')}\n',
      );
    },
    skip: Platform.isWindows ? 'runs atsc through sh' : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
