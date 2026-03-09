import 'dart:io'; 
import '../diagnostic_check.dart';
import '../utils/platform_utils.dart';
import 'config_check.dart';

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
        var keyFileNames = keyFiles.map((f) => f.uri.pathSegments.last).join(', ');
        var keyNames = keyFileNames.replaceAll('.atKeys', '').replaceAll('_key', '');
        print(keyNames);
        print(ConfigCheck.atKeys);

        for (var keyName in keyNames.split(',')) {
          var trimmed = keyName.trim();
          if (ConfigCheck.atKeys.contains(trimmed)) {
            return CheckResult(
              checkName: name,
              status: CheckStatus.pass,
              message:
                  'Found $trimmed in $keysPath, and it is present in your config file.',
              duration: DateTime.now().difference(start),
            );
          }
        }

        // None of the key files matched the config
        return CheckResult(
          checkName: name,
          status: CheckStatus.fail,
          message:
              'Found .atKeys files ($keyFileNames) in $keysPath, but none are present in your config file.',
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
