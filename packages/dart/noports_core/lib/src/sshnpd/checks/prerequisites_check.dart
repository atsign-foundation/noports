import '../diagnostic_check.dart';
import '../utils/platform_utils.dart';

class PrerequisitesCheck extends DiagnosticCheck {
  @override
  String get name => 'Prerequisites Check';

  @override
  String get description => 'Checks for the presence of curl and ssh';

  @override
  Future<CheckResult> run() async {
    final start = DateTime.now();
    List<String> missingTools = [];

    var tools = ['curl', 'ssh'];

    for (var tool in tools) {
      bool available = await PlatformUtils.instance.isCommandAvailable(tool);
      if (!available) {
        missingTools.add(tool);
      }
    }

    if (missingTools.isEmpty) {
      return CheckResult(
        checkName: name,
        status: CheckStatus.pass,
        message: 'Every required tool is present (curl, ssh).',
        duration: DateTime.now().difference(start),
      );
    } else {
      return CheckResult(
        checkName: name,
        status: CheckStatus.fail, // This is a blocking issue!
        message: 'Missing required tools: ${missingTools.join(', ')}',
        duration: DateTime.now().difference(start),
      );
    }
  }
}
