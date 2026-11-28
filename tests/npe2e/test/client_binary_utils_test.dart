import 'dart:io';

import 'package:npe2e/client_binary.dart';
import 'package:npe2e/client_binary_utils.dart';
import 'package:npe2e/language.dart';
import 'package:npe2e/noports_version.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  test(
    'Given an output directory that cannot be made, when the current build'
    ' runs, then each program fails, and no failure goes unhandled',
    () async {
      final Directory scratch = Directory.systemTemp.createTempSync('npe2e');
      addTearDown(() => scratch.deleteSync(recursive: true));
      final File notADirectory = File(path.join(scratch.path, 'file'))
        ..createSync();

      final List<Future<ClientBinary>> builds = compileDartCurrentBinariesList(
        noPortsVersion: NoPortsVersion(
          language: Language.dart,
          version: 'current',
        ),
        clientBinaryTypes: [ClientBinaryType.npt, ClientBinaryType.sshnp],
        outputDirectory: Directory(path.join(notADirectory.path, 'out')),
      );

      await Future.wait([
        for (final Future<ClientBinary> build in builds)
          expectLater(build, throwsA(isA<Exception>())),
      ]);
    },
  );
}
