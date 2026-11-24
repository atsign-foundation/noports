/// Catalogue: features/atsc/atsc.feature
library;

import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:sshnoports/src/admin/web_app.dart';
import 'package:test/test.dart';

void main() {
  final String postfix = Platform.isWindows ? '.exe' : '';

  late Directory installation;

  setUp(() {
    installation = Directory.systemTemp.createTempSync('np_admin_web_app');
    addTearDown(() => installation.deleteSync(recursive: true));
    Directory(
      path.join(installation.path, 'web', 'admin'),
    ).createSync(recursive: true);
  });

  /// The directory np_admin serves for an executable called [name] in the
  /// installation.
  String servedFor(String name) => webAppDirectory(
        path.join(installation.path, '$name$postfix'),
      ).absolute.path;

  test('np_admin serves its web app from beside atsc', () {
    expect(Directory.current.path, isNot(installation.path));

    expect(servedFor('atsc'), path.join(installation.path, 'web', 'admin'));
  });

  test('an executable named np_admin does not serve the web app beside it', () {
    expect(
      servedFor('np_admin'),
      path.join(Directory.current.path, '..', '..', '..', 'apps', 'admin',
          'webapp', 'dist'),
    );
  });

  test('np_admin run from source serves the web app built in this repository',
      () {
    expect(
      servedFor('dart'),
      path.join(Directory.current.path, '..', '..', '..', 'apps', 'admin',
          'webapp', 'dist'),
    );
  });
}
