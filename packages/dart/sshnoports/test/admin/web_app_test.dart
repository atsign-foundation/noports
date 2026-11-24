import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:sshnoports/src/admin/web_app.dart';
import 'package:test/test.dart';

void main() {
  final String installation = path.join(Directory.systemTemp.path, 'opt', 'a');

  group('Given np_admin runs as a compiled binary', () {
    test('when the binary has any name, then it serves web/admin beside it',
        () {
      for (final String name in ['np_admin', 'atsc', 'other']) {
        final String executable = path.join(installation, name);
        expect(
          webAppDirectory(script: Uri.file(executable), executable: executable)
              .path,
          path.join(installation, 'web', 'admin'),
          reason: name,
        );
      }
    });
  });

  group('Given np_admin runs from source in this repository', () {
    test(
        'when its script is a .dart or .dill file in bin,'
        ' then it serves the web app built in this repository', () {
      final String dist = path.normalize(
          path.absolute('..', '..', '..', 'apps', 'admin', 'webapp', 'dist'));
      expect(File(path.join(path.dirname(dist), 'package.json')).existsSync(),
          isTrue,
          reason: 'the web app is in this repository');

      for (final String name in ['np_admin.dart', 'atsc.dart', 'atsc.dill']) {
        expect(
          webAppDirectory(
            script: Uri.file(path.absolute('bin', name)),
            executable: path.join(installation, 'atsc'),
          ).path,
          dist,
          reason: name,
        );
      }
    });
  });
}
