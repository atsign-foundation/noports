import 'dart:io'; 
import '../diagnostic_check.dart';
import '../utils/platform_utils.dart';

class KeysCheck extends DiagnosticCheck {
  @override
  String get name => 'Keys Check (.atKeys)';

  @override
  String get description =>
      'Checks for the presence of keys directory and .atKeys files';

  @override
  Future<CheckResult> run() async {
    final start = DateTime.now();

    String home = PlatformUtils.instance.homeDirectory;
    
    String keysPath = '$home${Platform.pathSeparator}.atsign${Platform.pathSeparator}keys';
    var directory = Directory(keysPath);

    if (!await directory.exists()) {
      return CheckResult(
        checkName: name,
        status: CheckStatus.fail,
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

        return CheckResult(
          checkName: name,
          status: CheckStatus.pass,
          message:
              'Directory valid. Found ${keyFiles.length} key file(s): $keyNames',
          duration: DateTime.now().difference(start),
        );
      } else {
        // The keys directory exists but contains no .atKeys files.
        return CheckResult(
          checkName: name,
          status: CheckStatus.warning,
          message: 'The keys directory exists but contains no .atKeys files.',
          duration: DateTime.now().difference(start),
        );
      }
    } catch (e) {
      return CheckResult(
        checkName: name,
        status: CheckStatus.fail,
        message: 'Error reading the keys directory: $e',
        duration: DateTime.now().difference(start),
      );
    }
  }
}
