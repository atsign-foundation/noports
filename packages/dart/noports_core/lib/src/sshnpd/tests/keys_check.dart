import 'dart:io'; 
import '../diagnostic_test.dart';
import '../utils/platform_utils.dart';

class KeysCheck extends DiagnosticTest {
  @override
  String get name => 'Keys Check (.atKeys)';

  @override
  String get description =>
      'Checks for the presence of keys directory and .atKeys files';

  @override
  Future<TestResult> run() async {
    final start = DateTime.now();

    String home = PlatformUtils.instance.homeDirectory;
    
    String keysPath = '$home${Platform.pathSeparator}.atsign${Platform.pathSeparator}keys';
    var directory = Directory(keysPath);

    if (!await directory.exists()) {
      return TestResult(
        testName: name,
        status: TestStatus.fail,
        message:
            'The keys directory is not found ($keysPath). Have you onboarded your atSign?',
        duration: DateTime.now().difference(start),
      );
    }

    try {
      List<FileSystemEntity> files = directory.listSync();
      var keyFiles =
          files.where((file) => file.path.endsWith('.atKeys')).toList();

      if (keyFiles.isNotEmpty) {
        var keyNames = keyFiles.map((f) => f.uri.pathSegments.last).join(', ');

        return TestResult(
          testName: name,
          status: TestStatus.pass,
          message:
              'Directory valid. Found ${keyFiles.length} key file(s): $keyNames',
          duration: DateTime.now().difference(start),
        );
      } else {
        // The keys directory exists but contains no .atKeys files.
        return TestResult(
          testName: name,
          status: TestStatus.warning,
          message: 'The keys directory exists but contains no .atKeys files.',
          duration: DateTime.now().difference(start),
        );
      }
    } catch (e) {
      return TestResult(
        testName: name,
        status: TestStatus.fail,
        message: 'Error reading the keys directory: $e',
        duration: DateTime.now().difference(start),
      );
    }
  }
}
