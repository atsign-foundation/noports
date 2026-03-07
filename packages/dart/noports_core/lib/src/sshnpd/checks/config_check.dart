import 'dart:io';
import '../diagnostic_check.dart';
import '../utils/platform_utils.dart';

class ConfigCheck extends DiagnosticCheck {
  @override
  String get name => 'Config Check (sshnpd.yaml)';

  @override
  String get description =>
      'Checks for the presence and content of the config file';

  @override
  Future<CheckResult> run() async {
    final start = DateTime.now();

    //potential paths for config file
    List<String> potentialPaths = PlatformUtils.instance.getPotentialConfigPaths();

    for (var path in potentialPaths) {
      File configFile = File(path);

      if (await configFile.exists()) {
        try {
          String content = await configFile.readAsString();
          //get important lines
          var importantLines = content
              .split('\n')
              .where(
                  (line) => line.contains('manager') || line.contains('device'))
              .map((l) => l.trim())
              .join(', ');

          return CheckResult(
            checkName: name,
            status: CheckStatus.pass,
            message: 'File found at: $path\n      Preview: $importantLines',
            duration: DateTime.now().difference(start),
          );
        } catch (e) {
          return CheckResult(
            checkName: name,
            status: CheckStatus.warning,
            message: 'File found ($path) but unable to read it: $e',
            duration: DateTime.now().difference(start),
          );
        }
      }
    }
    
    return CheckResult(
      checkName: name,
      status: CheckStatus
          .warning, //warning because it's not a problem if you are using CLI arguments
      message:
          'No sshnpd.yaml file found (this is not a problem if you are using CLI arguments).',
      duration: DateTime.now().difference(start),
    );
  }
}
