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
          reason: '$name is not atsc',
        );
      }
    });
  });

  test('atsc with no srv beside it finds none', () async {
    expect(await Srv.getBinaryPathBeside(place('atsc')), isNull);
  });
}
